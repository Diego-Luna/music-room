# Phase 3 — Users, profile, friends, sessions

## Scope

Cover the **non-auth** half of V.1: profile data (public / friends-only
/ private / music preferences), friendship as the enabler of
`FRIENDS_ONLY` visibility, and session management as the operational
counterpart of the auth layer.

## Profile model

```prisma
model User {
  id               String     @id @default(uuid())
  email            String     @unique
  passwordHash     String?           // null for social-only accounts
  displayName      String
  avatarUrl        String?
  emailVerified    Boolean    @default(false)
  visibility       Visibility @default(PUBLIC)  // PUBLIC / FRIENDS_ONLY / PRIVATE
  musicPreferences String[]   @default([])
  createdAt        DateTime   @default(now())
  updatedAt        DateTime   @updatedAt
  ...
}
```

Three visibility tiers, mirroring the subject's
"public / friends-only / private" wording.

### Subject reading: per-field visibility vs per-profile visibility

The subject literally says:
> "In their profile, the user must be able to state and update:
> - their public informations,
> - informations only available to their friends,
> - their private informations,
> - their music preferences."

There are two valid readings:
1. **Per-field visibility**: every piece of info carries its own
   tag (e.g. phone is private, address is friends-only).
2. **Per-profile visibility**: the user picks one of three tiers
   that gates their **whole** profile.

We chose **(2)** for simplicity. Defendable because:
- It strictly satisfies the user "states and updates" their
  visibility level.
- Adding more fields later doesn't require schema migration — only
  the visibility tier needs to be honored on read.

## Friendship

Added in the latest pass to make `FRIENDS_ONLY` enforceable.

```prisma
enum FriendshipStatus { PENDING, ACCEPTED, DECLINED, CANCELED }

model Friendship {
  id          String           @id @default(uuid())
  requesterId String
  addresseeId String
  status      FriendshipStatus @default(PENDING)
  createdAt   DateTime         @default(now())
  respondedAt DateTime?

  @@unique([requesterId, addresseeId])
  @@index([addresseeId, status])
  @@index([requesterId, status])
}
```

State machine:
```
                      ┌────────────┐
                      │  (no row)  │
                      └──────┬─────┘
                  request()  │
                             ▼
                      ┌────────────┐  decline()  ┌────────────┐
                      │  PENDING   │────────────▶│  DECLINED  │
                      └──────┬─────┘             └────────────┘
              cancel()  │    │  accept()
              (requester only)│
                             ▼
                      ┌────────────┐
                      │  ACCEPTED  │
                      └──────┬─────┘
                             │  cancel() = unfriend (DELETE row)
                             ▼
                      ┌────────────┐
                      │  (no row)  │
                      └────────────┘
```

`DECLINED` and `CANCELED` rows can be **reopened** as a fresh
`PENDING` if the same requester sends another invite — protects
against the spam pattern of "send invite, withdraw, send again,
withdraw" creating thousands of rows.

`areFriends(a, b)` is the canonical check used by
`UsersService.findOnePublic` to gate the `FRIENDS_ONLY` view.

## Public profile endpoint

```
GET /users/me        → full self profile (email, emailVerified, …)
PATCH /users/me      → update self
GET /users/:id       → public profile of another user, gated by visibility
```

`findOnePublic(callerId, targetId)` is the gateway:
- **self** → full self profile via the existing `findOne` path
- **target visibility = PUBLIC** → return the public-safe view
- **target visibility = FRIENDS_ONLY** → check `areFriends`; if not
  a friend, `NotFoundException` (not `403` — see defense point below)
- **target visibility = PRIVATE** → `NotFoundException` regardless

The public-safe view strips `email`, `emailVerified`, `createdAt`,
`updatedAt` (PII / internal bookkeeping).

## Session listing & revocation

```
GET    /auth/sessions       → list active RefreshToken rows for the caller
DELETE /auth/sessions/:id   → revoke one
POST   /auth/logout         → revoke current access + refresh
```

Each `RefreshToken` row tracks `deviceId`, `userAgent`, `ip`,
`createdAt`, `expiresAt`, `revokedAt`, `replacedBy`. So the user
can see their active sessions ("Alice's iPhone, signed in from Paris
2 days ago") and revoke any. Useful for session-theft mitigation
mentioned in V.6.

## Soutenance defense points

- *Why a single `visibility` field instead of one per attribute?* —
  Pragmatic. The subject's "public / friends-only / private /
  music preferences" list is short, the gain from per-field tags
  is marginal, the schema cost is significant. Defendable as a
  conscious choice. We keep `musicPreferences` as a separate
  field on the public-safe view because the subject treats it as
  its own bullet — preferences are always visible to anyone who
  can see the profile at all.
- *Why use `NotFoundException` (404) and not `ForbiddenException`
  (403) for hidden profiles?* — Returning 404 prevents an attacker
  from enumerating which user IDs exist with a hidden profile. The
  industry term is "404 over 403 for opaque visibility". Standard
  on GitHub, Twitter, etc.
- *Why allow re-opening a `DECLINED` friendship as `PENDING`?* —
  Real relationships change; locking the pair forever after a
  decline is unfriendly UX and not required by the subject.
  Re-opening reuses the same row (controlled by `@@unique`) instead
  of accumulating audit trash.
- *How is a stolen session detected and revoked?* — Refresh
  rotation (Phase 2) catches double-use of a refresh token. Combined
  with the `GET /auth/sessions` endpoint, the user can see "I'm
  signed in from a device I don't recognize" and DELETE the row.
- *What about IoT / V.6 hazards in this layer?* — DELETE
  on `/auth/sessions/:id` is throttled by the default tier
  (`100 req/min`). Bruteforcing session IDs is bounded.
