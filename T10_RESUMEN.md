# Resumen de cambios — Rama `feat/t10-social-login`

> Guía para revisar el código de esta rama: **login social (Google / Facebook)**
> y **vinculación de cuenta** (T10 → T11). Todo el código toca solo el **frontend**
> (`frontend/music_room_app/`); el backend **no se modificó** (ya tenía `/auth/social`
> y `/auth/link-social`, ver sección 3).

---

## 1. Qué se hizo (código Dart, versión final)

| Elemento | Archivo |
|---|---|
| Dependencias `google_sign_in ^6.2.1` + `flutter_facebook_auth ^7.1.6` | `pubspec.yaml` |
| Endpoints `/auth/social` y `/auth/link-social` | `lib/config/api_config.dart` |
| `/auth/social` marcado como **público** en el interceptor (si no, un token caducado dispararía un bucle de logout) | `lib/config/api_client.dart` |
| Abstracción `SocialAuthService` + implementación con los plugins (devuelve el **access token OAuth** que el backend valida) | `lib/core/auth/social_auth_service.dart` *(NUEVO)* |
| `AuthProvider.socialLogin()` + `linkSocial()` | `lib/providers/auth_provider.dart` |
| Botones Google/Facebook conectados (login **y** signup) → `socialLogin` | `lib/pages/auth/pages/login_page.dart`, `signup_page.dart` |
| Sección "Link account" (T11) en ajustes → `linkSocial` | `lib/pages/settings/pages/settings_page.dart` |
| Eliminado el `try {}` muerto de Firebase + import sin usar | `lib/main.dart` |
| Tests de `socialLogin` (éxito + cancelación) y `linkSocial` (fake inyectado) | `test/providers/auth_provider_test.dart` |

---

## 2. Decisiones de diseño (para defender)

- **`google_sign_in` v6.2.x (no v7):** el backend valida un **access token OAuth**
  (llama a `googleapis.com/oauth2/v2/userinfo` con `Bearer <token>` y comprueba la
  audiencia con `tokeninfo`). La v6 expone `account.authentication.accessToken`
  directamente; la v7 separa autenticación y autorización y no entrega el access
  token de forma tan directa.
- **`link-social` en `settings_page`, no en `profile_page`:** este último lo modifica
  Diego en la rama `frontend` → así evitamos conflictos. Además, vincular una cuenta
  exige estar ya logueado, cosa que no ocurre justo tras el registro (que requiere
  verificación por email y no devuelve tokens).
- **Abstracción `SocialAuthService`:** mismo patrón que `AudioPlayerService` en T1.
  Aísla los SDK nativos en un solo lugar y mantiene `AuthProvider` testeable
  (los tests inyectan un fake en vez del plugin).

### Flujo

```
botón Google/Facebook → SocialAuthService.signIn(provider)  [flujo OAuth nativo]
   → access token del proveedor
   → POST /auth/social { provider, accessToken }   [público]
   → backend valida el token y devuelve { accessToken, refreshToken } propios
   → se guardan los tokens y se decodifica el User  ✅

Vincular (usuario ya logueado):
   ajustes → SocialAuthService.signIn → POST /auth/link-social { provider, accessToken }  [protegido]
```

Contrato del backend (idéntico en ambos endpoints):

```json
{ "provider": "google" | "facebook", "accessToken": "<token del proveedor>" }
```

---

## 3. Backend: ya estaba listo (no se tocó)

- `POST /auth/social` → `auth.controller.ts:98`, `auth.service.ts:162`
- `POST /auth/link-social` → `auth.controller.ts:113`, `auth.service.ts:214`
- Verificación del token en `verifySocialToken` (`auth.service.ts:496`):
  - Google: valida la audiencia con `tokeninfo` y lee el perfil de `oauth2/v2/userinfo`.
  - Facebook: valida la app con `debug_token` y lee el perfil de `graph.facebook.com`.

---

## 4. Pendiente: credenciales nativas (no se pueden generar desde el código)

El código compila y corre, pero el flujo OAuth solo funcionará con esto configurado:

1. **Google Cloud Console** → OAuth Client IDs (Android con SHA-1, iOS, Web):
   - Android: `android/app/google-services.json`
   - iOS: `ios/Runner/GoogleService-Info.plist` + URL scheme (reversed client ID) en `Info.plist`
   - Web: `<meta name="google-signin-client_id" content="...">` en `web/index.html`
2. **Facebook Developers** → App ID + Client Token:
   - Android: `facebook_app_id` / `fb_login_protocol_scheme` / `facebook_client_token`
     en `strings.xml` + `<meta-data>` y `FacebookActivity` en `AndroidManifest.xml`
   - iOS: `FacebookAppID`, `FacebookClientToken`, `CFBundleURLSchemes` (`fb<APP_ID>`),
     `LSApplicationQueriesSchemes` en `Info.plist`
3. **Backend (.env)** → `GOOGLE_CLIENT_ID`, `FACEBOOK_APP_ID`, `FACEBOOK_APP_SECRET`.

---

## 5. Verificación

- `flutter analyze lib/ test/` → **No issues found**
- `flutter test` → **82/82 tests OK** (incluye 3 nuevos tests de login/vinculación social)

---

## 6. Nota sobre conflictos con la rama `frontend` (Diego)

Sin conflicto con sus archivos (`user.dart`, `profile_page.dart`, `profile_provider.dart`),
**salvo `pubspec.lock`** (lo modificó él y nosotros al añadir los plugins). Conflicto menor,
se resuelve con `flutter pub get` tras el merge.

> `test/debug_api_test.dart` sigue presente en esta rama (solo se eliminó en `feat/t1-search`);
> desaparecerá al mergear T1.
