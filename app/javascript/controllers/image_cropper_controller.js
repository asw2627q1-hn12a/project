import { Controller } from "@hotwired/stimulus"
import Cropper from "cropperjs"

// Previsualització i retall de l'avatar / banner abans de pujar-los (TG-49).
//
// En triar un fitxer, es mostra dins d'un marc amb la proporció final; l'usuari
// pot moure'l i fer zoom. Cada cop que canvia el retall, generem la imatge final
// (mida exacta, p. ex. 400×400) en un <canvas> i la posem al mateix <input type=file>.
// Així el servidor rep una imatge normal i no cal res especial al controlador de Rails.
// Sense JavaScript, el camp funciona igual però sense retall.
export default class extends Controller {
  static targets = [ "input", "stage", "image", "preview" ]
  static values = { width: Number, height: Number }

  disconnect() {
    this.destroyCropper()
  }

  // data-action="change->image-cropper#load"
  load() {
    const file = this.inputTarget.files[0]
    if (!file || !file.type.startsWith("image/")) return // el servidor ja mostrarà l'error

    this.originalFile = file
    this.destroyCropper()
    this.imageTarget.src = URL.createObjectURL(file)
    this.stageTarget.hidden = false

    this.cropper = new Cropper(this.imageTarget, {
      aspectRatio: this.widthValue / this.heightValue,
      viewMode: 1,          // el marc no pot sortir de la imatge
      dragMode: "move",     // arrossegar mou la imatge, no crea un marc nou
      autoCropArea: 1,      // el marc ocupa tot el que pot d'entrada
      cropBoxMovable: false,
      cropBoxResizable: false,
      toggleDragModeOnDblclick: false,
      background: false,
      crop: () => this.scheduleExport()
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

  // Esperem que l'usuari pari de moure abans de generar la imatge (no cada píxel).
  scheduleExport() {
    clearTimeout(this.exportTimer)
    this.exportTimer = setTimeout(() => this.export(), 150)
  }

  export() {
    if (!this.cropper) return

    const canvas = this.cropper.getCroppedCanvas({
      width: this.widthValue,
      height: this.heightValue,
      imageSmoothingQuality: "high"
    })
    if (!canvas) return

    const type = this.originalFile.type === "image/png" ? "image/png" : "image/jpeg"
    canvas.toBlob((blob) => {
      if (!blob || !this.cropper) return

      const name = this.originalFile.name.replace(/\.[^.]+$/, "") + (type === "image/png" ? ".png" : ".jpg")
      const cropped = new File([ blob ], name, { type })

      // Substituïm el fitxer de l'input pel retallat (DataTransfer és l'única manera
      // estàndard de crear una FileList des de JavaScript).
      const files = new DataTransfer()
      files.items.add(cropped)
      this.inputTarget.files = files.files

      // Previsualització: com quedarà al perfil
      this.originalPreview ??= this.previewTarget.src
      this.previewTarget.src = canvas.toDataURL(type)
    }, type, 0.9)
  }

  destroyCropper() {
    clearTimeout(this.exportTimer)
    if (this.cropper) {
      this.cropper.destroy()
      this.cropper = null
    }
    if (this.imageTarget.src.startsWith("blob:")) URL.revokeObjectURL(this.imageTarget.src)
  }
}
