# V.7 — Ramp-up (charge)

Mesurer / justifier le nombre d’users simultanés sur les **3 services**, avec un outil type AB / Gatling / JMeter, en documentant CPU / RAM / cloud vs premise, et un max **cohérent** avec la plateforme.

## Outil

**Grafana k6** (hors liste du PDF, le sujet dit « for instance »). Même famille : seuils p95 / error rate, scripts reproductibles (`backend/loadtest/`, `make loadtest` / `make measure`).

Cinq scénarios **séparés** (pas un run mixte vote + playlist + délégation) :

| Script | Service | Artefact |
|---|---|---|
| `01_auth_burst.js` | Auth (sous-jacent) | `backend/loadtest/results/01_auth_burst.txt` |
| `02_vote_surge.js` | V.2.1 Vote | `.../02_vote_surge.txt` |
| `03_playlist_reorder.js` | V.2.3 Playlist | `.../03_playlist_reorder.txt` |
| `04_realtime_fanout.js` | Socket.IO | `.../04_realtime_fanout.txt` |
| `05_delegation.js` | V.2.2 Delegation (grant/list/revoke) | `.../05_delegation.txt` |

How-to, seuils, troubleshooting : [`backend/loadtest/README.md`](../../backend/loadtest/README.md). Les artefacts de run sont `backend/loadtest/results/*.txt`.

Playback remote **exclu** des k6 : le player est `just_audio` chez l’owner.

## Specs du run baseline

Premise, **localhost** (pas Render). Stack **dans** Colima :

| | |
|---|---|
| Host | Apple M1, 8 cœurs, 8 Go, macOS |
| VM | Colima 2 vCPU / 1.9 GiB |
| Images | Nest (`node:24-alpine`), Postgres 18, Redis 7, Mailpit |

Comparable à un petit cloud (`t4g.small` / `e2-small`). En cloud avec vraie latence, moins de RPS à p95 égal — les chiffres ci-dessous sont un **plafond local**.

## Baselines (thresholds **pass**)

| Service | Charge | p95 | Fail |
|---|---|---|---|
| Vote | 50 VU ~100 s | ~159 ms | 0 % |
| Playlist | 20 VU 45 s | ~41 ms | 0 % |
| Delegation | 40 VU ~100 s | ~70 ms | 0 % |
| Auth | pic ~50 RPS | ~29 ms | 0 % |
| Realtime | ~100 WS | session ~35 s | 2317 msgs reçus |

Claim de capacité : **dizaines–centaines** d’users sur 2 vCPU / ~2 Go. Pas de « milliers » — aligné Raspberry / petit serveur, pas un cluster.

## Limites à dire (pas des KO)

- **Pas un mixte** des 3 services d’un coup. Budget 2 vCPU : le goulot est Postgres ; additionner 50+20+40 VU saturera le pool.
- Vote 50 VU / playlist 20 VU = **1 room par VU**. Ça prouve la charge API, pas N votants sur *une* même track (pour ça : `increment` atomique + unique).
- `measure.sh` assouplit `THROTTLE_LIMIT`, `AUTH_THROTTLE_LIMIT`, `BCRYPT_ROUNDS_OVERRIDE=4`, `AUTH_ALLOW_UNVERIFIED`. La capacité **auth** est donc optimiste. Vote / playlist / délégation (hors setup register) restent représentatifs.
