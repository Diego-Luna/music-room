# Oral — ce qui n’est pas un KO

Phrases courtes si un évaluateur chipote. Le code mandatory est OK ; ceci évite de se faire coller sur un détail.

## Produit / licences

- **Inbox « a private room »** : tant que l’invite est pending, `GET /rooms/:id` est 404 (volontaire). L’invité trouve la room dans l’inbox, pas dans Events / Playlists. Le DTO d’invitation n’embarque pas le nom.
- **Pas de GPS device** : lat/lng du vote = Settings → Vote location. Suffisant ordi ; pas le GPS OS.
- **Geo / créneau** : réglés à la **création**. Edit Room change « who can vote », pas la geofence ni la fenêtre.
- **Playlist / vote privés** : même modèle. « Find » = inbox après invite, pas la search publique.
- **Éditer une playlist = Premium** (bonus VI.3). Un FREE voit / rejoint, pas add / move / remove. Switch = `PUT /subscription/me` (pas Stripe). Ce n’est pas un trou V.2.3.
- **musicPreferences** : pas de matching auto d’amis / playlists. Recherche + playlists publiques.

## Concurrence / charge

- Deux clics vote du *même* user : unique `(trackId, userId)` → 409. `previous` lu hors tx : TOCTOU théorique.
- Deux inserts playlist dans le même trou : `generateKeyBetween` déterministe → même `position` possible ; `addedAt` départage.
- k6 : **1 room par VU**. Preuve de charge API, pas N éditeurs sur une liste. Indexation fractionnaire = pas de renumérotation globale.
- Pas de run mixte 3 services. Postgres est le goulot sur 2 vCPU.

## Offline (bonus)

Hive = file + cache. Conflit → le **serveur** gagne (409 discard, snapshot `/sync`). Les votes offline ne sont pas une vérité locale.

## Mail / OAuth / iOS

- Sans SMTP / Mailpit, vérif + reset n’envoient pas de liens. UI Mailpit : `http://localhost:8025`.
- `AUTH_ALLOW_UNVERIFIED` : load tests uniquement.
- Reset front : longueur ≥ 8 ; le back exige aussi maj / min / chiffre.
- Liens mail → front **web** (`/#/auth/...`). Reset a un champ coller token ; verify non.

## CI

Gate tests front = **PR** (`validate-pr.yml`). Un push direct `main` déploie le web sans retester. Savoir le dire.
