# Hacker News clone — ASW (FIB, UPC)

Projecte de laboratori de l'assignatura **Aplicacions i Serveis Web (ASW)** de la FIB (UPC), curs 2026-27 Q1, grup **hn12a**.
L'objectiu és construir la nostra pròpia versió de [Hacker News](https://news.ycombinator.com/) amb Ruby on Rails.

🔗 **Aplicació desplegada:** https://asw2627q1-hn12-project.onrender.com
📋 **Taiga:** _(afegir l'enllaç al projecte públic de Taiga)_

## Equip

| Membre |
| --- |
| Vinyet Amorós |
| Martina Maldonado |
| Héctor Gutiérrez |
| Joel Novio |
| Marc Rodríguez |

## Funcionalitats actuals

- **Login amb GitHub** (OAuth via OmniAuth). L'usuari es crea automàticament el primer cop que inicia sessió.
- **Submissions** de dos tipus:
  - `url`: títol + URL (la URL ha de ser única; si ja existeix, es redirigeix a la submission original).
  - `ask`: títol + text, sense URL.
- **`/news`** (i `/`): submissions de tipus URL ordenades per punts.
- **`/newest`**: totes les submissions, de la més nova a la més antiga.
- **Perfil d'usuari** (`/users/:id`) amb avatar i banner.

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
