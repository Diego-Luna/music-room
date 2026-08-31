# Doc sujet (mandatory)

Une page par exigence écrite du PDF. L’API complète n’est **pas** recopiée ici : voir Swagger.

| Paragraphe | Fichier | Ce que ça couvre |
|---|---|---|
| **IV.1** Choix techno, Makefile, pas de vendor | [01-stack.md](01-stack.md) | Bénéfices / inconvénients du stack réel |
| **V.3–V.4** Back = vérité, REST + JSON, live | [02-architecture.md](02-architecture.md) | Rooms, délégation par device, REST vs Socket.IO |
| **V.4** Doc API (méthodes / inputs / outputs) | [03-api.md](03-api.md) | Où est le contrat (Swagger) + carte des ressources |
| **V.6** Sécu, hazards, logs mobile | [04-security.md](04-security.md) | Protections + tableau hazards |
| **V.7** Users simultanés, specs serveur | [05-loadtest.md](05-loadtest.md) | k6, baselines, limites honnêtes |
| **V.8** Agilité, tests par couche, CI, secrets | [06-ci-tests.md](06-ci-tests.md) | GitHub Actions, `make test`, credentials hors git |
| **IV.2 + V.5** App mobile = télécommande | [07-mobile.md](07-mobile.md) | Écrans ↔ consignes, URL back, OAuth |
| Oral | [08-defense.md](08-defense.md) | Phrases à avoir si un évaluateur chipote |

Les **bonus** (web, iBeacon, abo, offline) : code + [`../extra/`](../extra/). Pas scorés tant que le mandatory n’est pas parfait.
