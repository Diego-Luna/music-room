# Phase 4 — Rooms (model, membership, visibility, invitations)

## Scope

The shared substrate for the three V.2 services: a `Room` entity
with a `kind` (VOTE / PLAYLIST / DELEGATE), visibility, members and
invitations.

## Model

```prisma
enum RoomKind { VOTE, PLAYLIST, DELEGATE }
enum RoomVisibility { PUBLIC, PRIVATE }
enum MemberRole { OWNER, ADMIN, MEMBER }
enum InvitationStatus { PENDING, ACCEPTED, DECLINED, REVOKED, EXPIRED }

model Room {
  id           String         @id @default(uuid())
  name         String
  description  String?
  kind         RoomKind
  visibility   RoomVisibility @default(PUBLIC)
  ownerId      String
  ...
  // kind-specific columns:
  allowMembersEdit Boolean    @default(true)   // PLAYLIST: license toggle
  voteWindow       VoteWindow @default(ALWAYS) // VOTE: time gating
  voteStartsAt     DateTime?
  voteEndsAt       DateTime?
  voteLocationLat  Float?                       // VOTE: geo gating
  voteLocationLng  Float?
  voteLocationRadiusM Int?
  ...
  currentTrackId   String?  @unique             // playback "now playing" pointer
  delegateUserId   String?                      // DELEGATE: current DJ
  delegateGrantedAt DateTime?
}
```

Three rooms in one model. The alternative (one table per kind) would
duplicate the membership / invitation tables 3 times — not worth it
for the marginal cleanliness gain.

## Member roles

| Role   | Granted to                                   | Powers                                            |
|--------|-----------------------------------------------|---------------------------------------------------|
| OWNER  | Room creator                                  | Everything                                        |
| ADMIN  | Promoted by owner                             | Manage members, moderate playlist tracks         |
| MEMBER | Anyone who joined                             | Vote, suggest, edit playlist (if license allows) |

Stored in `RoomMember.role`. The role check is the predicate used by
`PlaylistService` (only OWNER/ADMIN can edit when
`allowMembersEdit=false`) and by `TracksService.removeTrack` (track
author or OWNER/ADMIN can delete a track).

## Visibility and join flow

| Visibility | `GET /rooms/:id`               | `POST /rooms/:id/join`                     |
|------------|--------------------------------|---------------------------------------------|
| PUBLIC     | Anyone authenticated           | Anyone — creates a `RoomMember`             |
| PRIVATE    | Members + invited only         | Only if a `PENDING` `RoomInvitation` exists |

The invitation, when consumed by the join flow, is updated to
`ACCEPTED` with `respondedAt = now()` — preserves the audit trail.

This is the implementation of the V.2.1 / V.2.3 sentence:
> "By default, your event is public. All the users can find your
> event and vote if your event is public."

For PUBLIC rooms, the chain "find → join → vote" is open to any
authenticated user. For PRIVATE rooms, the chain is gated by the
invitation.

## Invitation lifecycle

```
                  POST /rooms/:id/invitations
                         │
                         ▼
                    ┌────────┐
                    │ PENDING│
                    └───┬────┘
                        │
       ─────────────────┼─────────────────
       │            │           │           │
   accept       decline      revoke      time
   (invitee)    (invitee)    (inviter)   (expiresAt < now)
       │            │           │           │
       ▼            ▼           ▼           ▼
   ACCEPTED     DECLINED    REVOKED      EXPIRED
```

Expiry is enforced at consume time (the join flow filters
`expiresAt > now`). No cron needed — the row stays as `PENDING` in
DB but becomes functionally `EXPIRED`. Could be reaped by a periodic
job if size becomes an issue.

## Soutenance defense points

- *Why one `Room` table for three kinds instead of three tables?* —
  Members, invitations, ownership, visibility are identical across
  the three. Duplicating these would force every cross-cutting
  feature (the realtime gateway, the membership service, the
  invitation service) to handle three model shapes. Pragmatic
  single-table.
- *Why store the time/geo voting config on `Room` and not in a
  dedicated `VoteConfig` table?* — Single-tenant per room, no
  history needed. A side table would add joins on the hot vote
  path for no benefit.
- *What happens if I'm an OWNER and I leave the room?* — Currently
  blocked at the membership service level (`leave()` requires
  ownership transfer first). Avoids orphaning rooms.
- *Can I be in multiple rooms at the same time?* — Yes, the unique
  constraint is `(roomId, userId)` not `userId` alone. The realtime
  gateway subscribes the socket to multiple rooms based on
  membership.
- *Is the invitation flow rate-limited?* — Yes, by the default
  throttler. An attacker spamming `POST /rooms/:id/invitations`
  gets 429 after 100 req/min.
