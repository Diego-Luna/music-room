# Arquitectura y Uso de Providers (State Management)

En el frontend de nuestro projecto, toda la organisacion del estado global se maneja utilizando el paquete `provider`.
Esto nos permite separar la logica de negocio de la presentacion de manera mas modular y limpia.

## Estructura General

Todos los providers estan ubicados en la carpeta `lib/providers/` y son clases que extienden `ChangeNotifier`. Cuando ocurre un cambio en los datos, se llama a `notifyListeners()` para redibujar de forma reactiva los widgets correspondientes.

### Principales Providers del Projecto:

1.  **`RoomsProvider`**: Se encarga de listar y seleccionar las salas (`Room`). Es el nucleo para la navegacion y la gestion del controlador activo en salas de tipo `DELEGATE`.
2.  **`EventsProvider`**: Gestiona las salas de votacion en vivo (`RoomKind.vote`). Controla la adicion y el conteo de votos de las pistas (`Track`), manteniendo la lista ordenada por puntuacion.
3.  **`PlaylistsProvider`**: Maneja las salas de tipo playlist colaborativa (`RoomKind.playlist`). Permite añadir, remover y reordenar canciones usando indices fraccionales para evitar conflictos.
4.  **`SocketProvider`**: Coordina las conexiones en tiempo real usando WebSockets con `socket_io_client`. Escucha los eventos emitidos por el backend y los propaga hacia los demas providers (como votos actualizados o canciones agregadas).
5.  **`AuthProvider`**: Administra la sesion activa del usuario (login, registro y recuperacion), guardando las credenciales locales de forma segura con `TokenStorage`.
6.  **`PlayerProvider`**: Controla el reproductor de musica y los eventos de playback (reproduccion, pausa, volumen).

## Registro e Inyeccion de Dependencias

Los providers se inicializan en el contenedor de dependencias `setupLocator()` ubicado en `lib/core/routing/app_router.dart` y se inyectan en el arbol de widgets en `main.dart` utilizando `MultiProvider`:

```dart
MultiProvider(
	providers: [
		ChangeNotifierProvider.value(value: navigationProvider),
		ChangeNotifierProvider.value(value: authProvider),
		ChangeNotifierProvider.value(value: themeProvider),
		ChangeNotifierProvider.value(value: eventsProvider),
		ChangeNotifierProvider.value(value: playlistsProvider),
		ChangeNotifierProvider.value(value: roomsProvider),
		ChangeNotifierProvider.value(value: playerProvider),
		ChangeNotifierProvider.value(value: socketProvider),
	],
	child: const MyApp(),
)
```

## Buenas Practicas de Consumo en la UI

Para consumir la informacion de los providers en tus views, utiliza las siguientes herramientas nativas:

- **`context.watch<T>()`**: Util para redibujar un widget completo cuando cambie el estado de un provider.
- **`context.read<T>()`**: Ideal para ejecutar metodos o callbacks (ej. al presionar un boton) sin subscribirse a los cambios (evitando rebuilds innecesarios).
- **`Consumer<T>`**: Para redibujar unicamente un widget especifico y mantener el resto del widget tree estatico.

Esto evita realizar llamadas asincronas de red directamente en los constructores de los providers. Siempre utiliza metodos dedicados (como `fetchRooms()`) llamados despues de montar la pantalla.
