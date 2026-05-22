import 'package:flutter/material.dart';
import 'package:music_room_app/core/repositories/room_repository.dart';
import 'package:music_room_app/models/room.dart';
import 'package:music_room_app/models/track.dart';

// * Manages VOTE-kind rooms — for live track voting sessions
class EventsProvider extends ChangeNotifier {
  final RoomRepository _repository;
  List<Room> _events = [];
  bool _isLoading = false;
  String? _error;

  EventsProvider({required RoomRepository repository})
    : _repository = repository;

  List<Room> get events => _events;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchEvents() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _events = await _repository.getRooms(kind: RoomKind.vote);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // * value 1 = upvote, 0 = remove vote
  Future<void> voteForTrack(String roomId, String trackId, int value) async {
    try {
      await _repository.voteForTrack(roomId, trackId, value);
      _events = await _repository.getRooms(kind: RoomKind.vote);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> suggestTrack(String roomId, Track track) async {
    try {
      await _repository.addVoteTrack(roomId, track);
      _events = await _repository.getRooms(kind: RoomKind.vote);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
}
