# Phase 10 — Music Control Delegation

## Scope

The third V.2 service: **delegate music control to a friend** while
keeping ownership of the room. Subject text in full (V.2.2):

> "Music control delegation.
>
> A license management must be integrated to the service. It must be
> specific for each device attached to the user's account. The user
> can choose to give the music control to different friends."

This is the shortest of the three service sections in the subject —
**three sentences** — and intentionally ambiguous on the "per-device"
phrasing. This report documents what we built and what we left out,
honestly.

## What we built

A new room kind, `DELEGATE`, with a single optional `delegateUserId`
column on the `Room` row. The owner of a DELEGATE room can grant
DJ control to any of the room's members. Granted control means: the
delegate can call the playback endpoints (`/rooms/:id/playback/{play,
pause,next,previous,volume}`) which the `PlaybackService` translates
into Spotify Web API calls.

```prisma
model Room {
  ...
  delegateUserId    String?
  delegateGrantedAt DateTime?
  ...
}
```

`DelegationService` enforces:
- Only the room owner can `grant`
- The delegate must be a room member
- The delegate must have a `SocialAccount` for Spotify (otherwise
  the playback calls will fail anyway, so we fail loudly upfront)
- `revoke` can be called by the owner or by the delegate themself
- All transitions emit realtime events (`delegate:granted`,
  `delegate:revoked`) and push notifications to the delegate
  (`PushService.sendToUser`)

## What we did **not** build, and why

The subject's "license must be specific for each device" is the
sentence we did not fully honor.

### Three valid interpretations of "per-device"

1. **Per device of the owner**: Bob is logged in on iPhone + iPad;
   on his iPhone he delegates to Alice, on his iPad to Charlie. The
   same room has two simultaneous DJs, one per device-of-the-owner.
2. **Per device of the delegate**: Alice is logged in on multiple
   devices; the delegation specifies which of *Alice's* devices
   receives the playback.
3. **Per-device bookkeeping**: each user-device pair has its own
   delegation record, but only one delegation is active at a time.

Our impl satisfies **none** of these literally — there's a single
`Room.delegateUserId`. The `X-Device` header (logged by V.6
middleware) is captured but never consumed in the delegation
business logic.

### Path to fix (Lecture A, fully per-device of the owner)

```prisma
model DelegationGrant {
  id              String   @id @default(uuid())
  roomId          String
  room            Room     @relation(fields: [roomId], references: [id], onDelete: Cascade)
  ownerId         String
  ownerDeviceId   String     // X-Device header at grant time
  delegateUserId  String
  grantedAt       DateTime @default(now())

  @@unique([roomId, ownerId, ownerDeviceId])
  @@index([delegateUserId])
}
```

`DelegationService.grant(roomId, ownerId, ownerDeviceId,
delegateUserId)`. `PlaybackService` resolves the active delegation
by `(roomId, ownerId, ownerDeviceId)` derived from the caller's
context. Estimated cost: 2–3 h of code + tests.

### Decision

**Documented as a known limitation** rather than rushed in. The
project meets V.2 with 2 / 3 services fully complete (Vote, Playlist)
and the third (Delegation) implemented with a single-delegate model.
The subject explicitly allows 2 / 3 — see V.2 first sentence: *"user
must access at least 2 functions out of the following 3 ones"*. So
we cross the bar with margin.

## Operations and endpoints

```
POST   /rooms/:id/delegate      grant DJ control (owner only)
DELETE /rooms/:id/delegate      revoke (owner or current delegate)
GET    /rooms/:id/delegate      get current DJ (members)

POST   /rooms/:id/playback/play       start/resume playback
POST   /rooms/:id/playback/pause
POST   /rooms/:id/playback/next
POST   /rooms/:id/playback/previous
PUT    /rooms/:id/playback/volume     body: { percent: 0..100 }
```

All playback endpoints route through
`DelegationService.requireDelegateOrOwner(roomId, userId)` — the
caller must be either the owner or the current delegate.

## Soutenance defense points

- *Where is "per-device" in your impl?* — Honest answer: not fully.
  The subject's sentence is ambiguous, we built the simpler
  single-delegate model, and we treat Delegation as 1 of the 3
  services with a known limitation, not as a complete implementation
  of the "per-device" license. We cross the V.2 bar with the other
  two services regardless.
- *Why did you make Spotify a hard prerequisite for the delegate?* —
  Because the playback call will fail at Spotify if the delegate
  has no token. Failing early at grant time gives a clear error to
  the owner ("Delegate has no Spotify account linked") instead of a
  generic 500 later.
- *Can the owner revoke and re-grant fast enough to cause races?* —
  Yes; `grant` overwrites `delegateUserId` atomically (single
  `Room` row update). No partial state observable.
- *What happens on `delegate:granted` to the delegate?* — Two
  side-effects: a realtime event on the room channel
  (`delegate:granted`) and a direct event to the user channel
  (`delegate:you-are-dj`), plus a push notification if a device
  token is registered. Multi-channel so the delegate finds out
  regardless of whether their app is open or not.
- *Is the delegation persisted across server restarts?* — Yes, it's
  a column on the `Room` table. Survives backend redeploys and
  Redis flushes.
