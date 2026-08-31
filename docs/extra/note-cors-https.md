# Note — CORS HTTPS local (Facebook Login)

`localhost` / `127.0.0.1` **n’importe quel port** est autorisé (`isAllowedCorsOrigin`) — `flutter run -d chrome` prend un port debug aléatoire.

Facebook Login refuse souvent le HTTP clair en local. Si on passe par un proxy `https://localhost:8443`, l’ajouter à `STATIC_ORIGINS` dans `backend/src/common/cors-origin.ts`.
