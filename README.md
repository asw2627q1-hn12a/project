# Hacker News clone — ASW (FIB, UPC)

Projecte de laboratori de l'assignatura **Aplicacions i Serveis Web (ASW)** de la FIB (UPC), curs 2026-27 Q1, grup **hn12a**.
L'objectiu és construir la nostra pròpia versió de [Hacker News](https://news.ycombinator.com/) amb Ruby on Rails.

🔗 **Aplicació desplegada:** https://asw2627q1-hn12-project.onrender.com

🔗 **Projecte Taiga:** https://tree.taiga.io/project/hectorgutierrezz-assw2627q1_hn12a

🔗 **Repositori:** https://github.com/asw2627q1-hn12a/project

Aquest README descriu les funcionalitats i la configuració del primer lliurament. La interfície està inspirada en Hacker News i les pàgines es generen al servidor amb ERB; el retall d'imatges al navegador és una millora opcional.

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
- **Comentaris i fils**: es poden comentar submissions i respondre comentaris a qualsevol nivell. El detall d'una submission mostra el seu arbre de comentaris i el detall d'un comentari mostra el seu subarbre. Només l'autor pot editar o eliminar un comentari propi; l'esborrat és lògic i conserva les respostes d'altres usuaris.
- **Comentaris recents** (`/newcomments`): mostra els 30 comentaris més recents, amb enllaços al contingut i al fil. **Threads** (`/threads`) mostra els fils dels comentaris de l'usuari autenticat, evitant repetir respostes pròpies ja incloses en un altre fil.
- **Favorite/unfavorite** de submissions i comentaris, inclosos els propis: només amb sessió, un favorit per usuari i element, amb protecció també a la BD. Marcar o retirar un favorit no canvia els punts ni la visibilitat del contingut. Els comentaris eliminats no admeten favorits nous, però es poden retirar els anteriors des del seu detall.
- **Perfil d'usuari** (`/users/:id`): username, antiguitat, karma, about, avatar i banner. El karma és la suma dels punts de les submissions i dels comentaris de l'usuari.
  - Qualsevol visitant pot consultar els llistats de submissions, comentaris i favorits d'un usuari.
  - Només el propietari pot consultar `hidden`, `upvoted submissions` i `upvoted comments`; la restricció es comprova al servidor.
  - L'usuari autenticat pot editar about, email, avatar i banner des del seu perfil. El username no es modifica. El correu només és visible per al propietari, també en les respostes JSON.
  - Avatar i banner predeterminats si no n'hi ha cap de personalitzat. Es poden pujar, substituir i eliminar imatges PNG, JPEG, GIF o WebP de fins a 2 MB. El navegador permet retallar-les abans d'enviar-les.
- **Hide/unhide de submissions (Taiga #28)**: els usuaris autenticats poden amagar submissions, incloses les pròpies. L'ocultació és personal i persistent: les exclou de `/`, `/news`, `/submissions`, `/newest`, `/ask` i `/search` només per a aquell usuari. No elimina contingut ni canvia punts o comentaris; el detall continua accessible per URL.
  - El nom d'usuari de la capçalera obre el perfil; l'enllaç `hidden` del perfil propi porta a `/hidden`, una llista privada amb l'acció `unhide`. També es pot retirar l'ocultació des del detall.
  - La llista `hidden` també permet votar i retirar el vot de submissions alienes sense recuperar-les. Amagar o recuperar una submission conserva els vots i els punts, tant de la submission com dels seus comentaris.
  - `hide` envia un POST i `unhide` un DELETE a `/submissions/:submission_id/hide`, amb formularis de Rails i protecció CSRF, sense afegir JavaScript. Es torna a la pàgina d'origen, o a la portada si no hi ha un origen local vàlid.
  - L'usuari s'obté de la sessió. Un índex únic sobre `user_id` i `submission_id` evita duplicats; repetir hide/unhide no canvia el resultat. Només es pot retirar l'ocultació pròpia.

## Stack

| Peça | Versió / eina |
| --- | --- |
| Ruby | 4.0.7 (veure `.ruby-version`) |
| Rails | 8.1.4.1 (veure `Gemfile.lock`) |
| Base de dades | PostgreSQL extern a producció; SQLite 3 en local (CI amb tots dos) |
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

Els seeds afegeixen els exemples que falten sense esborrar dades ni modificar els registres existents. Es poden tornar a executar sense duplicar els mateixos exemples. Això no substitueix la persistència de la base de dades a producció.

En Windows, es poden executar les ordres de Rails amb Ruby explícitament:

```powershell
bundle install
ruby bin/rails db:prepare
ruby bin/rails db:seed   # opcional, contra la BD local
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

En desenvolupament també es poden definir en un fitxer `.env` local, ignorat per Git. No cal configurar R2 per treballar en local: les imatges es guarden al disc de desenvolupament.

> ⚠️ No pugeu mai el `GITHUB_CLIENT_SECRET` ni el `config/master.key` al repositori.

### 4. Arrencar el servidor

```bash
bin/dev
```

L'aplicació estarà disponible a http://localhost:3000.

En Windows: `ruby bin/rails server`.

## Tests i qualitat de codi

Les mateixes comprovacions que executa la CI (`.github/workflows/ci.yml`):

```bash
bin/rails db:test:prepare test test:system   # tests unitaris, de controlador i de sistema
bin/rubocop -f github                        # estil de codi
bin/brakeman --no-pager                      # anàlisi de seguretat
bin/importmap audit                          # vulnerabilitats en dependències JS
```

La CI executa els tests amb SQLite i PostgreSQL. El login es simula amb OmniAuth als tests; no s'hi utilitzen credencials reals de GitHub. Les proves d'imatges utilitzen emmagatzematge de test local: no substitueixen la verificació de R2 a producció.

En Windows, cal evitar la paral·lelització amb processos, perquè `fork` no està disponible:

```powershell
$env:PARALLEL_WORKERS = "1"
ruby bin/rails db:test:prepare test test:system
ruby bin/rubocop -f github
ruby bin/brakeman --no-pager
ruby bin/importmap audit
```

Les bases de dades de test han de ser independents de producció. La preparació d'una PostgreSQL de prova amb Docker es descriu a [docs/postgresql.md](docs/postgresql.md).

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
- Object storage (avatars i banners, servei compatible amb S3): `STORAGE_BUCKET`, `STORAGE_ACCESS_KEY_ID`, `STORAGE_SECRET_ACCESS_KEY`, `STORAGE_REGION` i, si no és AWS, `STORAGE_ENDPOINT`. L'endpoint ha de ser una URL completa amb `https://`. La clau d'accés ha de ser l'Access Key ID per a clients S3, no el token de l'API de Cloudflare.
- `DATABASE_URL`: connexió a PostgreSQL extern. Cache, queue i cable també s'emmagatzemen al servidor PostgreSQL, amb bases auxiliars.
- Les fotos requereixen object storage: el disc del servei Free no conserva fitxers entre desplegaments. Per a R2: `AWS_REQUEST_CHECKSUM_CALCULATION=WHEN_REQUIRED`.

La preparació, conservació de dades, importació de SQLite i verificació de persistència s'expliquen a [docs/postgresql.md](docs/postgresql.md). El canvi de connexió no migra dades automàticament. PostgreSQL Free de Render caduca als 30 dies.

L'arrencada Docker exigeix `DATABASE_URL` de PostgreSQL i `STORAGE_BUCKET`, i executa `db:prepare` per preparar la BD principal i les auxiliars. No es depèn del disc efímer de Render per conservar dades o imatges pujades.

Els seeds **no es carreguen automàticament a producció**. Si es volen les dades d'exemple, cal executar `bin/rails db:seed` expressament en un entorn amb la connexió correcta, després de decidir si s'importaran dades antigues. La càrrega local per defecte no omple la BD de Render. Un cop desats a PostgreSQL, els exemples no s'han de recrear a cada desplegament.

Health check: `GET /up`. Una resposta correcta indica que Rails arrenca, però no acredita totes les operacions de BD ni la pujada a R2.

## Verificació del primer lliurament

Abans de donar el desplegament per verificat:

1. Registrar el commit de `main` desplegat i comprovar la CI d'aquell commit.
2. Provar login/logout i la creació d'un usuari nou amb GitHub.
3. Provar submissions URL i Ask, URL incorrecta i duplicada, comentaris i respostes a diversos nivells, edició i eliminació pròpies i rebuig d'operacions sobre contingut aliè.
4. Provar vote/unvote, hide/unhide i favorite/unfavorite amb dos usuaris; comprovar punts, estat dels botons i llistes privades després de recarregar.
5. Revisar el menú, el cercador, els perfils i els seus llistats, inclòs l'accés sense sessió.
6. Pujar, substituir i eliminar avatar/banner; comprovar els objectes a R2 i la seva visualització.
7. Tornar a desplegar el mateix commit i comprovar que les dades de PostgreSQL i les imatges continuen disponibles. Comprovar també la represa després d'inactivitat.
8. Registrar els resultats i les incidències a Taiga #33. Les proves locals i la CI no impliquen, per si soles, que aquesta verificació de producció estigui completada.

Per a la tramesa de l'assignatura cal mantenir a `main` els noms de l'equip, el projecte Taiga i l'URL de producció indicats al principi del README, i completar la tramesa de l'URL del repositori a Atenea. La demo i la code review requereixen la presència de tot l'equip. Segons l'enunciat, no es poden fer commits, merges ni PR durant l'hora anterior a l'inici de la classe de la demo ni un cop començada.

## Estructura del projecte

```
app/
  controllers/   # contingut, OAuth, perfils, vots, ocultacions i favorits
  models/        # User, Submission, Comment i les relacions per usuari
  views/         # pàgines i formularis ERB
config/
  database.yml   # SQLite local/test i PostgreSQL extern a producció
  storage.yml    # disc local/test i object storage
  initializers/omniauth.rb   # configuració del login amb GitHub
  routes.rb
db/
  migrate/       # migracions de l'esquema
  schema.rb
  seeds.rb       # dades de prova
docs/
  postgresql.md  # preparació, importació i verificació del desplegament
lib/
  sqlite_data_import.rb     # importació a una BD principal buida
test/            # tests de models, controladors, integració i navegador
```
