import 'package:flutter/material.dart';
import 'package:music_room_app/core/repositories/room_repository.dart';
import 'package:music_room_app/models/room.dart';

class RoomsProvider extends ChangeNotifier {
  final RoomRepository _repository;
  List<Room> _rooms = [];
  Room? _currentActiveRoom;
  bool _isLoading = false;
  String? _error;

  RoomsProvider({required RoomRepository repository})
    : _repository = repository;

  List<Room> get rooms => _rooms;
  Room? get currentActiveRoom => _currentActiveRoom;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void selectRoom(Room room) {
    _currentActiveRoom = room;
    notifyListeners();
  }

  Future<void> fetchRooms() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _rooms = await _repository.getRooms();
      if (_currentActiveRoom != null) {
        _currentActiveRoom = _rooms.firstWhere(
          (r) => r.id == _currentActiveRoom!.id,
          orElse: () => _currentActiveRoom!,
        );
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void handleMemberJoined(String roomId, String userId) {
    // TODO: Implement member list update when model supports it
    // Placeholder to trigger UI refresh
    notifyListeners();
  }

  void handleMemberLeft(String roomId, String userId) {
    // TODO: Implement member removal when model supports it
    notifyListeners();
  }
}
