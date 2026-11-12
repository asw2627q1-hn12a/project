# Hacker News clone — ASW (FIB, UPC)

Projecte de laboratori de l'assignatura **Aplicacions i Serveis Web (ASW)** de la FIB (UPC), curs 2026-27 Q1, grup **hn12a**.
L'objectiu és construir la nostra pròpia versió de [Hacker News](https://news.ycombinator.com/) amb Ruby on Rails.

🔗 **Aplicació desplegada:** https://asw2627q1-hn12-project.onrender.com

## Equip

| Membre |
| --- |
| Vinyet Amorós |
| Martina Maldonado |
| Héctor Gutiérrez |
| Joel Novio |
| Marc Rodríguez |

## Funcionalitats actuals

- **Menú superior**: `new | threads | comments | ask | submit` (threads només amb sessió) i la pàgina actual es mostra ressaltada. Past, Show i Jobs queden fora de l'abast del primer lliurament.
- **Login amb GitHub** (OAuth via OmniAuth). L'usuari es crea automàticament el primer cop que inicia sessió.
- **Vote/unvote de submissions** al detall i als llistats: només amb sessió, sobre submissions alienes i un vot per usuari. Votar suma un punt i retirar el vot propi en resta un. Les submissions noves conserven el punt inicial, sense vot automàtic de l'autor.
  - Presentació inspirada en Hacker News: triangle gris per votar, que desapareix després del vot, i acció `unvote` al costat dels punts, autor i antiguitat del llistat. Són formularis POST/DELETE amb protecció CSRF, encara que visualment semblin enllaços. No cal JavaScript.
  - Referència visual del triangle: [CSS original](https://news.ycombinator.com/news.css) i [SVG original](https://news.ycombinator.com/triangle.svg) de Hacker News; es mostra a 10 × 10 píxels amb els mateixos marges. El gràfic es conserva localment a `app/assets/images/hn-vote-triangle.svg`.
- **Vote/unvote de comentaris**, també de respostes: mateix punt inicial i restriccions de propietat i unicitat que les submissions. Es mostren el triangle i `unvote` al fil, al detall, als comentaris recents i als threads. Els comentaris eliminats no admeten vots nous; els vots anteriors es conserven i es poden retirar.
  - Tant en submissions com en comentaris, votar o retirar el vot torna a la pàgina d'origen i conserva els paràmetres de cerca. Si el navegador no indica l'origen o apunta a un altre domini, es torna al detall de l'element.
  - Els visitants anònims també veuen el triangle: obre el login amb GitHub mitjançant POST, sense registrar cap vot automàticament.
  - L'estat dels vots es carrega per als elements del llistat o fil mostrat. El partial de submissions també el resol quan es reutilitza des d'altres llistats, sense dependre d'una acció concreta del controlador.
- **Submissions** de dos tipus:
  - `url`: títol + URL (la URL ha de ser única; si ja existeix, es redirigeix a la submission original).
  - `ask`: títol + text, sense URL.
- **`/news`** (i `/`): submissions de tipus URL i Ask ordenades per rellevància (punts i, en cas d'empat, les més recents primer), amb el nombre de comentaris de cada una.
- **`/newest`**: totes les submissions, de la més nova a la més antiga.
- **`/search`**: cerca pel títol des de la barra superior, sense distingir majúscules i minúscules; inclou URL i Ask, ordenades per punts i, en cas d’empat, per data més recent, com a la portada.
- **Gestió de submissions pròpies**: només l'autor autenticat pot editar o eliminar una submission. L'edició carrega les dades actuals i valida el títol, el format HTTP/HTTPS i les URL duplicades. Eliminar una submission elimina definitivament tots els seus comentaris i respostes, inclosos els comentaris marcats com a eliminats; es demana confirmació abans d'enviar l'eliminació.
- **Perfil d'usuari** (`/users/:id`) amb avatar i banner.
- **Hide/unhide de submissions (Taiga #28)**: els usuaris autenticats poden amagar submissions, incloses les pròpies. L'ocultació és personal i persistent: les exclou de `/`, `/news`, `/submissions`, `/newest`, `/ask` i `/search` només per a aquell usuari. No elimina contingut ni canvia punts o comentaris; el detall continua accessible per URL.
  - El nom d'usuari de la capçalera obre el perfil; l'enllaç `hidden` del perfil propi porta a `/hidden`, una llista privada amb l'acció `unhide`. També es pot retirar l'ocultació des del detall.
  - La llista `hidden` també permet votar i retirar el vot de submissions alienes sense recuperar-les. Amagar o recuperar una submission conserva els vots i els punts, tant de la submission com dels seus comentaris.
  - `hide` envia un POST i `unhide` un DELETE a `/submissions/:submission_id/hide`, amb formularis de Rails i protecció CSRF, sense afegir JavaScript. Es torna a la pàgina d'origen, o a la portada si no hi ha un origen local vàlid.
  - L'usuari s'obté de la sessió. Un índex únic sobre `user_id` i `submission_id` evita duplicats; repetir hide/unhide no canvia el resultat. Només es pot retirar l'ocultació pròpia.

## Stack

| Peça | Versió / eina |
| --- | --- |
| Ruby | 4.0.7 (veure `.ruby-version`) |
| Rails | 8.1 |
| Base de dades | SQLite 3 |
| Frontend | Hotwire (Turbo + Stimulus), Importmap, Propshaft |
| Autenticació | `omniauth` + `omniauth-github` |
| Cua / cache / cable | Solid Queue, Solid Cache, Solid Cable |
| Desplegament | Docker a Render (`render.yaml`) |

## Posada en marxa en local

### 1. Requisits

- Ruby 4.0.7 (recomanat via `rbenv`, `asdf` o `mise`)
- SQLite 3
- Google Chrome (només per als tests de sistema)

### 2. Instal·lació

```bash
git clone https://github.com/asw2627q1-hn12a/project.git
cd project
bin/setup --skip-server   # instal·la gems i prepara la base de dades
bin/rails db:seed         # (opcional) carrega usuaris i submissions de prova
```

### 3. Variables d'entorn (login amb GitHub)

Crea una **OAuth App** a GitHub (*Settings → Developer settings → OAuth Apps*) amb:

- **Homepage URL:** `http://localhost:3000`
- **Authorization callback URL:** `http://localhost:3000/auth/github/callback`

I exporta les credencials abans d'arrencar el servidor:

```bash
export GITHUB_CLIENT_ID=...
export GITHUB_CLIENT_SECRET=...
```

> ⚠️ No pugeu mai el `GITHUB_CLIENT_SECRET` ni el `config/master.key` al repositori.

### 4. Arrencar el servidor

```bash
bin/dev
```

L'aplicació estarà disponible a http://localhost:3000.

## Tests i qualitat de codi

Les mateixes comprovacions que executa la CI (`.github/workflows/ci.yml`):

```bash
bin/rails db:test:prepare test test:system   # tests unitaris, de controlador i de sistema
bin/rubocop                                  # estil de codi
bin/brakeman --no-pager                      # anàlisi de seguretat
bin/importmap audit                          # vulnerabilitats en dependències JS
```

## Flux de treball

1. Cada tasca de **Taiga** té la seva pròpia branca a GitHub.
2. Quan la tasca està feta, s'obre una **pull request** cap a `main` i es mou a *Ready for test* a Taiga.
3. Per fer el merge i passar la tasca a *Closed* cal que:
   - **tots els jobs de la CI** passin (tests, RuboCop, Brakeman i importmap audit), i
   - **un altre membre de l'equip aprovi** la pull request.

## Desplegament

L'aplicació es desplega a **Render** amb el `Dockerfile` del repositori, segons `render.yaml`:

- `RAILS_ENV=production`
- `RAILS_MASTER_KEY` (configurada manualment a Render)
- `GITHUB_CLIENT_ID` / `GITHUB_CLIENT_SECRET` (OAuth App de producció, amb callback `https://asw2627q1-hn12-project.onrender.com/auth/github/callback`)
- `SOLID_QUEUE_IN_PUMA=true`
- Object storage (avatars i banners, servei compatible amb S3): `STORAGE_BUCKET`, `STORAGE_ACCESS_KEY_ID`, `STORAGE_SECRET_ACCESS_KEY`, `STORAGE_REGION` i, si no és AWS, `STORAGE_ENDPOINT`. Sense `STORAGE_BUCKET` les imatges es guarden al disc local de Render.
- Disc persistent muntat a `/rails/storage` per a les bases de dades SQLite.

Health check: `GET /up`.

## Estructura del projecte

```
app/
  controllers/   # submissions, users, sessions (OAuth)
  models/        # Submission, User
  views/
config/
  initializers/omniauth.rb   # configuració del login amb GitHub
  routes.rb
db/
  schema.rb
  seeds.rb       # dades de prova
test/            # tests de models, controladors i sistema
```
