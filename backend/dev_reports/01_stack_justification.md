# Phase 1 — Tech stack justification

## Scope

Justify every load-bearing dependency in `package.json`. The subject
(IV.1 and V.4) explicitly demands that **decisions be justified** —
this report is the written record of those justifications, item by
item.

## The stack

| Layer            | Choice                              | Version |
|------------------|-------------------------------------|---------|
| Runtime          | Node.js                             | 24 LTS  |
| Language         | TypeScript                          | 6.0     |
| HTTP framework   | NestJS                              | 11      |
| HTTP server      | Fastify (via `@nestjs/platform-fastify`) | latest |
| ORM              | Prisma + `@prisma/adapter-pg`       | 7       |
| Database         | PostgreSQL                          | 18      |
| Cache / Pub/Sub  | Redis (via `ioredis`)               | 7       |
| WebSocket        | Socket.IO + `@socket.io/redis-adapter` | latest |
| Auth             | Passport (`local`, `jwt`) + `@nestjs/jwt` | latest |
| Validation       | `class-validator` + `class-transformer` | latest |
| Env validation   | `joi`                               | 18      |
| Test runner      | Vitest + `@vitest/coverage-v8`      | 4       |
| Logging          | `nestjs-pino`                       | latest  |
| Security         | `@fastify/helmet` + `@nestjs/throttler` | latest |
| Mail             | `nodemailer` + Mailpit (dev)        | latest  |

## Decision matrix

### NestJS vs raw Express/Fastify

| Criterion           | NestJS                              | Plain Fastify/Express        |
|---------------------|-------------------------------------|------------------------------|
| Modular structure   | Built-in `@Module` boundaries       | Ad-hoc folder convention     |
| Dependency injection| First-class, testable               | Manual wiring                |
| Decorator-driven    | `@Controller`, `@Body`, etc.        | Manual route registration    |
| Ecosystem fit       | `@nestjs/swagger`, `@nestjs/passport`, `@nestjs/throttler` all integrated | Each library glued by hand |

**Picked NestJS.** It gives us testability and structure for free,
which matters in a multi-service project (auth + rooms + realtime +
notifications). The cost is one extra abstraction layer, but the
features (DI, decorators, native testing module) repay that on every
single feature we add.

### Fastify adapter vs default Express

NestJS supports both. We picked **Fastify** because:
- It's measurably faster on small JSON payloads (matters for V.7 load
  testing — the closer we are to "thousands" of concurrent users on a
  low-end server, the better)
- Fastify's request/response model is closer to Node's native streams
  and avoids one layer of Express middleware overhead
- The cost: `@fastify/helmet` and `@fastify/static` are required
  (vs `helmet`/`express-static`) — minor friction, documented in
  `05_hardening.md`

### Prisma vs TypeORM vs raw SQL

| Criterion              | Prisma                                  | TypeORM                  | Raw `pg`         |
|------------------------|------------------------------------------|---------------------------|------------------|
| Schema as source       | Single `schema.prisma` file              | Decorators on entity classes | Manual SQL    |
| Type safety            | Generated TS client, fully typed         | Decorators + reflection   | None (or hand-rolled types) |
| Migrations             | `prisma migrate dev/deploy` versioned    | Decorators-driven, fragile| Hand-rolled SQL |
| Transactions           | `$transaction([...])` interactive or array | manual `QueryRunner`    | manual `BEGIN`   |
| Developer experience   | Best-in-class autocomplete on results    | Verbose, decorator-heavy  | Maximum flexibility, minimum safety |

**Picked Prisma.** The schema-as-source approach scales for a team
project, and the generated TS types catch entire classes of bugs at
compile time (e.g. typo in a column name, wrong type on a `where`
clause). Migrations are explicit files in git, which is what the V.8
audit trail favors.

In **Prisma 7** specifically, we use `@prisma/adapter-pg` so the
runtime client uses the native `pg` driver — required since v7
removed the `url` field from `schema.prisma` and now expects an
adapter on `PrismaClient`.

### PostgreSQL vs MongoDB

The subject (V.2.1) **explicitly** flags vote race conditions:
> "You should especially care about the management of competition
> problematics: for instance, if several people vote for different
> tracks or the same one in a playlist."

We need an ACID-transactional store. Postgres gives us
`Serializable` isolation and atomic `UPDATE ... RETURNING` for the
score-increment path. MongoDB's per-document atomicity is good but
multi-document transactions are slower and have more surprising
semantics. The choice is Postgres.

### Redis use cases

Three independent use cases, all justifying the Redis dependency:
1. **JWT blacklist** — sub-millisecond `EXISTS` on each authenticated
   request; TTL aligned with token expiry so the blacklist self-cleans.
2. **Socket.IO Pub/Sub adapter** — enables horizontal scaling: 2+
   backend replicas can broadcast a room event and every connected
   client receives it once, no matter which replica they're on.
3. **Rate limiting backing store** (via Redis support in
   `@nestjs/throttler` if needed for multi-instance — currently the
   in-memory store is sufficient).

### Vitest vs Jest

| Criterion      | Vitest                                                 | Jest                       |
|----------------|---------------------------------------------------------|----------------------------|
| Cold start     | Fast (uses Vite/esbuild/oxc transform pipeline)         | Slower (`ts-jest` / `babel-jest`) |
| ESM support    | Native                                                 | Mature but configuration heavy |
| API parity     | `describe / it / expect` identical to Jest             | Reference                  |
| Nest integration | Full (`@nestjs/testing` works as-is)                  | Full                       |

**Picked Vitest** for the iteration speed. 342 unit tests run in ~3 s,
which keeps the feedback loop tight enough to TDD.

### JWT vs server-side sessions

| Criterion          | JWT (current choice)                               | Session cookies                 |
|--------------------|-----------------------------------------------------|---------------------------------|
| State on backend   | None (stateless)                                    | Session store needed            |
| Mobile client fit  | Native — token in `Authorization: Bearer …` header  | Cookies on mobile are awkward   |
| Revocation         | Needs explicit blacklist                            | Native (delete from store)      |
| Horizontal scale   | Trivial — no shared session store                   | Requires sticky sessions or Redis |

**Picked JWT** because the V.5 mobile client is the primary
consumer; bearer tokens map cleanly to Flutter `dio` interceptors.
The revocation gap is filled by the Redis blacklist (see Phase 2).

## Soutenance defense points

- *Why Fastify if NestJS defaults to Express?* — Better p99 latency
  on small JSON payloads, which is the dominant shape of our API
  (auth tokens, vote events, playlist moves). Confirmed informally
  in `loadtest/`.
- *Why Prisma instead of TypeORM, given Nest's affinity with
  TypeORM?* — Schema-as-source-of-truth, better type inference on
  query results, explicit versioned migrations. The cost (slightly
  unusual `prisma.config.ts` setup in v7) is one-off.
- *Why upgrade to Prisma 7 mid-project?* — Prisma 6 had `package.json`
  config and embedded query engine warnings flagged as
  "deprecated, removed in v7". Better to migrate while the surface
  was small (only `prisma.service.ts` and `prisma/seed.ts` import
  `PrismaClient`) than after.
- *Why JWT + Redis blacklist instead of pure sessions?* — Stateless
  scales without sticky sessions, fits the mobile bearer-token model,
  and the Redis blacklist gives us revocation on demand (logout,
  password change) without sacrificing the architecture.
- *Why both `class-validator` (DTOs) and `joi` (env)?* — Different
  domains: DTOs validate per-request payloads using decorators
  collocated with the type definition; env validation happens once at
  boot and benefits from Joi's terse schema for simple K/V config.
