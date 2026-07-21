# Note — CORS HTTPS local (Facebook Login)

À remettre plus tard dans `backend/src/main.ts`, dans `app.enableCors({ origin: [...] })`.

**Pourquoi :** Facebook Login refuse souvent le plain HTTP en local. Un proxy HTTPS (`https://localhost:8443`) doit être autorisé en CORS.

## Snippet à ajouter

```ts
// Local HTTPS proxy (required to test Facebook Login, which refuses HTTP)
'https://localhost:8443',
```

## Emplacement

Après les origins localhost existantes, par ex. :

```ts
app.enableCors({
  origin: [
    'https://diego-luna.github.io',
    'https://musicroom.me',
    'https://www.musicroom.me',
    'http://localhost:3000',
    'http://localhost:5173',
    'http://localhost:8080',
    // Local HTTPS proxy (required to test Facebook Login, which refuses HTTP)
    'https://localhost:8443',
  ],
  methods: 'GET,HEAD,PUT,PATCH,POST,DELETE,OPTIONS',
  credentials: true,
});
```

Mis de côté le 2026-07-21 avant `git restore` pour switcher de branche.
