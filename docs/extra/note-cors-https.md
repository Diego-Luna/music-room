# Note — CORS HTTPS local (Facebook Login)

Facebook Login refuse souvent le HTTP clair en local. Si on passe par un proxy `https://localhost:8443`, l’ajouter à `app.enableCors({ origin: [...] })` dans `backend/src/main.ts`.

```ts
'https://localhost:8443',
```

Pas mergé : mis de côté (2026-07-21) avant un `git restore`. Origins actuelles : GitHub Pages, musicroom.me, localhost `:3000` / `:5173` / `:8080`.
