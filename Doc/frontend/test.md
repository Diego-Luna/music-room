# Guía de Pruebas Unitarias y Análisis Estático

Para garantizar la estabilidad multiplataforma de Music Room (Web, Android, iOS), implementamos una suite completa de pruebas automatizadas y analisis estatico estricto en el frontend.

## Pruebas Unitarias y de Widgets con Mocktail

Utilizamos el paquete `mocktail` para mockear dependencias externas como base de datos local Hive, API clients o repositorios de red. Esto nos permite simular fallos de conexion a internet de manera controlada.

### Ejemplo de Estructura de Test (`test/core/services/connectivity_sync_manager_test.dart`):

```dart
class MockRoomRepository extends Mock implements RoomRepository {}
class MockOfflineCache extends Mock implements OfflineCache {}

void main() {
	late ConnectivitySyncManager syncManager;
	late MockRoomRepository mockRemote;
	late MockOfflineCache mockCache;

	setUp(() {
		mockRemote = MockRoomRepository();
		mockCache = MockOfflineCache();
		syncManager = ConnectivitySyncManager(
			remoteRepository: mockRemote,
			cache: mockCache,
		);
	});

	test('should process pending action queue and delete completed ones', () async {
		// * Arrange: configuramos las respuestas de los mocks
		final action = OfflineAction(id: 'a1', roomId: 'r1', type: 'vote', payload: {'trackId': 't1', 'value': 1}, createdAt: DateTime.now());
		when(() => mockCache.getPendingActions()).thenReturn([action]);
		when(() => mockRemote.voteForTrack('r1', 't1', 1)).thenAnswer((_) async {});
		when(() => mockCache.removeAction('a1')).thenAnswer((_) async {});

		// * Act: ejecutamos el metodo a probar
		await syncManager.syncQueue();

		// * Assert: verificamos que se llamaron a los mocks con los parametros correctos
		verify(() => mockRemote.voteForTrack('r1', 't1', 1)).called(1);
		verify(() => mockCache.removeAction('a1')).called(1);
	});
}
```

## Flujo de Desarrollo

Para seguir el flujo para añadir codigo nuevo de forma segura:

1.  **Escribir la implementacion**: Escribe la clase, metodo o logica basica en `lib/`
2.  **Escribir la enfocarse en ser simple**: Enfocarse en que la estrirua se base en ser simple, y sunado los providers
3.  **Escribir la prueba**: Crea un archivo `.dart` dentro del folder `test/` simulando el caso real para evitar que se rompa a futuro.
4.  **Correr la prueba**: Usa la herramienta `flutter test` para verificar que las pruebas pasan.
5.  **Refactorizar**: Si es necesario, refactorizar la implementacion y las pruebas.

## Análisis Estático (Quality Checks)

Antes de enviar cualquier pull request o subir cambios a produccion, es obligatorio ejecutar las siguientes validaciones locales en tu consola:

```bash
# Analisis de formato y buenas practicas de Dart
flutter analyze

# Correr toda la suite de pruebas del frontend
flutter test
```

> **Nota**: en el merge es necesario que pasen las pruebas y que compile el codigo.
