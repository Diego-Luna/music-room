# V.8 — Agilité, tests, CI, secrets

## Agilité

Deux auteurs (Diego, Jérémy). Branches `main` / `dev` / `frontend`. Makefile racine (`install` / `test` / `dev` / `up`). Pivot assumé : Spotify → Deezer ; rooms `DELEGATE` → délégation par device.

## Tests par couche

| Couche | Où |
|---|---|
| Unit back | `backend/src/**/*.spec.ts` (controllers, services — chaque `*.service.ts` a un spec —, guards, filters, middleware, strategies) |
| E2E back | `backend` vitest e2e (auth, health, hardening, rate-limit, realtime, delegation) contre Postgres + Redis |
| Unit / widget front | `frontend/music_room_app/test/` |
| Integration front | `integration_test/offline_mode_test.dart` (bonus VI.4 ; pas dans le workflow PR) |
| Charge | k6 (V.7) |

```sh
make test            # back unit + flutter test
make test-backend    # délégué à backend/Makefile
cd backend && make test-e2e
```

## Intégration continue (GitHub Actions)

| Workflow | Quand | Quoi |
|---|---|---|
| `backend-ci.yml` | push / PR, paths `backend/**`, branches `main` et `backend` | `npm ci`, Postgres 18 + Redis, Prisma, build, unit, e2e |
| `validate-pr.yml` | PR vers `dev` / `main`, paths `frontend/**` | `flutter test` + `flutter build web` |
| `deploy-main.yml` | push `main` (front) | build web + GitHub Pages — **sans** `flutter test` (la gate tests = les PR) |

Pas dans CI aujourd’hui : `flutter analyze`, `integration_test`, k6. La branche trigger `backend` n’existe plus forcément sur le remote ; `dev` n’est pas dans `backend-ci.yml`.

## Credentials hors git

- `backend/.env` gitignoré (racine aussi : `.env`, `.env.local`, `.env.*.local`).
- Placeholders : `backend/.env.example`. Schéma Joi : `src/config/env.validation.ts`.
- OAuth secrets : `local.properties` / `Secrets.xcconfig` / GitHub `secrets.*` / `--dart-define`.
- Compose : `env_file: backend/.env`.

**Pas des secrets** (IDs publics) : Google client ID dans `Info.plist` / `web/index.html` ; Facebook App ID. Client secret / client token restent hors git.

Mot de passe seed `prisma/seed.ts` : compte **démo local**, pas une clé API. Ne pas le réutiliser en prod.
