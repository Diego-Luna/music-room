# Music Room — Frontend (Flutter)

Client iOS / Android / web. Télécommande REST (Dio) + Socket.IO. Hive = cache / settings / file offline, **pas** la vérité.

Doc écrans ↔ sujet : [`docs/sujet/07-mobile.md`](../docs/sujet/07-mobile.md).  
Providers / offline / UI : [`docs/extra/`](../docs/extra/).

## Run

```sh
cd frontend/music_room_app
flutter pub get
flutter run
```

URL API : Login ou Settings. Émulateur Android : `http://10.0.2.2:3000`. iOS simulateur : `http://localhost:3000`. iPhone physique en `http://` LAN : ATS peut bloquer.

OAuth natif : `local.properties` / `Secrets.xcconfig` / dart-defines. Sans ça, mail + mot de passe suffisent.

```sh
flutter test
flutter analyze
```

`make test` / `make install` depuis la racine du repo.
