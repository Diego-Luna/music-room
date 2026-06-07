import 'package:hive_ce/hive.dart';
import 'package:music_room_app/models/room.dart';
import 'package:music_room_app/models/offline_action.dart';

class OfflineCache {
  final Box<Map>? _testRoomsBox;
  final Box<Map>? _testActionsBox;

  OfflineCache() : _testRoomsBox = null, _testActionsBox = null;

  // * Test constructor to inject mocked boxes
  OfflineCache.test({required Box<Map> roomsBox, required Box<Map> actionsBox})
    : _testRoomsBox = roomsBox,
      _testActionsBox = actionsBox;

  Box<Map> get _roomsBox => _testRoomsBox ?? Hive.box<Map>('cached_rooms');
  Box<Map> get _actionsBox =>
      _testActionsBox ?? Hive.box<Map>('pending_actions');

  Future<void> init() async {
    // * Handled in HiveConfig, kept for structure
  }

  // * Rooms caching
  Future<void> saveRooms(List<Room> rooms) async {
    for (final room in rooms) {
      await _roomsBox.put(room.id, room.toJson());
    }
  }

  List<Room> getRooms() {
    return _roomsBox.values
        .map((json) => Room.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  Future<void> saveRoom(Room room) async {
    await _roomsBox.put(room.id, room.toJson());
  }

  Room? getRoomById(String id) {
    final data = _roomsBox.get(id);
    if (data == null) return null;
    return Room.fromJson(Map<String, dynamic>.from(data));
  }

  // * Drop cached rooms that are absent from [keepIds], so rooms deleted
  // * server-side don't linger as ghosts offline. Caller MUST pass the full,
  // * unfiltered set of the user's rooms (never a kind-filtered subset).
  Future<void> deleteRoomsExcept(Set<String> keepIds) async {
    final stale = _roomsBox.keys
        .where((key) => !keepIds.contains(key))
        .toList();
    for (final key in stale) {
      await _roomsBox.delete(key);
    }
  }

  // * Queue management
  Future<void> enqueueAction(OfflineAction action) async {
    await _actionsBox.put(action.id, action.toJson());
  }

  List<OfflineAction> getPendingActions() {
    final actions = _actionsBox.values
        .map((json) => OfflineAction.fromJson(Map<String, dynamic>.from(json)))
        .toList();
    // * FIFO ordering
    actions.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return actions;
  }

  Future<void> removeAction(String id) async {
    await _actionsBox.delete(id);
  }
}
