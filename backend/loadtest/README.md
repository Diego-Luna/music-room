# Music Room — Load Tests (k6)

Scripts here target the Phase 1–9 surface. They are safe to run
against a locally running backend (`docker compose up -d` + `make dev`)
and do **not** require a Spotify account — the scenarios that would
hit Spotify (`playback:*`) are excluded on purpose so the test
closes a loop entirely on our servers.

## Prerequisites

- `k6` installed: `brew install k6` or see https://k6.io/docs/get-started/installation/
- Backend running on `http://localhost:3000`
- A clean-ish dev database (the scripts register random users)

## Scenarios

| Script                       | Purpose                                                  |
|------------------------------|----------------------------------------------------------|
| `01_auth_burst.js`           | Register + login 50 users in parallel                    |
| `02_vote_surge.js`           | 50 voters × 10 tracks × 2 vote flips in a VOTE room      |
| `03_playlist_reorder.js`     | 20 editors drag-reordering items in a PLAYLIST room      |
| `04_realtime_fanout.js`      | 100 subscribers on one room receiving 500 events         |

Each script sets `thresholds` that fail the run if p95 latency or
error rate goes above what's acceptable for the subject
soutenance.

## Running

```sh
# Burst of account creation
k6 run loadtest/01_auth_burst.js

# Heavy VOTE scenario (expects a pre-seeded room id — override via env)
BASE_URL=http://localhost:3000 k6 run loadtest/02_vote_surge.js
```

See `dev_reports/11_loadtest.md` for baseline numbers recorded on a
2024 MacBook Air M3.
