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
      final rooms = await _repository.getRooms(kind: RoomKind.vote);
      final voteRooms = rooms
          .where((room) => room.kind == RoomKind.vote)
          .toList();
      final populatedRooms = await Future.wait(
        voteRooms.map((room) async {
          final tracks = await _repository.getVoteTracks(room.id);
          return room.copyWith(tracks: tracks);
        }),
      );
      _events = populatedRooms;
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
      await fetchEvents();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> suggestTrack(String roomId, Track track) async {
    try {
      await _repository.addVoteTrack(roomId, track);
      await fetchEvents();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // * Handler methods for socket events
  void handleTrackAdded(Track track) {
    for (var i = 0; i < _events.length; i++) {
      final room = _events[i];
      if (room.tracks.any((t) => t.id == track.id)) continue;
      final updatedTracks = List<Track>.from(room.tracks)..add(track);
      _events[i] = room.copyWith(tracks: updatedTracks);
    }
    notifyListeners();
  }

  void handleTrackVoted(String trackId, int score, int votesCount) {
    for (var i = 0; i < _events.length; i++) {
      final room = _events[i];
      final idx = room.tracks.indexWhere((t) => t.id == trackId);
      if (idx != -1) {
        final updatedTrack = room.tracks[idx].copyWith(score: score);
        final updatedTracks = List<Track>.from(room.tracks)
          ..[idx] = updatedTrack;
        updatedTracks.sort((a, b) => b.score.compareTo(a.score));
        _events[i] = room.copyWith(tracks: updatedTracks);
      }
    }
    notifyListeners();
  }

  void handleTrackRemoved(String trackId) {
    for (var i = 0; i < _events.length; i++) {
      final room = _events[i];
      if (room.tracks.any((t) => t.id == trackId)) {
        final updatedTracks = room.tracks
            .where((t) => t.id != trackId)
            .toList();
        _events[i] = room.copyWith(tracks: updatedTracks);
      }
    }
    notifyListeners();
  }
}
