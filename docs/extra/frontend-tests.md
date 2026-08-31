# Tests frontend

Depuis `frontend/music_room_app` :

```sh
flutter test
flutter analyze
flutter test integration_test/offline_mode_test.dart -d flutter-tester
```

Mocks : **mocktail** (pas Mockito). CI PR : `flutter test` + `flutter build web` (`validate-pr.yml`). `analyze` et l’integration_test ne sont pas dans le workflow.

`make test` à la racine lance aussi `flutter test`.
