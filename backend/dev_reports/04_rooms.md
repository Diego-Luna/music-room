# Phase 3 — Rooms & Memberships

Phase 3 introduces the **Room** domain: the container for every music-centric
feature that follows (vote, playlist, delegate). This phase ships the CRUD, the
visibility/access rules, and the full membership lifecycle (join, leave,
invite, role change, kick). No music logic yet — Phase 5+ will plug tracks,
votes and delegation onto the `Room` model defined here.

## 1. Scope

| Sujet                                                               | Where                                       |
|---------------------------------------------------------------------|---------------------------------------------|
| V.7 create a room of one of 3 kinds                                 | `POST /rooms` with `kind ∈ {VOTE,PLAYLIST,DELEGATE}` |
| V.7 public vs private visibility                                    | `visibility ∈ {PUBLIC, PRIVATE}` on `Room`  |
| V.7 invite users to a private room                                  | `POST /rooms/:id/invitations`               |
| V.7 list / inspect / update / delete a room                         | `GET /rooms`, `GET/PATCH/DELETE /rooms/:id` |
| V.7 owner/admin roles, member management                            | `RoomMember.role`, `/rooms/:id/members/*`   |
| Vote-window + geo-gating metadata (for Phase 6 enforcement)         | `voteWindow`, `voteStartsAt/EndsAt`, `voteLocation*` |

## 2. Domain model (`prisma/schema.prisma`)

Six new enums and three new tables; migration
`20260418140624_phase3_rooms`:

- `RoomKind` — `VOTE`, `PLAYLIST`, `DELEGATE`. Immutable once set: a
  playlist-editor room cannot become a vote room mid-flight (the subject
  treats them as separate features). Enforced in `UpdateRoomDto =
  PartialType(OmitType(CreateRoomDto, ['kind']))`.
- `RoomVisibility` — `PUBLIC` / `PRIVATE`. A **separate enum** from
  `User.visibility` (`PUBLIC` / `FRIENDS_ONLY` / `PRIVATE`) because the rules
  are different: room privacy uses membership; user privacy uses friendship
  (Phase 2 report, §2). Sharing one enum would force a "friends-only room"
  concept the subject doesn't ask for.
- `LicenseTier` — `FREE` / `PREMIUM`. Placeholder for the Spotify-SDK gate
  planned in Phase 8.
- `VoteWindow` — `ALWAYS` / `SCHEDULED`. When `SCHEDULED`, `voteStartsAt` and
  `voteEndsAt` are both required and validated in the service.
- `MemberRole` — `OWNER`, `ADMIN`, `MEMBER`. One row per (room, user),
  `@@unique([roomId, userId])` so membership is a set, not a multiset.
- `InvitationStatus` — `PENDING`, `ACCEPTED`, `DECLINED`, `REVOKED`,
  `EXPIRED`. `@@unique([roomId, inviteeId, status])` lets us hold at most one
  *pending* invite per (room, invitee) while preserving history.

The `voteLocation*` columns (lat, lng, radius) are nullable and validated as a
group (§4) so Phase 6's geo-gated vote room can query them with one index
lookup.

## 3. `RoomsService` — CRUD with visibility

- **`create(userId, dto)`** wraps room creation and the `OWNER` membership
  insert in a single `$transaction`: if the member row fails, the room row
  is rolled back and we never end up with an orphan room. The service
  validates vote-window + geo settings before touching the DB.
- **`findOne(roomId, userId)`** returns 404 (not 403) for a PRIVATE room the
  caller isn't a member of. Rationale: returning 403 would leak the existence
  of the room. The room list on `GET /rooms` already filters private rooms out
  for non-members, so a dedicated `findOne` with 404 is the consistent story.
- **`list(userId)`** uses a Prisma `OR`: `visibility = PUBLIC` or
  `ownerId = userId` or `members.some(userId = caller)`. One query, no N+1.
- **`update(roomId, userId, dto)`** goes through `requireEditableRoom`:
  owner always can; admins can when `allowMembersEdit` isn't set to reject
  them (the rule is "owner or admin"). Re-validates vote-window + geo on
  every write.
- **`remove(roomId, userId)`** is owner-only. `onDelete: Cascade` on the
  RoomMember/Invitation relations means we don't have to clean children
  manually.

## 4. Invariants enforced at the service layer

- `validateVoteSettings`: `SCHEDULED` ⇒ both `voteStartsAt` and `voteEndsAt`
  set, and `voteEndsAt > voteStartsAt`. `ALWAYS` ⇒ both null.
- `validateLocationSettings`: the triplet (lat, lng, radius) is all-or-none.
  0-of-3 or 3-of-3; any partial set is a 400. The radius has a lower bound of
  10 m (club-sized; below that a GPS fix is noise).
- `kind` immutable (see §2).
- Owner cannot leave — `leave()` returns 400 with "transfer ownership or
  delete the room" because the `Room.ownerId` column is non-nullable by
  design (a room without owner would have no one authorised to change its
  settings or kick bad actors).
- Owner cannot be kicked or have their role changed (400 on both paths).
  Role changes are owner-only; kicks are owner/admin.

## 5. `RoomMembershipService` — join / leave / invite / role / kick

Split from `RoomsService` because its surface is large enough to deserve its
own controller (`RoomMembershipController` mounted under
`/rooms/:id/{members,invitations,join,leave}`) and its own test file.

- **`join(roomId, userId)`**
  - PUBLIC room ⇒ direct `MEMBER` insert.
  - PRIVATE room ⇒ must have a `PENDING` invitation with
    `expiresAt > now()`. On success, the invitation transitions to
    `ACCEPTED` and the `RoomMember` row is created. Both writes happen in
    the same service call; a failure of the second raises and the first is
    re-run on retry (the `@@unique([roomId, inviteeId, status])` will
    prevent a duplicate PENDING).
- **`invite(roomId, inviterId, dto)`**
  - Owner/admin gate via `requireAdmin(roomId, room, userId)`. The
    `roomId` parameter is passed explicitly — an earlier version inferred
    it from `room.id`, which broke under the Prisma `select` shape.
  - Checks that the invitee exists as a `User` and isn't already a member.
  - Creates a `PENDING` invitation with `expiresAt = now + 7d` (the
    `INVITE_TTL_MS` constant). The TTL is cheaper than a background job
    that sweeps invitations: the `PENDING + expiresAt > now` check already
    hides expired rows, and a one-liner cron can hard-delete expired rows
    later if the table grows.
- **`updateRole` / `removeMember`** — owner-only role changes, owner/admin
  kicks. Both refuse to target the owner.

## 6. Access pattern — 404 over 403 for PRIVATE rooms

Throughout the module, the policy is "don't leak room existence to outsiders":

| Caller                         | Behaviour                            |
|--------------------------------|--------------------------------------|
| Not a member of a PRIVATE room | 404 on `GET /rooms/:id` and `/members` |
| Not owner/admin on a PATCH     | 403 (the caller already knows the room exists — usually they're a regular member) |
| Not owner on a DELETE          | 403 (same)                           |

This gives us a single, predictable rule for the client: "403 means you see
it but can't do that; 404 means the room might not even exist to you."

## 7. Tests

- `rooms.service.spec.ts` — 15 tests: create happy path + the three validator
  paths (vote window, geo triplet, kind enum), findOne (public / private
  member / private non-member 404 / missing 404), list (OR clause correctness),
  update (owner / admin / member 403 / stranger 404), remove (owner / admin
  403).
- `membership.service.spec.ts` — 16 tests covering every branch of join,
  leave, invite, updateRole, removeMember, listMembers, including the
  private-invite acceptance side-effect (`status: ACCEPTED`,
  `respondedAt: Date`).
- `rooms.controller.spec.ts` — 5 wiring tests (service is a `vi.fn()` mock).
- `test/e2e/auth.e2e-spec.ts > Rooms` — 7 end-to-end tests against the full
  Nest stack with an in-memory Prisma mock. The e2e mock uses `randomUUID()`
  so `@IsUUID()` DTOs accept the generated ids.

Total after Phase 3: **168 unit + 30 e2e = 198 tests** green.

## 8. Soutenance defense points

- *Why a separate visibility enum for rooms?* Different access rules (membership
  vs friendship). Fusing them into one enum would add a "friends-only room"
  concept the subject doesn't ask for.
- *Why 404 instead of 403 for private rooms?* Don't leak room existence to
  outsiders. The client has one rule: `404 = invisible to you`.
- *Why store invitation expiry rather than delete on expire?* The table is
  small, a cron can prune, and the `PENDING + expiresAt > now` check already
  hides expired rows — no background worker required today.
- *Why can't the owner leave?* `Room.ownerId` is non-nullable and every
  ACL path keys off it; allowing a null owner would require either
  "ownerless" rooms (who changes settings?) or forcing an election (off
  scope). The API exposes DELETE and a future `POST /rooms/:id/transfer`
  instead.
- *Why is `kind` immutable?* Vote, playlist and delegate rooms have
  disjoint state (tracks table vs delegation table vs vote table, Phase 5+).
  A kind change would require wiping children; the subject never asks for
  this. Cheaper to force a new room.
- *Why split `RoomMembershipService` from `RoomsService`?* Six endpoints
  deserve their own controller, the join/invite flow crosses two tables,
  and the cyclomatic complexity of `RoomsService` would double if we
  merged them. Splitting keeps both under 200 lines each.
