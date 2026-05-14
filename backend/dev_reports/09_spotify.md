# Phase 9 — Spotify integration

## Scope

Spotify is our music data + playback provider:
- Authorize a user (OAuth 2.0 Authorization Code)
- Refresh expired access tokens
- Search the track catalog
- Drive playback (play / pause / next / previous / volume)
- Disconnect

The subject (Chapter III) warns:
> "Warning the SDK you choose must not do your work."

So Spotify provides **the music**, but the business logic (rooms,
votes, delegation, playlist ordering, …) is all hand-written.

## OAuth flow

```
                              ┌──────────────────────────┐
                              │      Spotify accounts    │
                              │     accounts.spotify.com │
                              └────────────┬─────────────┘
                                           │
                                           │ ① redirect to authorize URL
                                           │    with state + scopes
                                           │
┌─────────────┐    GET /authorize-url    ◄─┘                          ┌───────────┐
│  Mobile     │ ──────────────────────────────────────────────────────│  Backend  │
│  client     │                                                       └──────┬────┘
│  (Flutter)  │ ② follows the URL, user logs into Spotify, returns          │
└──────┬──────┘    to the redirect URI with ?code=...&state=...             │
       │                                                                    │
       │  ③ POST /callback { code, state }                                  │
       └────────────────────────────────────────────────────────────────────▶
                                                                            │
                                                       ④ Exchange code →    │
                                                          Spotify token API │
                                                                            │
                                                       ⑤ Fetch /me to get  │
                                                          Spotify user id  │
                                                                            │
                                                       ⑥ Upsert            │
                                                          SocialAccount    │
                                                                            │
                                                       ⑦ Respond           │
                                                          { connected,     │
                                                            expiresAt }    │
```

Code lives in `src/spotify/spotify.service.ts`. `buildAuthorizeUrl`
generates the URL with scopes (`user-read-private`,
`user-modify-playback-state`, `streaming`, …) and a random
`state` (16 bytes hex). `exchangeCode` POSTs to
`/api/token` with HTTP Basic auth (`client_id:client_secret` base64),
parses the response, fetches the profile, persists everything as a
`SocialAccount` row (provider = `spotify`).

## Token refresh strategy

Access tokens expire after 1 hour. `getAccessTokenForUser(userId)`
is the single read path; it:
1. Looks up the `SocialAccount` row
2. If `tokenExpiresAt - 60s` still in the future → return current
   access token
3. Else if a `refreshToken` exists → POST to `/api/token` with
   `grant_type=refresh_token`, persist the new pair (Spotify may
   omit a new refresh token; we keep the old one in that case)
4. Else → throw `UnauthorizedException('Spotify access token
   expired and no refresh token stored')`

The **60 s slack** avoids a race where the token is valid right now
but expires mid-call. We refresh slightly early instead.

## Playback API surface

`PlaybackService` is the room-layer caller; it delegates to
`SpotifyService.play / pause / next / previous / setVolume`. Each
method:
1. Calls `getAccessTokenForUser(delegateUserId)` (the delegate is
   the Spotify-authenticated user whose device receives the call)
2. Calls Spotify Web API with a bearer token
3. Maps Spotify HTTP error codes:
   - `404` → `NotFoundException('No active Spotify device for the
     delegate')` (the most common failure, surfaced clearly)
   - non-`2xx` non-`204` → `InternalServerErrorException(\`Spotify
     playback failed (${status})\`)` with the original status code

`setVolume` clamps and rounds the input (`Math.max(0, Math.min(100,
Math.round(percent)))`) before forwarding — guards against bad
inputs reaching Spotify.

## Why `fetch` and not a Spotify SDK

| Criterion                  | Native `fetch`                     | `spotify-web-api-node`       |
|----------------------------|-------------------------------------|------------------------------|
| Dependency weight          | 0 (built into Node 24)              | + dependency tree            |
| API surface predictability | What Spotify docs say               | SDK abstraction may lag      |
| Subject "SDK must not do your work" | Maximum compliance         | Slight abstraction smell     |
| Type safety                | Hand-written types where needed     | SDK types                    |

The SDK we'd save ~50 LOC of fetch boilerplate. We'd lose
fine-grained control over error handling (the 404 mapping above) and
add a dep the jury could question. Trade picks fetch.

## Search

`SpotifyService.search(userId, query, limit)`:
- Clamps limit to `[1, 50]`
- Calls `/search?q=…&type=track&limit=…` with bearer auth
- Maps Spotify's nested track shape to our flat
  `SpotifySearchResult` (id, name, artists[], durationMs,
  artworkUrl, uri) for the frontend

This is the catalog used by VOTE and PLAYLIST rooms to populate
their tracks (`POST /rooms/:id/tracks` / `POST /rooms/:id/playlist`
take the Spotify track id and copy id/name/artist/duration locally).

## Soutenance defense points

- *Where is the boundary "SDK must not do the work"?* — Spotify
  supplies us with track metadata and the playback transport.
  Everything else — voting, scoring, ordering, delegation, room
  membership — is hand-rolled in `src/rooms/`. The Spotify Web
  API never decides who can do what, only "play this URI on this
  device" once we've made the decision.
- *Why do you refresh tokens with a 60 s slack instead of just
  catching 401s?* — Catching 401 mid-call breaks the request and
  forces a retry, doubling latency on a hot path (playback). The
  slack proactively keeps tokens fresh.
- *What if the user revokes our app on the Spotify side?* — Next
  refresh call returns 400; we surface `BadRequestException` and
  let the user re-link via `POST /callback` again. The
  `SocialAccount` row stays in DB.
- *Can two users share one Spotify account?* — Technically yes
  (the unique constraint is `(provider, providerId)` — but
  effectively no, because we also require
  `(provider, userId)` unique. A given Spotify identity is bound
  to exactly one Music Room user.
- *What happens if Spotify rate-limits us?* — Spotify uses 429
  with `Retry-After`. Our current code surfaces this as a 500
  (`Spotify playback failed (429)`); a production-grade improvement
  would be to honor `Retry-After` and either queue or surface a
  more specific error. Out of scope for the subject.
