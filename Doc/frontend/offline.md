# Modo Offline y Sincronización en Flutter

El modo offline es una de las caracteristicas clave de nuestro projecto para permitir a los usuarios seguir interactuando con las salas activas (votos y playlists) sin depender de conexion a internet estable.

## Diseño Arquitectonico del Modo Offline

Implementamos un patron **Decorator** sobre el repositorio y una **Cola de Acciones Estructuradas** usando la base de datos NoSQL ultra-rapida `hive_ce`.

### Componentes Clave:

1.  **`OfflineCache`**: La base de datos local Hive en [offline_cache.dart](file:///Users/diegoluna/Documents/42course/music-room/frontend/music_room_app/lib/config/offline_cache.dart). Cachea los modelos de `Room` y `Track` y gestiona la cola de acciones pendientes en memoria local de forma persistente.
2.  **`OfflineRoomRepository`**: Decorador en [offline_room_repository.dart](file:///Users/diegoluna/Documents/42course/music-room/frontend/music_room_app/lib/core/repositories/offline_room_repository.dart) que decide de forma transparente:
    - **Lectura**: Intenta consumir de la API remota. Si hay error de red, lee de la cache local en Hive.
    - **Escritura (Votos / Playlist)**: Aplica un cambio de forma optimista en la cache local para que la UI se actualice de inmediato y guarda la accion en la cola de pendientes.
3.  **`ConnectivitySyncManager`**: Servicio reactivo en [connectivity_sync_manager.dart](file:///Users/diegoluna/Documents/42course/music-room/frontend/music_room_app/lib/core/services/connectivity_sync_manager.dart) que escucha a `connectivity_plus`. En cuanto el internet regresa, procesa la cola de pendientes en orden cronologico.

## Sincronizacion Reactiva y Reconciliacion con el Backend

Al detectar conexion mediante `Connectivity().onConnectivityChanged`:

1.  **Procesamiento FIFO**: El `ConnectivitySyncManager` recorre las acciones pendientes. Las envia secuencialmente al backend real.
2.  **Idempotencia en Backend**: Gracias a las restricciones unicas del backend (como voto unico por `(trackId, userId)` y tracks unicos por `(roomId, provider, providerId)`), reenviar acciones duplicadas es seguro. Si el backend retorna un error `409 Conflict`, el sincronizador lo descarta asumiendo que ya fue aplicado con exito.
3.  **Reconciliacion Final (`GET /sync`)**: Una vez vaciada la cola local, se realiza una peticion GET al endpoint `/sync` para obtener un snapshot limpio de todas las salas e invitaciones del usuario, sobreescribiendo la cache de Hive con la ultima verdad del servidor.
4.  **Reconexion de Sockets**: Finalmente, tras sincronizar la cache local, el `SocketProvider` reconecta su canal de tiempo real para evitar recibir actualizaciones desfasadas.

## Estructura de las Acciones Pendientes (OfflineAction)

Para almacenar temporalmente los cambios realizados sin conexion, el sistema utiliza el modelo [offline_action.dart](file:///Users/diegoluna/Documents/42course/music-room/frontend/music_room_app/lib/models/offline_action.dart). Cada accion registrada cuenta con:

- **`id`**: Clave unica autogenerada con un timestamp que previene duplicados en la base de datos local Hive.
- **`roomId`**: El identificador de la sala donde se realizo la mutacion.
- **`type`**: Define que operacion se ejecuto (por ejemplo `'vote'` para salas de votos o `'addTrack'` para agregar canciones).
- **`payload`**: Mapa con la informacion necesaria requerida por el endpoint del backend.
- **`createdAt`**: Timestamp que garantiza que la sincronizacion mantenga el orden cronologico de las acciones del usuario.

## Control de Fallos y Reversion de Cambios

El sistema cuenta con mecanismos especificos para manejar errores de conexion e inconsistencias durante la sincronizacion:

- **Perdida de red durante la cola**: Si una peticion intermedia de la cola falla por falta de conexion real, el sincronizador pausa inmediatamente el procesamiento. Esto evita que se pierda la sincronia o el orden cronologico del resto de acciones pendientes.
- **Errores definitivos del Servidor**: Si el backend devuelve un error definitivo no recuperable (como `403 Forbidden`), la accion se descarta definitivamente de la cola y el sistema deshace de manera automatica el cambio optimista en la UI, manteniendo la coherencia de los datos con el servidor.
