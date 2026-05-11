# Phase 5 — Security hardening

## Scope

Cover **V.6 Securing** of the subject. The requirements call out:
- Authenticated user must access only their data, not others'
- Plan for malicious behaviors: bruteforce, session theft
- Identify other hazards and explain protections
- **Mandatory log of `X-Platform`, `X-Device`, `X-App-Version` on
  every action**

Each is implemented by a specific Nest building block.

## Layered controls

```
┌──── Request ────────────────────────────────────────────────────┐
│                                                                 │
│  Fastify + @fastify/helmet                                      │  ← HTTP headers, CSP
│      │                                                          │
│  RequestLoggerMiddleware                                        │  ← X-Platform / X-Device / X-App-Version
│      │                                                          │
│  ThrottlerGuard (APP_GUARD)                                     │  ← default 100/min, auth 10/min
│      │                                                          │
│  JwtAuthGuard (APP_GUARD) + @Public() opt-out                   │  ← every route requires JWT unless explicit
│      │                                                          │
│  ValidationPipe (global, whitelist + forbidNonWhitelisted)      │  ← class-validator on DTOs
│      │                                                          │
│  Controller handler                                             │
│      │                                                          │
│  HttpExceptionFilter                                            │  ← homogeneous error shape, no leak
│      │                                                          │
└──── Response (logged with status / duration) ───────────────────┘
```

## Controls, mapped to subject hazards

### Bruteforce (subject V.6 explicitly named)

`@nestjs/throttler` with **two tiers** (`app.module.ts`):

```typescript
ThrottlerModule.forRootAsync({
  useFactory: () => [
    { name: 'default', ttl: 60_000, limit: 100 },  // 100 req/min/IP
    { name: 'auth',    ttl: 60_000, limit: 10  },  // 10 req/min/IP
  ],
});
```

The `AuthController` opts in to the stricter `auth` tier with
`@SkipThrottle({ default: true }) @Throttle({ auth: {} })`. So
register / login / refresh / forgot-password are capped at 10/min/IP
**before** they reach the bcrypt verify path — keeping the CPU
bounded under attack.

### Session theft (subject V.6 explicitly named)

Three layers:
1. **Refresh rotation** — every refresh issues a new token and
   revokes the old; replay of a stolen token is detectable
   (the rightful owner gets a 401 next time, signal to revoke all
   sessions).
2. **JWT blacklist (Redis)** — immediate revocation on logout or
   password change. The strategy queries the blacklist on every
   request.
3. **`GET /auth/sessions` + `DELETE /auth/sessions/:id`** —
   end-user visibility on active sessions and ability to revoke
   any of them remotely.

### Auth-user → data isolation (subject V.6)

`JwtAuthGuard` is registered globally as `APP_GUARD`. Every route is
authenticated by default; explicit `@Public()` opt-out is required
to expose anonymous routes (currently: `/health`, `/auth/register`,
`/auth/login`, `/auth/forgot-password`, `/auth/reset-password`,
`/auth/verify-email`, `/auth/social`).

Services use `user.sub` (from the JWT) as the identity for any
authorization check — a user querying `/rooms/:id/playlist` can
only see the playlist if they own / admin / member the room
(`PlaylistService.requireEditor` / `requireMember`).

### CSP / clickjacking / XSS at the HTTP layer

`@fastify/helmet` with a tightened CSP (`main.ts`):

```typescript
await app.register(helmet, {
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc:  ["'self'", "'unsafe-inline'"],
      styleSrc:   ["'self'", "'unsafe-inline'"],
      imgSrc:     ["'self'", 'data:', 'https:'],
      connectSrc: ["'self'"],
    },
  },
  crossOriginEmbedderPolicy: false,
});
```

Headers added:
- `Strict-Transport-Security: max-age=31536000; includeSubDomains`
- `X-Frame-Options: SAMEORIGIN`
- `X-Content-Type-Options: nosniff`
- `Referrer-Policy: no-referrer`
- `Origin-Agent-Cluster: ?1`

### DTO validation

`ValidationPipe` global with `whitelist: true, forbidNonWhitelisted:
true, transform: true`. Every payload is stripped to declared fields
and rejected if it contains anything else. This kills entire classes
of mass-assignment bugs (e.g., `PATCH /users/me` with
`{ emailVerified: true }` — the field would be stripped).

### Log secrets redaction

`nestjs-pino` is configured to redact known sensitive fields from
both request and response logs (`app.module.ts`):

```typescript
redact: {
  paths: [
    'req.headers.authorization',
    'req.headers.cookie',
    'req.headers["x-refresh-token"]',
    'req.body.password',
    'req.body.newPassword',
    'req.body.currentPassword',
    'req.body.refreshToken',
    'req.body.accessToken',
    'req.body.token',
    'res.headers["set-cookie"]',
  ],
  censor: '[REDACTED]',
}
```

So even if logs leak (devops misconfig, log aggregator breach),
tokens and passwords don't.

### Env validation at boot

`src/config/env.validation.ts` uses Joi to enforce a schema for
`DATABASE_URL`, `JWT_SECRET` (>= 32 chars), `JWT_REFRESH_SECRET`,
`REDIS_HOST/PORT`, throttler caps, etc. With `validationOptions:
{ abortEarly: true }`, the app **refuses to boot** if any required
env is missing or malformed. Fail fast, don't pretend.

### Mandatory request logging (V.6 explicit)

`RequestLoggerMiddleware` is applied to **all routes**:
```typescript
consumer.apply(RequestLoggerMiddleware).forRoutes('*');
```

It reads `X-Platform`, `X-Device`, `X-App-Version` from headers, logs
on `res.on('finish')` with method, URL, status, duration, and
attaches the raw `RequestLogData` to `res.__logData` for potential
async persistence to a downstream log store (Loki, BigQuery, etc.).

This implementation is exactly what the V.6 paragraph asks for:
> "Any action on the mobile application must generate logs on the
> back-end.
> - Platform (Android, iOS, etc.),
> - Device (iPhone 6G, iPad Air, Samsung Edge, etc.),
> - Application Version."

## Soutenance defense points

- *Why a two-tier throttler instead of one?* — One tier risks
  picking the wrong tradeoff: too lenient and bruteforce works; too
  strict and legitimate users hit 429 on `/rooms` lists. Splitting
  `auth` (very strict, low traffic) from `default` (lenient, high
  traffic) hits the sweet spot.
- *Why a JWT blacklist in Redis and not in Postgres?* — Every
  authenticated request reads the blacklist. Postgres roundtrip
  adds ~5 ms, Redis ~0.5 ms. At 100 req/s that's 9.5 minutes of
  saved CPU per day. Redis is also TTL-aware, no cron needed.
- *Why redact secrets from logs instead of just not logging the
  body?* — We need request bodies for debugging (the structured
  log of a failed request is gold). The redaction lets us log
  everything else while keeping the small list of fields safe.
- *What if `JWT_SECRET` is too short and someone deploys
  anyway?* — Joi schema in `env.validation.ts` mandates
  `min(32)`. The app refuses to start; the deploy fails noisily
  rather than running with a weak secret.
- *What other hazards have you identified beyond bruteforce and
  session theft?* — SQL injection (Prisma's parameterized queries
  + no raw SQL except `$queryRaw\`SELECT 1\`` in health), XSS
  (CSP), CSRF (mobile-only via Bearer tokens, no cookies), open
  redirect (no redirect endpoint exists), mass assignment
  (`whitelist: true` on ValidationPipe), TLS downgrade (HSTS
  header).
