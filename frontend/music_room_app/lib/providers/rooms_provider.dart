import 'package:flutter/material.dart';
import 'package:music_room_app/core/repositories/mock_api_repository.dart';
import 'package:music_room_app/models/room.dart';

class RoomsProvider extends ChangeNotifier {
	final MockApiRepository _repository;
	List<Room> _rooms = [];
	Room? _currentActiveRoom;
	bool _isLoading = false;
	String? _error;

	RoomsProvider({required MockApiRepository repository}) : _repository = repository;

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

	Future<void> delegateControl(String roomId, String userId) async {
		try {
			await _repository.delegateRoomControl(roomId, userId);
			await fetchRooms();
		} catch (e) {
			_error = e.toString();
			notifyListeners();
		}
	}

	Future<void> revokeControl(String roomId) async {
		try {
			await _repository.revokeRoomControl(roomId);
			await fetchRooms();
		} catch (e) {
			_error = e.toString();
			notifyListeners();
		}
	}
}
