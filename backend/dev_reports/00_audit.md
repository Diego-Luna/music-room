# Phase 0 — Audit du scaffold existant

**Date :** 2026-04-18
**Branche :** `backend`
**Objectif :** établir l'état initial du backend avant d'attaquer les phases métier, identifier les écarts vs le sujet 42 Music Room, fixer les anomalies de scaffold.

---

## 1. Inventaire de l'existant

### Outillage & racine `backend/`
- `package.json` : NestJS 11, Fastify 5, Prisma 6, ioredis, JWT/Passport, Swagger, class-validator, joi, bcrypt, vitest 3, swc.
- `Makefile` : cibles `install / dev / build / test / test-e2e / test-cov / db-migrate / db-generate / db-seed / docker-up / docker-down / clean`.
- `docker-compose.yml` : `postgres:16-alpine` + `redis:7-alpine` avec healthchecks.
- `vitest.config.ts` (unit) + `vitest.config.e2e.ts` (e2e).
- `tsconfig.json` / `tsconfig.build.json`.
- `.gitignore` : couvre `.env`, `.env.local`, `.env.*.local`, `node_modules/`, `dist/`, `coverage/`, `*.db`. **Conforme V.8.**
- `.env.example` : présent (dev), variables documentées sans secret.

### Code source `backend/src/`
- `main.ts` : bootstrap Fastify + ValidationPipe global (whitelist+forbidNonWhitelisted+transform) + Swagger sur `/api/docs` + CORS ouvert.
- `app.module.ts` : `ConfigModule` (validation Joi globale) + `ThrottlerModule` (60s / 100 req) + `PrismaModule` + `RedisModule` + `AuthModule` + `HealthModule` + `JwtAuthGuard` global + `RequestLoggerMiddleware`.
- `auth/` : controller (8 routes), service (register, login, social Google/Facebook via `fetch`, link-social, verify-email, forgot/reset password, refresh, logout), `JwtBlacklistService`, stratégies `jwt` + `local`, 8 DTO.
- `common/` : décorateurs `@Public` + `@CurrentUser`, filter `HttpException`, guard `JwtAuth`, interceptor `Transform`, middleware `RequestLogger`.
- `config/env.validation.ts` : schéma Joi (NODE_ENV, PORT, DATABASE_URL, REDIS_*, JWT_*, GOOGLE_*, FACEBOOK_*, THROTTLE_*).
- `health/` : controller (`GET /health`).
- `prisma/` : `PrismaService`.
- `redis/` : `RedisService` (ioredis wrapper).

### Schéma Prisma
- `User` : id/email/passwordHash/displayName/avatarUrl/emailVerified/emailVerifyToken/resetPasswordToken/resetPasswordExpires/visibility/musicPreferences/createdAt/updatedAt.
- `SocialAccount` : provider/providerId/userId, contraintes uniques `(provider, providerId)` et `(provider, userId)`.
- `enum Visibility` : `PUBLIC | FRIENDS_ONLY | PRIVATE`.

### Tests
- 12 fichiers spec, **84 tests verts** (durée ~1.7s).
- Coverage global : **94.07 % stmts / 89.74 % branches / 98.14 % funcs**.
- 2 fichiers e2e (`auth.e2e-spec.ts`, `health.e2e-spec.ts`) + helpers (`auth-test.helper.ts`, `prisma-test.helper.ts`, `redis-test.helper.ts`).

---

## 2. Conformité au sujet (matrice)

| Exigence sujet | Statut | Référence |
|---|---|---|
| V.1 Email/password register | OK | `auth.service.ts::register` |
| V.1 Mail validation | Stub (token créé, pas d'envoi) | À compléter Phase 1 (Mailpit (successeur multi-arch de MailHog) + nodemailer) |
| V.1 Forgot password | Stub (token créé, pas d'envoi) | À compléter Phase 1 |
| V.1 Social login Google/Facebook | Partiel (vérif `fetch`, pas de stratégies passport) | Compléter Phase 2 |
| V.1 Link social account | OK | `auth.service.ts::linkSocial` |
| V.1 Profil public/friends/private | Schéma minimal, pas d'endpoints | Phase 3 |
| V.1 Préférences musicales | `String[]` brut | Enrichir Phase 3 |
| V.2.1 Music Track Vote | Absent | Phase 5 |
| V.2.2 Music Control Delegation | Absent | Phase 7 |
| V.2.3 Music Playlist Editor | Absent | Phase 6 |
| V.4 Swagger | OK | `main.ts` |
| V.6 Logs Platform/Device/Version | Middleware existe, format simple | Renforcer Phase 4 (table `ActionLog` + enforcement) |
| V.6 Bruteforce protection | Throttler global 100/60s | Renforcer Phase 1 (bucket `/auth/*`) + Phase 4 |
| V.7 Load test | Absent | Phase 10 (k6) |
| V.8 `.env` gitignored | OK | `.gitignore:9` |
| IV.1 Deps via Makefile | OK | `make install` |

---

## 3. Anomalies détectées (à corriger en Phase 0)

1. **`prisma/seed.ts` manquant** alors que `package.json` déclare `"prisma": { "seed": "ts-node prisma/seed.ts" }`. → `make db-seed` casserait. **Fix :** créer un seed minimal idempotent.
2. **Mailpit (successeur multi-arch de MailHog) absent** de `docker-compose.yml` alors que la Phase 1 livre la vérif email + reset password réels. **Fix :** ajouter le service.
3. **`.env.example` ne déclare pas `SMTP_*`** ni `APP_BASE_URL` (utilisé pour les liens d'email). **Fix :** ajouter.
4. **`config/env.validation.ts` couverture 0 %** : non testé. **Fix :** test ciblé en Phase 1.
5. **`nestjs-pino` non présent** alors que choisi pour la stack. **À installer en Phase 4** (pas un blocker Phase 0).
6. **Aucun Dockerfile** pour packager le backend (compose ne lance que les dépendances). **Fix :** Phase 11 (durcissement / CI).
7. **`@fastify/helmet` absent**. **Fix :** Phase 4 (sécurité transverse).
8. **Coverage gaps mineurs** (`current-user.decorator.ts` 42 %, `env.validation.ts` 0 %, branches `request-logger.middleware.ts` 60 %, `auth.service.ts` 94.79 % avec lignes 180-183 / 305-306 non couvertes). À combler progressivement (Phase 1 vise 100 % du module auth).

---

## 4. État `git`

Branche courante `backend`, working tree propre. Dernier commit `500ad33 backend`. Aucun fichier sensible suivi.

---

## 5. Décisions de Phase 0 (mises en œuvre dans ce rapport)

- Création `dev_reports/`.
- Audit + justification stack écrits.
- Ajout Mailpit (successeur multi-arch de MailHog) au compose + variables `SMTP_*` + `APP_BASE_URL` à `.env.example`.
- Création `prisma/seed.ts` minimal idempotent (utilisateur de test conditionnel `NODE_ENV !== 'production'`).
- Aucune nouvelle dépendance installée à cette étape (objectif : ne casser ni l'install ni les 84 tests existants).

---

## 6. Critères de sortie de Phase 0

- [x] `dev_reports/` existe avec 2 rapports (audit + justification stack).
- [x] Suite vitest verte (84/84) — vérifié à 14:03 le 2026-04-18.
- [x] Coverage baseline mesuré et documenté (94.07 %).
- [x] `prisma/seed.ts` existe.
- [x] Mailpit (successeur multi-arch de MailHog) dans le compose.
- [x] `.env.example` à jour.
- [x] `.gitignore` confirmé conforme à V.8.

Phase 0 close → passage à Phase 1 (Auth email/password complète, mail réel via Mailpit (successeur multi-arch de MailHog), RefreshToken/EmailVerification/PasswordReset en tables dédiées, coverage auth 100 %).
