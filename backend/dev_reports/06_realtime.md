# Phase 6 — Realtime (Socket.IO + Redis adapter)

## Scope

The collaborative side of the three services (vote / playlist /
delegation) requires that every client in a room sees changes
instantly: vote scores updating, tracks moving, the DJ being
delegated. This phase covers the realtime fan-out layer.

## Choice: Socket.IO over raw WebSocket

| Criterion             | Socket.IO                                   | Raw `ws`                       |
|-----------------------|----------------------------------------------|--------------------------------|
| Rooms abstraction     | Native (`socket.join('room:42')`)            | Manual (track set per server)   |
| Reconnection          | Auto with backoff + state recovery           | Manual reconnect logic         |
| Multi-instance fan-out| Adapter pattern (`@socket.io/redis-adapter`) | Manual Redis Pub/Sub bridge    |
| Fallback transport    | HTTP long-polling fallback                   | None (WS only)                 |
| Mobile client support | First-party JS, FlutterSocketIO available    | Bare WS works but no rooms     |

We picked Socket.IO for the **rooms** primitive and the **adapter**
pattern, both of which we use heavily.

## Architecture

```
┌─────────────┐         ┌─────────────┐
│  Client 1   │         │  Client 2   │
│ (Flutter)   │         │ (Flutter)   │
└──────┬──────┘         └──────┬──────┘
       │  WS                   │  WS
       │                       │
       ▼                       ▼
┌──────────────────┐    ┌──────────────────┐
│  Backend node A  │    │  Backend node B  │
│   (Nest+Fastify) │    │   (Nest+Fastify) │
└────────┬─────────┘    └────────┬─────────┘
         │                       │
         │   pub/sub via         │
         └──────────►┌───────────┐◄──────────┘
                    │   Redis   │
                    │  Pub/Sub  │
                    └───────────┘
```

`@socket.io/redis-adapter` wires every backend replica to Redis
Pub/Sub. When `RealtimeService.emitToRoom('room:42', 'vote', payload)`
fires:
1. Socket.IO publishes to the Redis channel for `room:42`
2. **Every** backend replica subscribes to that channel
3. Each replica delivers the event to its locally-connected clients
   that are members of `room:42`

So horizontal scaling is trivial — N replicas behind a load
balancer all share the same realtime view. No sticky sessions
required.

## Code structure

- **`src/realtime/redis-io.adapter.ts`** — Custom `IoAdapter`
  subclass that wires the Redis adapter in `connectToRedis()`. Called
  once in `main.ts` before `app.listen()`.
- **`src/realtime/realtime.gateway.ts`** — The Socket.IO gateway
  (`@WebSocketGateway`) with handlers for client → server events
  (`subscribe:room`, `unsubscribe:room`) and authentication on
  connect.
- **`src/realtime/realtime.service.ts`** — Server → client emission
  helpers (`emitToRoom`, `emitToUser`). Injected as an `@Optional()`
  dependency wherever events need to be sent (rooms, tracks,
  playlist, delegation, push-notifications).

The `@Optional()` injection is important: services that emit events
remain testable in isolation — the unit specs construct them
without a realtime adapter and still verify the business logic.

## Authentication on the WebSocket

The Socket.IO handshake carries an `auth.token` field (or
`Authorization: Bearer …` header in the upgrade request). The
gateway's `handleConnection` verifies the JWT using the same
`JwtService` as the HTTP path, attaches the `JwtPayload` to
`socket.data.user`, and rejects the connection on invalid tokens.

So a malicious client cannot subscribe to a room they don't belong
to without a valid token, just as they can't hit the REST routes.

## Event vocabulary (subset)

```
emit to room        event name              payload
────────────────    ────────────────────    ────────────────────────
room:<id>           "member:joined"         { roomId, userId, role }
room:<id>           "member:left"           { roomId, userId }
room:<id>           "track:added"           { trackId, addedById }
room:<id>           "track:voted"           { trackId, userId, value, score }
room:<id>           "track:removed"         { trackId }
room:<id>           "playlist:item-added"   Track
room:<id>           "playlist:item-moved"   { trackId, position }
room:<id>           "delegate:granted"      { roomId, delegateUserId, grantedById }
room:<id>           "delegate:revoked"      { roomId, previousDelegateId, revokedById }
user:<id>           "delegate:you-are-dj"   { roomId }
```

Naming convention: `<entity>:<verb>` past tense, payload always an
object (never a primitive) so we can add fields without breaking
clients.

## Soutenance defense points

- *Why Socket.IO over native WebSocket on a Fastify project?* —
  Rooms abstraction is the killer feature. Hand-rolling per-room
  subscription tracking for every backend replica is enough code
  to be a project of its own. Socket.IO solves it in 5 lines.
- *What if Redis goes down?* — Each backend still serves clients
  locally, just without cross-replica fan-out. Functional but
  degraded. Recovery is automatic when Redis returns.
- *Can a client subscribe to a room they don't belong to?* — No.
  The gateway's `subscribe:room` handler calls
  `RoomMembershipService.assertVisible(roomId, userId)` before
  joining the Socket.IO room.
- *Does the realtime layer have any persistence?* — None by design.
  Events are fire-and-forget; the source of truth is Postgres. A
  client reconnecting after a disconnect rehydrates by re-querying
  the REST API.
- *How do you scale beyond 2-3 backend replicas?* — Redis Pub/Sub
  is the bottleneck. Single-channel publish is O(N subscribers)
  in Redis CPU. At 10+ replicas you'd want to shard rooms across
  channels — out of scope for this project but mentioned as the
  natural next step.
