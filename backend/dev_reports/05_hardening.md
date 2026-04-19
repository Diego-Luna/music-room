# Phase 4 — Hardening

Phase 4 is a no-new-feature pass: tighten headers, redact what the logger
emits, lock down the auth bucket, make sure the defaults we inherit from
Nest + Fastify don't betray us. The goal is a surface that's defensible at
soutenance — every header, every log line, every 429.

## 1. Scope

| Concern                                   | Where                                                   |
|-------------------------------------------|---------------------------------------------------------|
| HTTP security headers                     | `@fastify/helmet` registered in `main.ts`               |
| Structured logging with request id + redaction | `nestjs-pino` `LoggerModule.forRootAsync` in `AppModule` |
| Brute-force protection on auth routes     | `ThrottlerModule` `'auth'` bucket + `@Throttle({ auth: {} })` |
| Stack traces hidden in prod               | Nest's `HttpExceptionFilter` + Pino level gating        |

## 2. Helmet — the headers we chose

`main.ts` registers `@fastify/helmet` with an explicit CSP rather than
Helmet's default (`default-src 'self'`) because Swagger UI at `/api/docs`
pulls inline styles. The policy:

- `default-src 'self'` — no cross-origin JS/CSS/fonts unless whitelisted
- `script-src 'self' 'unsafe-inline'` — Swagger needs inline scripts. In a
  future pass we can add a nonce or move to `'strict-dynamic'`, but
  `'unsafe-inline'` is the Swagger-UI default and we accept it until we
  serve the UI under a separate origin.
- `style-src 'self' 'unsafe-inline'` — Swagger, same reason
- `img-src 'self' data: https:` — Swagger's favicon + future avatar URLs
- `connect-src 'self'` — the SPA talks to this API only

`crossOriginEmbedderPolicy: false` — leaving COEP off because the frontend
is a React Native app and a browser-only COEP/COOP split would break the
web dashboard.

The other headers come from Helmet defaults and are tested in
`test/e2e/hardening.e2e-spec.ts`:

| Header                           | Value                          |
|----------------------------------|--------------------------------|
| `X-Content-Type-Options`         | `nosniff`                      |
| `X-Frame-Options`                | `SAMEORIGIN`                   |
| `Strict-Transport-Security`      | `max-age=15552000; includeSubDomains` |
| `Referrer-Policy`                | `no-referrer`                  |
| `X-DNS-Prefetch-Control`         | `off`                          |
| `X-Powered-By`                   | *removed*                      |

## 3. Structured logging with nestjs-pino

`LoggerModule.forRootAsync` in `AppModule` wires Pino as the default Nest
logger via `app.useLogger(app.get(Logger))` in `main.ts`. Three things we
care about:

1. **Request id correlation** — pino-http auto-generates a `req.id` for
   every request and every log line from a handler inherits it. That gives
   a single grep to follow a request through the stack.
2. **Redaction at the transport boundary** — the `redact` config strips
   `Authorization`, `Cookie`, `x-refresh-token`, `password`,
   `newPassword`, `currentPassword`, `refreshToken`, `accessToken`,
   `token`, and `set-cookie` before they reach stdout. A stray
   `logger.debug(req.body)` would have leaked a password in plaintext —
   now it prints `[REDACTED]`.
3. **Level gating** — `LOG_LEVEL` env var (validated as a Joi enum in
   `env.validation.ts`) overrides the default. Default is `debug` in dev,
   `info` in prod. Pretty printing only in dev.

The pre-existing `RequestLoggerMiddleware` still runs for the
`"HTTP method path status dur"` summary line with device headers — the
two systems coexist because the middleware line is cheap to grep and the
Pino request log is the one with the body/header context.

## 4. Rate limiting — the `auth` bucket

`ThrottlerModule.forRootAsync` defines two named buckets in `AppModule`:

| Name      | TTL (ms) | Limit | Applied to              |
|-----------|----------|-------|-------------------------|
| `default` | 60000    | 100   | All routes              |
| `auth`    | 60000    | 10    | `/auth/*`               |

`AuthController` declares `@SkipThrottle({ default: true })` at the class
level so the generic bucket doesn't count, then `@Throttle({ auth: {} })`
switches to the tighter one. That means a spike on `/users/me` doesn't
starve logins, and brute-forcing `/auth/login` can't hide in the
100-requests-per-minute bucket.

`test/e2e/rate-limit.e2e-spec.ts` verifies the guard by standing up an
isolated module with `limit: 3`, firing 5 consecutive bad-credential
logins, and asserting the last 2 return 429 while the first 3 return 401.
The `x-forwarded-for` header is set explicitly to pin the tracker key —
otherwise in-test requests share `::1` with every other e2e test in the
pool and bucket interference is non-deterministic.

Why the 10/minute number? Industry defaults (GitHub, GitLab) are around
5–15/minute/IP. Ten leaves room for a user who genuinely forgot their
password to retry a few times, and forces a brute-force attacker to
distribute across >5 IPs per minute to make progress — at which point the
cost is detection, not throughput.

## 5. Error surface

Nest's built-in `HttpExceptionFilter` already:

- Renders every `HttpException` as `{ statusCode, message }`;
- Logs 5xx as `error` and 4xx as `warn` via the logger we wired up;
- Hides stack traces in the response body (they never leave the server —
  they land in the Pino log at `error` level with the request id).

With `NODE_ENV=production`, Pino's default formatter drops the stack from
the serialised log line. For local dev we keep stacks via
`pino-pretty`.

No custom filter yet — a custom one would buy uniformity with the handful
of non-Http errors (e.g. bare `Error` from a mis-configured helper), but
we don't have any in the current codebase. If one surfaces during
Phase 5+ we'll add an `AllExceptionsFilter` that maps to 500 and logs
with the request id.

## 6. Tests

- `test/e2e/hardening.e2e-spec.ts` — 3 tests: core Helmet headers, the
  CSP directives we explicitly chose, `x-powered-by` removed.
- `test/e2e/rate-limit.e2e-spec.ts` — 1 test: auth bucket exhaustion
  flips from 401 to 429.

Total after Phase 4: **168 unit + 34 e2e = 202 tests** green.

## 7. Soutenance defense points

- *Why Helmet over hand-rolling headers?* Every week a new browser
  introduces a new header (COOP/COEP/CORP, Permissions-Policy…). Helmet
  keeps up; we don't want to.
- *Why a separate `auth` bucket?* Brute-force attempts otherwise hide in
  the 100/min generic bucket. The subject requires we protect accounts;
  a targeted bucket is the cheapest defense.
- *Why redact via Pino and not via a middleware?* Redaction at the
  logger is a single enforcement point — any future `logger.info(req)`
  anywhere in the codebase inherits it. Middleware-based scrubbing would
  miss logs emitted from services.
- *Why `'unsafe-inline'` in CSP?* Only for Swagger UI at `/api/docs`.
  The app itself doesn't execute inline scripts; once we move the docs
  behind a separate host we can drop this directive.
- *Why test rate-limit with an isolated module?* The shared module has
  `limit: 10` — flaky across parallel tests. A dedicated module with
  `limit: 3` makes exhaustion deterministic.
