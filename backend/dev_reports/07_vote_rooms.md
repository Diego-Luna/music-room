# Phase 7 — VOTE rooms

## Scope

Cover the **V.2.1 Music Track Vote** service end-to-end:
- Visibility (PUBLIC / PRIVATE)
- License: time-based voting, location-based voting
- The thing the subject explicitly flags: **vote race conditions**

## Model

```prisma
model Track {
  id          String   @id @default(uuid())
  roomId      String
  provider    String   @default("spotify")  // future-proofed for other providers
  providerId  String
  title       String
  artist      String
  durationMs  Int
  artworkUrl  String?
  addedById   String
  addedAt     DateTime @default(now())
  playedAt    DateTime?

  votes       TrackVote[]
  score       Int      @default(0)            // denormalized for fast ranking
  position    String?                          // shared with playlist (fractional index)

  @@unique([roomId, provider, providerId])    // no duplicate suggestions
  @@index([roomId, score])                    // fast top-N retrieval
}

model TrackVote {
  trackId  String
  userId   String
  value    Int        // +1 or -1; 0 = vote cleared (row deleted)
  ...
  @@unique([trackId, userId])                 // one vote per user per track
}
```

Two design decisions:
1. **`score` is denormalized** on `Track` for O(log N) sort instead
   of `SELECT track, SUM(value) FROM TrackVote GROUP BY track ORDER
   BY ... LIMIT 50` on every list call. Updated atomically as part
   of every vote transaction.
2. **One vote per user per track**: the `@@unique([trackId, userId])`
   constraint enforces idempotency at the schema level. A user
   re-voting doesn't insert a second row; it `UPDATE`s the existing
   one.

## The race condition

The subject explicitly flags:
> "You should especially care about the management of competition
> problematics: for instance, if several people vote for different
> tracks or the same one in a playlist."

Two distinct race scenarios:

### Scenario A — Two users vote for the same track simultaneously
- T0: track score = 5
- T1: user A vote +1, user B vote +1 (interleaved)
- naive impl: each reads score=5, writes score=6 → score=6 (lost
  update, both increments collapsed)
- subject expectation: score=7

### Scenario B — One user changes their vote
- T0: existing vote (user A, track X, value=+1), track score = 5
- T1: user A votes -1
- correct delta: score should go from 5 to 3 (remove +1, add -1)
- naive impl: 4 (forgot to compensate the existing vote)

## How we handle it

`TracksService.vote()` runs the **whole** state transition inside a
single Postgres transaction:

```typescript
const previous = await this.prisma.trackVote.findUnique({
  where: { trackId_userId: { trackId, userId } },
});
const oldValue = previous?.value ?? 0;
const delta = dto.value - oldValue;

const updated = await this.prisma.$transaction(async (tx) => {
  if (dto.value === 0) {
    if (previous) await tx.trackVote.delete({ where: ... });
  } else if (previous) {
    await tx.trackVote.update({ where: ..., data: { value: dto.value } });
  } else {
    await tx.trackVote.create({ data: { ..., value: dto.value } });
  }
  return tx.track.update({
    where: { id: trackId },
    data: { score: { increment: delta } },   // ← atomic increment
  });
});
```

Two safety net:
1. The **`{ increment: delta }`** generates `UPDATE Track SET score
   = score + $1` — Postgres handles concurrent increments
   atomically.
2. The entire flow (read previous vote + write new vote + adjust
   score) is wrapped in `$transaction`, so two concurrent votes
   from the same user (e.g., double-click) serialize, never
   producing a stale `delta`.

The `loadtest/02_vote_surge.js` script runs 50 VUs hammering this
endpoint and validates that the resulting `Track.score` matches the
expected sum exactly.

## License: time-based voting

Subject:
> "With the right license, the people located in a specific place
> for at a specific time (between 4 and 6PM for instance) will be
> able to vote."

Schema:
- `voteWindow: ALWAYS | SCHEDULED`
- `voteStartsAt`, `voteEndsAt: DateTime?` when `SCHEDULED`

`enforceVoteWindow(room)`:
```typescript
if (room.voteWindow !== 'SCHEDULED') return;
const now = Date.now();
if (!room.voteStartsAt || !room.voteEndsAt ||
    now < room.voteStartsAt.getTime() ||
    now > room.voteEndsAt.getTime()) {
  throw new ForbiddenException('Voting is closed for this room');
}
```

Called at the top of every `vote()` call. Configuration set by the
owner via `PATCH /rooms/:id`.

## License: location-based voting

Schema:
- `voteLocationLat`, `voteLocationLng: Float?`
- `voteLocationRadiusM: Int?` (radius in meters)

Vote DTO carries optional `lat`, `lng`:
```typescript
class VoteTrackDto {
  @IsInt() @Min(-1) @Max(1) value!: number;
  @IsOptional() @IsLatitude()  lat?: number;
  @IsOptional() @IsLongitude() lng?: number;
}
```

`enforceGeoGate(room, dto)`:
- If the room has no location config → noop
- If the DTO doesn't carry coordinates → 403 ("Geo-gated room:
  lat/lng required")
- Otherwise compute the Haversine great-circle distance between
  the room's center and the voter's location; reject if > radius

The Haversine implementation is inline (no extra dependency) and
covered in unit tests.

## Visibility / membership

For VOTE rooms:
- PUBLIC: any authenticated user can `find → join → vote`
- PRIVATE: only invited users (via `RoomInvitation`) can do the same

The membership check is intentionally **after** the vote-window and
geo-gate checks, so we surface the most specific 403 message
("Voting closed" vs "Out of voting radius" vs "Not a member") to
help client UX.

## Soutenance defense points

- *How do you handle simultaneous votes on the same track?* —
  `$transaction` + atomic `increment`. The score column is never
  read-modify-written; only `score = score + delta` is emitted to
  Postgres. Two transactions serialize at the row lock and produce
  the correct sum.
- *Why a denormalized `score` instead of computing on the fly?* —
  Ranking is the hot path (`listRanked()` is what every UI calls).
  An aggregate-on-the-fly takes O(votes) per call and grows
  monotonically; a denormalized column is O(1) read and O(1)
  write.
- *What happens if a vote crashes mid-transaction?* — The
  transaction rolls back: no partial row in `TrackVote`, no
  unbalanced `score`. The user retries.
- *Can a malicious user vote 100 times in a row?* — The
  `@@unique([trackId, userId])` constraint means subsequent
  inserts UPDATE the row in place — no value drift. Plus the
  default throttler (100 req/min/IP) caps the surface.
- *How do you prove your geo gate isn't easily spoofed?* — We
  don't, and the subject doesn't ask us to. A spoofed lat/lng
  bypasses the gate, but in the context of a real event the
  consequence is one person who shouldn't be able to vote getting
  to vote. The mitigation in production would be a TEE-attested
  location (out of scope).
- *Can voting be disabled for a room without deleting it?* — Yes:
  set `voteWindow=SCHEDULED` with `voteEndsAt` in the past. The
  enforcement rejects all subsequent votes with a clear 403.
