import { Controller } from "@hotwired/stimulus"
import Cropper from "cropperjs"

// Previsualització i retall de l'avatar / banner abans de pujar-los (TG-49).
//
// En triar un fitxer, es mostra dins d'un marc amb la proporció final; l'usuari
// pot moure'l i fer zoom. El retall es genera en un <canvas> a la mida exacta
// (p. ex. 400×400) i es posa al mateix <input type=file>, així el servidor rep
// una imatge normal. Sense JavaScript, el camp funciona igual però sense retall.
//
// Dues curses que cal evitar (review de la PR #35):
// 1. Enviar el formulari abans que el retall estigui exportat: interceptem el
//    "submit", esperem l'exportació i el tornem a enviar.
// 2. Canviar ràpidament d'imatge A a B: cada imatge té un número de "generació"
//    i qualsevol exportació d'una generació antiga es descarta.
export default class extends Controller {
  static targets = [ "input", "stage", "image", "preview" ]
  static values = { width: Number, height: Number }

  connect() {
    this.generation = 0
    this.form = this.element.closest("form")
    this.onSubmit = this.onSubmit.bind(this)
    this.form?.addEventListener("submit", this.onSubmit)
  }

  disconnect() {
    this.form?.removeEventListener("submit", this.onSubmit)
    this.destroyCropper()
  }

  // data-action="change->image-cropper#load"
  load() {
    const file = this.inputTarget.files[0]
    this.destroyCropper()
    if (!file || !file.type.startsWith("image/")) return // el servidor ja mostrarà l'error

    const generation = ++this.generation
    this.originalFile = file
    this.cropVersion = 1  // puja cada cop que l'usuari mou o fa zoom
    this.exportedVersion = 0
    this.stageTarget.hidden = false
    this.imageTarget.src = URL.createObjectURL(file)

    this.ready = new Promise((resolve) => {
      this.resolveReady = resolve // destroyCropper() també l'allibera, perquè ningú es quedi esperant
      // Si el navegador no pot llegir la imatge, no bloquegem el formulari:
      // s'enviarà l'original i el servidor el validarà.
      this.imageTarget.onerror = () => {
        if (generation !== this.generation) return
        this.destroyCropper()
        this.stageTarget.hidden = true
        resolve()
      }
      this.cropper = new Cropper(this.imageTarget, {
        aspectRatio: this.widthValue / this.heightValue,
        viewMode: 1,          // el marc no pot sortir de la imatge
        dragMode: "move",     // arrossegar mou la imatge, no crea un marc nou
        autoCropArea: 1,      // el marc ocupa tot el que pot d'entrada
        cropBoxMovable: false,
        cropBoxResizable: false,
        toggleDragModeOnDblclick: false,
        background: false,
        ready: () => resolve(),
        crop: () => {
          if (generation !== this.generation) return
          this.cropVersion++
          this.scheduleExport()
        }
      })
    })
  }

  zoomIn() {
    this.cropper?.zoom(0.1)
  }

  zoomOut() {
    this.cropper?.zoom(-0.1)
  }

  // Desfà la selecció: no es pujarà cap fitxer nou.
  cancel() {
    this.destroyCropper()
    this.inputTarget.value = ""
    this.stageTarget.hidden = true
    if (this.originalPreview) this.previewTarget.src = this.originalPreview
  }

  // Si el retall no està exportat, frenem l'enviament, l'exportem i el reenviem.
  // Amb dos camps (avatar i banner), cada controlador fa el mateix amb el seu.
  get dirty() {
    return Boolean(this.cropper) && this.exportedVersion !== this.cropVersion
  }

  async onSubmit(event) {
    if (!this.dirty) return

    event.preventDefault()
    event.stopImmediatePropagation()
    const submitter = event.submitter
    await this.exportNow()
    this.form.requestSubmit(submitter && submitter.form === this.form ? submitter : undefined)
  }

  // Esperem que l'usuari pari de moure abans de generar la imatge (no cada píxel).
  scheduleExport() {
    clearTimeout(this.exportTimer)
    this.exportTimer = setTimeout(() => this.exportNow(), 150)
  }

  async exportNow() {
    clearTimeout(this.exportTimer)
    const generation = this.generation
    await this.ready
    if (generation !== this.generation || !this.cropper) return

    const version = this.cropVersion
    const canvas = this.cropper.getCroppedCanvas({
      width: this.widthValue,
      height: this.heightValue,
      imageSmoothingQuality: "high"
    })
    if (!canvas) return

    const type = this.originalFile.type === "image/png" ? "image/png" : "image/jpeg"
    const blob = await new Promise((resolve) => canvas.toBlob(resolve, type, 0.9))

    // Si mentrestant s'ha triat una altra imatge (o s'ha cancel·lat), aquest resultat és vell.
    if (!blob || generation !== this.generation || !this.cropper) return

    const name = this.originalFile.name.replace(/\.[^.]+$/, "") + (type === "image/png" ? ".png" : ".jpg")
    const files = new DataTransfer() // única manera estàndard de crear una FileList des de JS
    files.items.add(new File([ blob ], name, { type }))
    this.inputTarget.files = files.files

    this.originalPreview ??= this.previewTarget.src
    this.previewTarget.src = canvas.toDataURL(type)
    // Si l'usuari ha tornat a moure la imatge mentre exportàvem, continua "brut"
    // i el submit (o el següent temporitzador) en farà una altra exportació.
    this.exportedVersion = Math.max(this.exportedVersion, version)
  }

  destroyCropper() {
    clearTimeout(this.exportTimer)
    this.generation++ // invalida qualsevol exportació pendent
    this.resolveReady?.()
    this.resolveReady = null
    this.ready = null
    this.imageTarget.onerror = null
    if (this.cropper) {
      this.cropper.destroy()
      this.cropper = null
    }
    if (this.imageTarget.src.startsWith("blob:")) URL.revokeObjectURL(this.imageTarget.src)
  }
}
