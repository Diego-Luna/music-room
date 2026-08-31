# VI.1 — Multi-platform / web responsive

Le sujet : mobile déjà (IV.2) ; en bonus, **le même service sur le web**, *responsive* (toute taille d’écran). Flutter compile iOS, Android **et** web **sans réécrire le client** — c’est le bénéfice du choix IV.1.

## Plateformes

| Cible | Où |
|---|---|
| Android | `android/`, `flutter run` / APK |
| iOS | `ios/` |
| Web | `web/` + `flutter build web` ; CI `deploy-main.yml` → GitHub Pages |

Hash URLs (`HashUrlStrategy`) pour Pages (`/#/auth/verify-email?token=`).

## Responsive

- Viewport : `width=device-width` dans `web/index.html` (model-viewer / 3D en a besoin **avant** le boot Flutter). Flutter le remplace ensuite → warning debug « tag will be replaced », inoffensif.
- PWA : `orientation: any` (plus `portrait-primary`).
- `AppBreakpoints.compact` (700) : bottom nav vs barre haute (`ResponsiveNavbar` / `MainPage`).
- `ResponsiveBody` : contenu plafonné à 960 px (shell) / 480 px (auth) sur un écran large.
- Player : carte 400 px centrée au-delà de 700 px.

## Même code, branches `kIsWeb`

OAuth GIS (`GoogleSignInButton.renderButton`), Facebook `webAndDesktopInitialize`, headers `x-platform: WEB`, modèles 3D (`assets/` prefix). Login **et** Signup utilisent le bouton GIS sur web (`authenticate()` n’existe pas sur web).

## Démo

```sh
cd frontend/music_room_app
flutter run -d chrome
# ou le build Pages déjà déployé
```

Redimensionner la fenêtre : < 700 px barre du bas ; au-dessus barre du haut + colonnes centrées.
