# Phase 12 — Push notifications

## Scope

A small layer that lets the backend push events to users' devices
when they are offline (or the app is backgrounded). Currently used by
the delegation flow ("You're the DJ") and ready to be wired into
other domain events (track removed from your playlist, room invite
received, etc.).

## Pluggable transport

We use the **Strategy pattern** to keep the choice of push provider
out of the domain code. `PushTransport` is an abstract class with one
method:

```typescript
export abstract class PushTransport {
  abstract send(envelope: PushEnvelope): Promise<PushSendResult>;
}

export interface PushEnvelope {
  token: string;
  platform: 'IOS' | 'ANDROID' | 'WEB';
  title: string;
  body: string;
  data?: Record<string, string>;
}
```

Two concrete implementations:
- **`LogPushTransport`** (default, registered in `NotificationsModule`) —
  logs the envelope with a redacted token. Useful in dev / tests /
  CI: the notification path runs end-to-end without needing
  Firebase / APNS credentials.
- **A real transport** (FCM / APNS / web-push) is a future addition;
  swap one provider line in `notifications.module.ts` to enable it.

## Device tokens

```prisma
enum DevicePlatform { IOS, ANDROID, WEB }

model DeviceToken {
  id          String         @id @default(uuid())
  userId      String
  token       String                       // FCM / APNS / web-push subscription
  platform    DevicePlatform
  createdAt   DateTime       @default(now())
  lastSeenAt  DateTime       @default(now())

  @@unique([platform, token])              // a token can belong to only one user
  @@index([userId])
}
```

Mobile clients register a token via
`POST /notifications/register { token, platform }` after the OS
delivers it; deregister via `DELETE /notifications/register
{ token }` on logout. `PushService` keeps the rows fresh by upserting
on register (updates `lastSeenAt`).

## Sending flow

`PushService.sendToUser(userId, { title, body, data })`:
1. Fetch all `DeviceToken` rows for the user
2. For each: call `transport.send(envelope)`
3. If the transport returns `invalidToken: true` → delete the row
   (e.g., user uninstalled the app, FCM returns invalid_registration)
4. Fire-and-forget (`void this.push?.sendToUser(...)`) — the caller
   never waits on notification delivery

The fire-and-forget pattern is intentional: a slow notification
backend should not slow down the user-facing API. Any send failure
is logged and (if `invalidToken`) cleans up the dead row.

## Optional injection

`PushService` is `@Optional()` in every domain service that uses it
(`delegation.service.ts`, future `playlist.service.ts`, etc.). So
the domain code:
1. Tests cleanly without a push provider in the module
2. Works in the running app where the module *is* registered
3. Could be globally disabled by simply not registering the module
   (e.g., a test deployment)

## Soutenance defense points

- *Why the Strategy pattern instead of just calling FCM directly?* —
  Pluggability for prod (FCM vs APNS vs web-push) and zero-config
  dev (LogPushTransport prints to the logger). Also keeps the
  `PushService` testable with a stub transport.
- *Why fire-and-forget?* — A delegation grant should commit
  successfully even if the push backend is slow. The user gets a
  realtime event over Socket.IO immediately (in-app); the push is
  a fallback for the offline case.
- *Can a malicious user steal someone's device token?* — Tokens
  are FCM / APNS / web-push values that only the OS hands out to
  the legitimate app. The API endpoint
  (`POST /notifications/register`) is JWT-protected, so the user
  must already be authenticated.
- *What happens when a user logs out from one device but stays
  logged in on another?* — The mobile client deregisters the token
  on logout via `DELETE /notifications/register`. The other
  device's token is unaffected — push notifications continue
  going to it.
- *Why store the token unhashed?* — Push tokens are not secrets
  in the cryptographic sense; they're addressing identifiers
  issued by FCM / APNS. Hashing would prevent us from sending
  pushes (we need the original to call the provider). The
  `@@unique([platform, token])` constraint prevents the same
  token being claimed by two users.
