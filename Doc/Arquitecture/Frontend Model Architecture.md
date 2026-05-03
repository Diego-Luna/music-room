# Modelos y Arquitectura del Frontend (Dart/Flutter)

## 1. Estructura de Datos (Frontend mindset)

Para que todo funcione en Flutter (con el sistema de caché **Hive** y el manejo de estado con **Provider**), estos son los objetos principales que manejo:

### A. Perfil de Usuario (User)

Es el objeto que guardo cuando el usuario se loguea.

* **Campos**:
  * `id` (String/UUID): Viene del auth.
  * `email`: Para identificarte.
  * `displayName`: El nombre que se muestra en la app.
  * `avatarUrl`: Link a la foto (si tiene la de google o facebook).
  * `visibility`: Enum (`PUBLIC`, `FRIENDS_ONLY`, `PRIVATE`).
  * `musicPreferences`: Una lista de géneros/artistas favoritos.

### B. El Core de Música (Track)

La unidad mínima. No guardamos el archivo, solo la referencia.

* **Campos**:
  * `id` (String): El ID de Spotify o YouTube.
  * `title`: Nombre de la rola.
  * `artist`: Quién la canta.
  * `albumArtUrl`: Para que la app se vea pro con las portadas.
  * `durationSeconds`: Para la barra de progreso del player.

### C. Contenedores (Events & Playlists)

Uso modelos intermedios para que sea más limpio.

* **Event (La "Room"):**
  * `id`, `name`, `ownerId`, `isPublic`.
  * `tracks`: Lista de `EventTrack`.
* **Playlist (El Editor):**
  * `id`, `name`, `ownerId`, `isPublic`.
  * `tracks`: Lista de `PlaylistTrack`.

---

## 3. Notas para el Backend (Integración)

1. **Modelos Anidados:** Cuando pida un `Event` o una `Playlist`, el backend debería hacerme el favor de incluir los `tracks` ya con la info del `Track` dentro (un `JOIN` en SQL), para que yo pueda pintar la lista de una sin hacer 20 llamadas.

2. **Votación Real-Time:**

   * Cada `EventTrack` tiene un `voteCount`.
   * El objeto `Vote` nos sirve para validar que un usuario no vote 100 veces por la misma canción.
   * El backend debe actualizar el `voteCount` y avisarme por WebSockets (ver `WebSocket Architecture.md`).

3. **Manejo de Dispositivos (Licenses):**
   * El PDF pide que cada dispositivo tenga su licencia.
   * Usaremos `DEVICE_LICENSE` para saber si el iPhone o el Android del usuario tiene permiso de darle "Play/Pause" a la música en ese momento.

---

## 4. Sincronización Offline

Como uso **Hive**, si el backend me manda los datos en este formato JSON, yo los guardo directo en la "caja" (box) local. Si no hay internet, la app sigue funcionando con lo último que recibió.
