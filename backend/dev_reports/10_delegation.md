# Phase 10 — Music Control Delegation (V.2.2)

## Scope

The third V.2 service: **delegate music control to a friend**. Subject
text in full (V.2.2):

> "Music control delegation.
>
> A license management must be integrated to the service. It must be
> specific for each device attached to the user's account. The user
> can choose to give the music control to different friends."

Three sentences, and — unlike V.2.1 (event-scoped) and V.2.3
(playlist-scoped) — **no mention of a room, event or playlist**. V.2.2
is scoped to the *account and its devices*, not to a room.

## What we built

A standalone module, `src/delegation/`, with no coupling to rooms.

### Data model

```prisma
model MusicControlDelegation {
  id             String   @id @default(uuid())
  ownerId        String
  owner          User     @relation("DelegationOwner", ...)
  deviceId       String
  delegateUserId String
  delegate       User     @relation("DelegationDelegate", ...)
  grantedAt      DateTime @default(now())

  @@unique([ownerId, deviceId])
  @@index([delegateUserId])
}
```

`deviceId` is the value of the `X-Device` header — the same device
identifier already captured by the V.6 logging middleware. The
`@@unique([ownerId, deviceId])` constraint means **one delegate per
device**: the owner can delegate their phone to Alice and their tablet
to Bob independently, which is exactly *"give the music control to
different friends"*.

### Service — `DelegationService`

- `grant(ownerId, deviceId, delegateUserId)` — upsert on
  `(ownerId, deviceId)`. Enforces: not self, delegate exists, and the
  delegate **is a friend** (`FriendsService.areFriends`, else 403).
  Emits `device:delegation:granted` to the delegate; if control moved
  away from a previous delegate, emits `device:delegation:revoked` to
  the old one.
- `revoke(ownerId, deviceId)` — deletes the delegation, notifies the
  ex-delegate.
- `getCurrent` / `listMyDelegations` / `listControlledDevices` — reads.

### Playback — `DelegationPlaybackService`

The delegate is a **remote control, not the audio source**. Playback
commands (`play`, `pause`, `next`, `previous`, `setVolume`) always run
against the device **owner's** Spotify token. Either the owner or the
current delegate of a delegation may issue commands; anyone else gets
a 403.

## Why this is per-device (and not per-room)

The old implementation (`RoomKind.DELEGATE` + `Room.delegateUserId`)
scoped a single "DJ" to a room. That conflated V.2.2 with the
room-based services and had no notion of device — it did not match the
subject. It was **removed entirely** (schema, services, controllers,
routes) and replaced with the account+device model above.

A VOTE room no longer has a DJ at all: its queue advances on its own
(see `src/rooms/queue-progression.service.ts`). Playback control as a
*delegated* capability is precisely and only what V.2.2 describes.

## Operations and endpoints

```
GET    /users/me/delegations                    devices I delegated
GET    /users/me/controlled-devices             devices I can control
GET    /users/me/devices/:deviceId/delegate     current delegate
PUT    /users/me/devices/:deviceId/delegate     grant  { delegateUserId }
DELETE /users/me/devices/:deviceId/delegate     revoke

POST   /delegations/:id/playback/play           { uris?, contextUri? }
POST   /delegations/:id/playback/pause
POST   /delegations/:id/playback/next
POST   /delegations/:id/playback/previous
PUT    /delegations/:id/playback/volume         { percent: 0..100 }
```

## Soutenance defense points

- *Where is "per-device" in your impl?* — The `MusicControlDelegation`
  table is keyed `(ownerId, deviceId)` unique. Each device of the
  account has its own, independent delegation. That is the literal
  reading of *"specific for each device attached to the user's
  account"*.
- *Why account-level and not room-level?* — V.2.1 and V.2.3 name an
  explicit container (event, playlist) with visibility rules; V.2.2
  names none. We implemented V.2.2 literally — account+device, no
  added container — to avoid over-interpretation.
- *Why must the delegate be a friend?* — The subject says *"give the
  music control to different friends"*. `grant` calls
  `FriendsService.areFriends` and returns 403 otherwise.
- *Whose Spotify plays?* — Always the **owner's**. The delegate's
  commands proxy to the owner's token (`DelegationPlaybackService`).
  The delegate is a remote control.
- *What does `deviceId` target on Spotify?* — `deviceId` is our
  app-level identifier (the `X-Device` header), used to scope which
  app-device is delegated. The Spotify Web API call drives the active
  session of the owner's account. The granularity lets the owner
  revoke one device without affecting the others.
- *Is the delegation persisted across restarts?* — Yes, it is a row
  in `MusicControlDelegation`. Survives backend redeploys.

## Tests

- `src/delegation/delegation.service.spec.ts` — grant/revoke/listing
- `src/delegation/delegation-playback.service.spec.ts` — authz + owner-token routing
- `src/delegation/delegation.controller.spec.ts`,
  `delegation-playback.controller.spec.ts` — routing
- `test/e2e/delegation.e2e-spec.ts` — full grant → playback → revoke flow
