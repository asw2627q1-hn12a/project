# PostgreSQL a producció (Taiga #33)

Rails s'executa al servei web i les dades es guarden en una instància PostgreSQL externa. SQLite continua disponible per a desenvolupament i tests locals; la CI prova SQLite i PostgreSQL.

## Arquitectura

Una instància PostgreSQL conté quatre bases de dades lògiques. Si `DATABASE_URL` acaba en `/hn12a`, les connexions auxiliars apunten a `/hn12a_cache`, `/hn12a_queue` i `/hn12a_cable`. `CACHE_DATABASE_URL`, `QUEUE_DATABASE_URL` i `CABLE_DATABASE_URL` permeten canviar-les explícitament.

`db:prepare` prepara els esquemes de totes quatre. L'usuari PostgreSQL ha de poder crear les bases auxiliars; si no té aquest permís, cal crear-les prèviament amb un administrador. Els seeds no es carreguen automàticament a producció: una BD nova comença buida.

## 1. Abans de desplegar: preservar les dades

No feu un nou desplegament fins a obtenir una còpia consistent de la BD antiga si les dades encara existeixen. En un servei Free sense disc persistent, un nou desplegament pot fer desaparèixer l'última còpia SQLite.

Una còpia amb SQLite en mode WAL ha d'incloure les escriptures pendents: feu servir l'API de backup de SQLite o una ordre `.backup` mentre s'atura l'escriptura de l'aplicació. Copiar només el fitxer principal mentre hi ha activitat pot deixar dades fora. Guardeu també els fitxers pujats al disc local, si n'hi ha. R2 i els registres Active Storage són coses diferents.

Render Free no proporciona shell/SSH. Si no disposeu de cap via per extreure la BD actual, cal resoldre aquest accés abans del canvi; no es pot prometre recuperar un fitxer del contenidor desaparegut. No afegiu endpoints públics per descarregar la BD. No pengeu backups ni URLs amb contrasenya a GitHub; els backups locals poden anar a `tmp/`, que està ignorat.

## 2. Crear PostgreSQL a Render

1. Creeu una instància Render Postgres a la mateixa regió que el servei web existent. El Blueprint del repositori proposa `hn12a-postgres` i una BD inicial `hn12a`.
2. Confirmeu el pla abans de crear-la. Render Postgres Free caduca als 30 dies: acordeu com mantenir el servei per a les següents revisions/entregues. No activeu recursos de pagament sense acord de l'equip.
3. Al servei web **existent**, configureu `DATABASE_URL` amb la Internal Database URL de PostgreSQL. Les connexions externes des del vostre ordinador utilitzen l'External Database URL amb TLS. No les compartiu al xat.
4. No creeu un segon servei web per error. El fitxer `render.yaml` descriu la configuració desitjada; editar-lo no actualitza necessàriament un servei creat manualment. Si useu Blueprint, reviseu el pla d'aplicació abans d'aprovar-lo i no elimineu cap disc existent sense còpia.
5. Manteniu les variables OAuth i `RAILS_MASTER_KEY`. Configureu R2 amb les variables `STORAGE_*` i `AWS_REQUEST_CHECKSUM_CALCULATION=WHEN_REQUIRED`. L'arrencada rebutja l'absència de `DATABASE_URL` o `STORAGE_BUCKET` perquè no es desin dades noves a l'emmagatzematge efímer per error.

No substituïu les variables del servei actual fins que el codi PostgreSQL hagi estat revisat i la còpia estigui assegurada. Prepareu primer un entorn de prova amb dades sintètiques o una còpia autoritzada.

## 3. Preparar i importar en un entorn controlat

Les migracions creen les taules; no copien les dades de SQLite.

Amb el codi nou, `RAILS_ENV=production`, les variables anteriors i accés al servidor PostgreSQL, executeu:

```sh
bin/rails db:prepare
SQLITE_BACKUP=/ruta/segura/production-backup.sqlite3 bin/rails data:import_sqlite
```

L'importador només escriu a la BD principal i exigeix que les seves taules estiguin buides. No esborra ni actualitza una BD destí ocupada. Llegeix el backup SQLite en mode de només lectura, conserva IDs, timestamps, punts, vots, ocultacions, favorits i metadades d'Active Storage; restaura els pares dels comentaris i reajusta les seqüències. Si una relació és invàlida, la transacció es desfà. La cache i els missatges temporals no es copien. Cal buidar/processar o valorar els jobs pendents abans del canvi; la cua nova comença buida.

Els fitxers d'imatge no es copien amb aquesta ordre. L'import rebutja adjunts que encara apunten a disc local. Primer cal traslladar-los a object storage i obtenir una còpia coherent de les metadades actualitzades. Si ja apunten a `object_storage`, conserva aquesta associació; igualment cal verificar que l'objecte existeixi al bucket configurat.

Si no hi ha cap dada antiga recuperable, documenteu-ho i inicieu una BD buida amb acord de l'equip. No executeu seeds abans d'importar: ocuparien el destí. Els exemples són opcionals i només s'han de carregar de manera explícita quan correspongui.

## 4. Verificació i canvi final

1. En proves, compareu els recomptes de l'importador amb el backup, i comproveu relacions i IDs.
2. Proveu login/logout, URL i Ask, respostes, editar/esborrar contingut propi, vot/unvote, hide/unhide, favorits, llistats i cerca.
3. Proveu pujar, substituir i eliminar avatar/banner. Confirmeu els objectes a R2.
4. Reinicieu o desplegueu de nou l'entorn de prova: les dades i les fotos han de continuar disponibles.
5. Per al canvi final, atureu les noves escriptures, feu la còpia final, importeu-la una sola vegada i connecteu la versió nova al destí validat. No mantingueu dues versions acceptant escriptures contra BDs diferents.
6. Registreu el SHA desplegat, el resultat de la CI i les proves a Taiga #33. No tanqueu la tasca només perquè `/up` retorni 200.

Conserveu la còpia original. Tornar al codi antic no trasllada automàticament les dades noves de PostgreSQL a SQLite: després d'acceptar noves escriptures, qualsevol retorn necessita un pla de dades propi.

## Proves locals amb PostgreSQL

Cal Docker en marxa. Aquest exemple crea una BD temporal, només accessible des del vostre ordinador, amb credencials exclusives de prova:

```sh
docker run --rm --name hn12a-pg-test -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=hn12a_test -p 127.0.0.1:15432:5432 -d postgres:17-alpine
```

A PowerShell:

```powershell
$env:RAILS_ENV = 'test'
$env:PARALLEL_WORKERS = '1'
$env:DATABASE_URL = 'postgresql://postgres:postgres@127.0.0.1:15432/hn12a_test'
ruby bin/rails db:test:prepare test test:system
Remove-Item Env:DATABASE_URL
Remove-Item Env:RAILS_ENV
```

Per aturar i eliminar només el contenidor temporal creat amb `--rm`:

```sh
docker stop hn12a-pg-test
```

## Verificació executada del canvi (12/11/2026)

- Windows, Ruby 3.4.11: 244 tests / 1558 assertions i 24 tests de navegador / 101 assertions, tant amb SQLite com amb PostgreSQL 17; sense errors, fallades ni skips.
- Linux, Ruby 4.0.7 en Docker: construcció de la imatge correcta i 244 tests / 1558 assertions amb PostgreSQL, sense errors, fallades ni skips. Els navegadors s'han provat a Windows; la CI queda configurada per provar-los amb els dos adapters a Linux.
- Mode production local: `db:prepare` crea les quatre bases PostgreSQL i els seus esquemes; Puma i Solid Queue arrenquen; `/up` retorna 200.
- Dades sintètiques conservades després d'eliminar i recrear el contenidor web: usuaris, submission, comentari, punts, vots, ocultació, favorit i metadades/associació del banner. No s'ha pujat cap fitxer a R2 en aquesta prova.
- RuboCop i Brakeman correctes; importmap audit sense paquets vulnerables detectats.
- Aquesta verificació no crea serveis a Render, no demostra la recuperació de les dades antigues i no substitueix la comprovació del bucket real.

## Referències

- https://render.com/docs/deploy-rails-8
- https://render.com/docs/postgresql-creating-connecting
- https://render.com/docs/free
- https://guides.rubyonrails.org/active_record_multiple_databases.html
