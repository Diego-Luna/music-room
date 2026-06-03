import 'package:flutter/material.dart';
import 'package:music_room_app/core/repositories/room_repository.dart';
import 'package:music_room_app/models/room.dart';
import 'package:music_room_app/models/track.dart';

// * Manages VOTE-kind rooms — for live track voting sessions
class EventsProvider extends ChangeNotifier {
  final RoomRepository _repository;
  List<Room> _events = [];
  Room? _selectedEvent;
  bool _isLoading = false;
  String? _error;
  final Set<String> _votedTrackIds = {};

  EventsProvider({required RoomRepository repository})
    : _repository = repository;

  List<Room> get events => _events;
  Room? get selectedEvent => _selectedEvent;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Set<String> get votedTrackIds => _votedTrackIds;

  void selectEvent(Room event) {
    _selectedEvent = event;
    notifyListeners();
  }

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
      if (_selectedEvent == null && _events.isNotEmpty) {
        _selectedEvent = _events.first;
      } else if (_selectedEvent != null) {
        final idx = _events.indexWhere((e) => e.id == _selectedEvent!.id);
        if (idx != -1) {
          _selectedEvent = _events[idx];
        } else {
          _selectedEvent = _events.isNotEmpty ? _events.first : null;
        }
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // * value 1 = upvote, 0 = remove vote
  Future<void> voteForTrack(String roomId, String trackId, int value) async {
    _votedTrackIds.add(trackId);
    notifyListeners();
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

  Future<Room> createEvent({
    required String name,
    required String description,
    required bool isPublic,
    required String voteAccess,
    required String voteWindow,
    DateTime? voteStartsAt,
    DateTime? voteEndsAt,
    double? voteLocationLat,
    double? voteLocationLng,
    double? voteLocationRadiusM,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final room = await _repository.createRoom(
        name: name,
        kind: RoomKind.vote,
        isPublic: isPublic,
        description: description,
        voteAccess: voteAccess,
        voteWindow: voteWindow,
        voteStartsAt: voteStartsAt,
        voteEndsAt: voteEndsAt,
        voteLocationLat: voteLocationLat,
        voteLocationLng: voteLocationLng,
        voteLocationRadiusM: voteLocationRadiusM,
      );
      await fetchEvents();
      final idx = _events.indexWhere((e) => e.id == room.id);
      if (idx != -1) {
        _selectedEvent = _events[idx];
      }
      return room;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
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
      if (_selectedEvent?.id == room.id) {
        _selectedEvent = _events[i];
      }
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
        if (_selectedEvent?.id == room.id) {
          _selectedEvent = _events[i];
        }
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
        if (_selectedEvent?.id == room.id) {
          _selectedEvent = _events[i];
        }
      }
    }
    notifyListeners();
  }
}
