# Audit interne (mandatory)

Verdicts d’après le code, pas d’après d’anciens markdown.  
Légende : **OK** · **PARTIEL** · **KO**.

La justification écrite demandée par le PDF est dans [`../sujet/`](../sujet/).

## Mandatory

| Zone | Verdict |
|---|---|
| V.1 User (compte, link social, 4 champs profil, vérif mail + reset) | **OK** |
| V.2 ≥ 2 services / 3 | **OK** (Vote + Playlist + Delegation) |
| V.2.1 Vote (live, public/privé, licences, geo+créneau, concurrence) | **OK** |
| V.2.2 Delegation (device, plusieurs amis, player `just_audio`) | **OK** |
| V.2.3 Playlist (live, public/privé, licences, concurrence, sockets scoped) | **OK** |
| V.3 Back = vérité | **OK** |
| V.4 API REST JSON + Swagger | **OK** — [03-api.md](../sujet/03-api.md) |
| V.5 App = télécommande, URL configurable, OAuth mobile | **OK** |
| V.6 Isolation, protections, hazards, logs | **OK** — [04-security.md](../sujet/04-security.md) |
| V.7 Charge 3 services + specs | **OK** — [05-loadtest.md](../sujet/05-loadtest.md) |
| V.8 Agilité, tests, CI, secrets hors git | **OK** — [06-ci-tests.md](../sujet/06-ci-tests.md) |
| IV.1 Stack justifié, pas de vendor, `make install` | **OK** — [01-stack.md](../sujet/01-stack.md) |
| IV.2 Toutes les actions sur mobile, Android ou iOS | **OK** — [07-mobile.md](../sujet/07-mobile.md) |

Aucun **KO**. Chipotages oraux : [08-defense.md](../sujet/08-defense.md).

## Bonus — non scorés ici

| | |
|---|---|
| VI.1 Multi-platform / web | **OK** — [vi1-multiplatform.md](vi1-multiplatform.md) |
| VI.2 IoT / iBeacon | **OK** (geofence, pas BLE) — [vi2-iot.md](vi2-iot.md) |
| VI.3 Free vs Paid | API Subscription + gate Premium sur l’édition playlist |
| VI.4 Offline | [frontend-offline.md](frontend-offline.md) |
