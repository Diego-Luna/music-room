# Music Room

App collaborative 42 : comptes, vote live, playlists temps réel, délégation du player par device. Backend NestJS + PostgreSQL ; client Flutter (iOS / Android / web).

**Doc soutenance** : [`docs/sujet/`](docs/sujet/) — stack, API, sécu, charge, CI, mobile.  
**Doc interne / bonus** : [`docs/extra/`](docs/extra/).  
**Contrat API** : `http://localhost:3000/api/docs` (Swagger).

## Quick start

Prérequis : Node 24, Flutter stable, Docker (Colima / Docker Desktop), optionnel `k6`.

```sh
cp backend/.env.example backend/.env   # JWT secrets au minimum
make install
make up                                # Postgres, Redis, Mailpit, backend :3000
```

App : `cd frontend/music_room_app && flutter run`  
URL du back configurable dans Login / Settings (émulateur Android : `http://10.0.2.2:3000`).

Mails de vérif / reset : Mailpit `http://localhost:8025`.

```sh
make test          # unit back + flutter test
make loadtest      # k6 (stack déjà up)
make down
```

Détail back : [`backend/README.md`](backend/README.md). Front : [`frontend/README.md`](frontend/README.md). Charge : [`docs/sujet/05-loadtest.md`](docs/sujet/05-loadtest.md).
