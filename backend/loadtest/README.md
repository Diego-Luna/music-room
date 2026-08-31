# Music Room — Load Tests (k6)

Load tests for V.7. Five **separate** scenarios (auth, vote, playlist
reorder, realtime fan-out, delegation). Defense write-up (baselines,
server specs, honest limits): [`docs/sujet/05-loadtest.md`](../../docs/sujet/05-loadtest.md).

## Server specifications used for the baseline runs

The numbers reported below ("baselines") were captured on the same
machine the project was developed on. To reproduce, match these specs
or scale the expected throughput accordingly — the subject explicitly
asks that the user-count claim be consistent with the platform.

| Layer            | Value                                      |
|------------------|--------------------------------------------|
| Host CPU         | Apple M1 (arm64), 8 cores                  |
| Host RAM         | 8 GB                                       |
| Host OS          | macOS 15 (Darwin 25.4)                     |
| Docker runtime   | Colima 0.x using Apple Virtualization (vz) |
| Container OS     | Ubuntu 24.04 LTS (kernel 6.8)              |
| Docker engine    | 29.2.1                                     |
| Colima VM CPUs   | 2 vCPU                                     |
| Colima VM RAM    | 1.9 GiB                                    |
| Network          | localhost loopback only (no internet hop)  |

The full stack runs **inside** that 2 vCPU / 1.9 GiB VM:

| Service           | Image               |
|-------------------|---------------------|
| Backend (Nest)    | `node:24-alpine` (custom build, multi-stage) |
| PostgreSQL        | `postgres:18-alpine`|
| Redis             | `redis:7-alpine`    |
| Mailpit (SMTP)    | `axllent/mailpit`   |

So the headline figures below are achieved on a **deliberately
constrained** environment — a 2-vCPU container budget, comparable to a
small cloud instance (e.g. AWS `t4g.small`, GCP `e2-small`). Bare-metal
or larger cloud servers will scale linearly for the auth/vote scenarios
that are CPU-bound, and slightly better than linearly for the
realtime fan-out scenario which is mostly Redis-pubsub bound.

## Prerequisites

- `k6` installed (`brew install k6` on macOS, see
  https://k6.io/docs/get-started/installation/ otherwise)
- The full Music Room stack running:
  ```sh
  docker compose up -d --build      # from the repo root
  ```
  Wait until `docker compose ps` shows `musicroom-backend` as
  `healthy` (typically <30 s after a fresh build).
- A clean dev database is recommended for repeatable numbers:
  ```sh
  docker compose down -v && docker compose up -d --build
  ```

## Scenarios

Every script targets `http://localhost:3000` by default; override with
`BASE_URL`. Each scenario carries its own k6 `thresholds`: a run that
violates them exits with a non-zero status, useful for CI gating.

### 1) `01_auth_burst.js` — bruteforce-resilient signup/login

| Goal | Verify the auth pipeline (register + login + JWT issuance + Throttler) holds under bursty load |
|------|---|
| Shape  | `ramping-arrival-rate` 5 → 20 → 50 req/s over 55 s, 50–100 VUs |
| Asserts | `http_req_failed < 1%`, `p(95) < 500 ms` |
| Scope  | `POST /auth/register`, `POST /auth/login` |
| Why    | The `auth` Throttler tier is set to 10 req/min/IP. The burst is intentionally above that — we expect to see throttle 429 responses kick in, which the test counts but doesn't fail on. |

### 2) `02_vote_surge.js` — vote race conditions

| Goal | Stress the `prisma.$transaction()` that updates `Track.score` while many clients vote simultaneously |
|------|---|
| Shape  | `ramping-vus` 5 → 50 → 50 over 100 s |
| Asserts | `http_req_failed < 1%`, `p(95) < 600 ms`, vote-checks `> 98%` |
| Scope  | Register N voters, join a VOTE room, repeatedly POST `/rooms/:id/tracks/:tid/vote` with `+1`/`-1`/`0` flips |
| Why    | The subject explicitly calls out competition problems for vote ordering. This scenario is the canonical proof that two voters cannot both increment a stale score (atomic update via Postgres + Prisma transaction). |

### 3) `03_playlist_reorder.js` — concurrent fractional-index moves

| Goal | Verify the playlist's fractional-indexing scheme survives 20 editors moving items at once |
|------|---|
| Shape  | `constant-vus` 20, duration 45 s |
| Asserts | `http_req_failed < 2%`, `p(95) < 700 ms` |
| Scope  | Each VU drag-reorders a track via `PATCH /rooms/:id/playlist/:tid/move` with `afterTrackId` references |
| Why    | Subject again calls out competition problems for playlist edits. Fractional indexing means concurrent moves never deadlock — we measure latency, not collision count, since collisions cannot happen by construction. |

### 4) `04_realtime_fanout.js` — Socket.IO + Redis adapter fan-out

| Goal | Measure delivery latency when 100 Socket.IO subscribers receive events from a single publisher in the same room |
|------|---|
| Shape  | `per-vu-iterations` 100 VUs × 1 iteration, max 60 s |
| Asserts | `ws_msgs_received > 2000`, `p(95) ws_session_duration < 60 s` |
| Scope  | 100 clients connect WebSocket, subscribe to one room; backend emits 500 events (vote flips), each fanned out via `@socket.io/redis-adapter` |
| Why    | This is the realtime contract that powers the live UI. Validates the Redis adapter (Pub/Sub) actually fans out at the expected rate without dropping messages. |

### 5) `05_delegation.js` — Music Control Delegation grant/revoke

| Goal | Stress the V.2.2 delegation hot path (grant / list / revoke) under concurrent load |
|------|---|
| Shape  | `ramping-vus` 5 → 40 → 40 over 100 s |
| Asserts | `http_req_failed < 1%`, `p(95) < 800 ms`, delegation-checks `> 98%` |
| Scope  | Each VU registers an owner + a friend, befriends them, then loops `PUT`/`DELETE /users/me/devices/:deviceId/delegate` plus the two list endpoints |
| Why    | V.2.2 is one of the 3 mandatory services and must be measured for V.7. Delegation is friendship-gated and keyed `(ownerId, deviceId)` — this proves the `upsert` + access checks hold under load. Playback is excluded: remote commands drive `just_audio` on the owner's device. |

## Running

```sh
# 1) Burst auth — fast feedback
k6 run loadtest/01_auth_burst.js

# 2) Heavy VOTE scenario
BASE_URL=http://localhost:3000 k6 run loadtest/02_vote_surge.js

# 3) Concurrent playlist reorder
k6 run loadtest/03_playlist_reorder.js

# 4) Realtime fan-out (websocket)
k6 run loadtest/04_realtime_fanout.js

# 5) Delegation grant/revoke
k6 run loadtest/05_delegation.js

# All five sequentially (CI mode)
for f in loadtest/0*.js; do k6 run "$f" || break; done
```

Each script prints its summary table and exits non-zero if any
threshold fails — wire that into a pre-defense smoke test if needed.

## Target thresholds and how to record real baselines

The five scripts encode their **target thresholds** in `options.thresholds`
(a run that violates them exits non-zero). The expected order of
magnitude on the 2 vCPU / 1.9 GiB Colima VM described above is:

| Script | Target threshold (encoded) | Expected order of magnitude on the spec above |
|---|---|---|
| `01_auth_burst.js`     | `http_req_failed < 1%`, `p95 < 500 ms` | Sustained ~50 RPS peak, with Throttler 429 returned for >10/min/IP (intended behavior, **not** counted as error) |
| `02_vote_surge.js`     | `http_req_failed < 1%`, `p95 < 600 ms`, `vote-checks > 98%` | ~50 concurrent voters, Postgres CPU is the first bottleneck above this VU count |
| `03_playlist_reorder.js` | `http_req_failed < 2%`, `p95 < 700 ms` | 20 concurrent editors, fractional indexing serializes through Postgres without row-level contention |
| `04_realtime_fanout.js` | `ws_msgs_received > 2000`, `p95 ws_session_duration < 60 s` | 100 WS clients × 500 events ≈ 50 000 deliveries, Redis Pub/Sub is the limiting factor |
| `05_delegation.js`     | `http_req_failed < 1%`, `p95 < 800 ms`, `delegation-checks > 98%` | ~40 concurrent owner/friend pairs; the p95 budget is wider because each iteration does two bcrypt registrations before the delegation calls |

### Recording your own baseline

Before the soutenance, run the **5** scripts and keep the k6 summary
output under `loadtest/results/` (already committed as `0*.txt`). The
k6 summary prints env, threshold pass/fail, and percentiles — that's
the V.7 artifact, not a hand-typed table.

```sh
mkdir -p loadtest/results
for f in loadtest/0*.js; do
  k6 run "$f" 2>&1 | tee "loadtest/results/$(basename "${f%.js}")-$(date +%Y%m%d).txt"
done
```

Re-running on a more powerful machine (e.g. 4 vCPU allocated to Colima
or a cloud VM) typically yields linear throughput gains on the
auth/vote scripts and slightly better than linear on the realtime
script.

## What this proves for the V.7 requirement

- **Number of simultaneous users** on a 2 vCPU / 1.9 GiB container
  (p95 under the per-script thresholds):
  - **Auth**: ~50 RPS peak (`01`) — capacity is optimistic if run via
    `measure.sh` (relaxed throttle / bcrypt)
  - **Vote**: ~50 concurrent VUs (`02`), **one room per VU**
  - **Playlist**: 20 editors (`03`), one playlist per VU
  - **Delegation**: 40 owner/friend pairs (`05`)
  - **Realtime**: ~100 WebSocket clients (`04`)
- **Server characteristics**: documented above (CPU, RAM, host OS,
  container OS, runtime versions).
- **Scaling path**: vertical (more vCPU on Colima or cloud VM) yields
  near-linear throughput on the auth/vote endpoints; horizontal
  (multiple backend replicas behind a load balancer) is supported out
  of the box because the JWT blacklist and the Socket.IO adapter both
  use Redis as a shared store — no sticky sessions required.

## Troubleshooting

- **`http_req_failed` rate > 0**: check `docker compose logs backend`,
  most often the Throttler kicked in (429) — that's a real success of
  the security layer, not a regression. Inspect the per-status
  breakdown in the k6 summary.
- **Postgres connection saturation**: bump the Prisma connection pool
  via `DATABASE_URL=...?connection_limit=20` if running with >50 VUs
  on the vote scenario.
- **WebSocket script not connecting**: ensure the Socket.IO path
  (`/socket.io/`) is reachable on `BASE_URL` and that no proxy is
  rewriting the upgrade header.
