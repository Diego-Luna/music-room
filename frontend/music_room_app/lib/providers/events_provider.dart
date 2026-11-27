import 'package:flutter/material.dart';
import 'package:music_room_app/config/location_config.dart';
import 'package:music_room_app/core/repositories/room_repository.dart';
import 'package:music_room_app/core/utils/api_error_handler.dart';
import 'package:music_room_app/models/room.dart';
import 'package:music_room_app/models/track.dart';

// * Manages VOTE-kind rooms — for live track voting sessions
class EventsProvider extends ChangeNotifier {
  final RoomRepository _repository;
  List<Room> _events = [];
  Room? _selectedEvent;
  bool _isLoading = false;
  String? _error;

  EventsProvider({required RoomRepository repository})
    : _repository = repository;

  List<Room> get events => _events;
  Room? get selectedEvent => _selectedEvent;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void selectEvent(Room event) {
    _selectedEvent = event;
    notifyListeners();
  }

  /// Loads one event by id, including its queue. Used when the address is
  /// opened directly, for example after a browser reload.
  Future<Room> loadEvent(String roomId) async {
    final room = await _repository.getRoomById(roomId);
    if (room.kind != RoomKind.vote) {
      throw Exception('This event is unavailable.');
    }
    final tracks = await _repository.getVoteTracks(roomId);
    final full = room.copyWith(tracks: tracks);
    final index = _events.indexWhere((event) => event.id == roomId);
    if (index == -1) {
      _events = [..._events, full];
    } else {
      final next = [..._events];
      next[index] = full;
      _events = next;
    }
    _selectedEvent = full;
    notifyListeners();
    return full;
  }

  Future<void>? _fetchEventsFuture;
  int _fetchGeneration = 0;

  Future<void> fetchEvents({bool force = false}) async {
    if (_fetchEventsFuture != null && !force) {
      return _fetchEventsFuture!;
    }
    final generation = ++_fetchGeneration;
    final future = _doFetchEvents(generation);
    _fetchEventsFuture = future;
    try {
      await future;
    } finally {
      if (_fetchEventsFuture == future) {
        _fetchEventsFuture = null;
      }
    }
  }

  Future<void> _doFetchEvents(int generation) async {
    if (generation != _fetchGeneration) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final rooms = await _repository.getRooms(kind: RoomKind.vote);
      if (generation != _fetchGeneration) return;
      final voteRooms = rooms
          .where((room) => room.kind == RoomKind.vote)
          .toList();
      final populatedRooms = await Future.wait(
        voteRooms.map((room) async {
          try {
            final tracks = await _repository.getVoteTracks(room.id);
            return room.copyWith(tracks: tracks);
          } catch (_) {
            return room;
          }
        }),
      );
      if (generation != _fetchGeneration) return;
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
      if (generation != _fetchGeneration) return;
      _error = e.toString();
    } finally {
      if (generation == _fetchGeneration) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Room _asOwner(Room room) =>
      room.myRole == 'OWNER' ? room : room.copyWith(myRole: 'OWNER');

  // * value 1 = vote for the track, 0 = clear that vote.
  // * V.2.1: attach lat/lng from LocationConfig (Settings) for geo-gated rooms.
  Future<void> voteForTrack(
    String roomId,
    String trackId,
    int value, {
    double? lat,
    double? lng,
  }) async {
    if (value != 0 && value != 1) {
      throw ArgumentError.value(value, 'value', 'Vote must be 1 or 0');
    }
    final room = _findRoom(roomId);
    final snapshot = room == null ? null : List<Track>.from(room.tracks);
    if (room != null && snapshot != null) {
      final currentId = room.currentTrackId;
      final nextTracks = [
        for (final track in snapshot)
          if (track.id == trackId)
            track.copyWith(
              myVote: value,
              score: track.score + (value - (track.myVote == 1 ? 1 : 0)),
            )
          else if (value == 1 && track.myVote == 1 && track.id != currentId)
            track.copyWith(myVote: 0, score: track.score - 1)
          else
            track,
      ];
      _setTracks(roomId, nextTracks);
    }
    _error = null;
    notifyListeners();
    try {
      final position = (lat != null && lng != null)
          ? GeoPoint(lat: lat, lng: lng)
          : await LocationConfig.resolve();
      await _repository.voteForTrack(
        roomId,
        trackId,
        value,
        lat: position?.lat,
        lng: position?.lng,
      );
      await fetchEvents(force: true);
    } catch (e) {
      if (snapshot != null) _setTracks(roomId, snapshot);
      _error = ApiErrorHandler.getMessage(e);
      notifyListeners();
      rethrow;
    }
  }

  Room? _findRoom(String roomId) {
    for (final room in _events) {
      if (room.id == roomId) return room;
    }
    final selected = _selectedEvent;
    if (selected?.id == roomId) return selected;
    return null;
  }

  void _setTracks(String roomId, List<Track> tracks) {
    final sorted = [...tracks]..sort((a, b) => b.score.compareTo(a.score));
    Room update(Room room) {
      if (room.id != roomId) return room;
      return room.copyWith(tracks: sorted);
    }

    _events = _events.map(update).toList();
    final selected = _selectedEvent;
    if (selected?.id == roomId) _selectedEvent = update(selected!);
  }

  // * Invite a friend to a (private) room — POST /rooms/:id/invitations.
  // Throws on failure so the UI can surface the backend message.
  Future<void> inviteFriend(String roomId, String userId) async {
    await _repository.inviteToRoom(roomId, userId);
  }

  Future<void> suggestTrack(String roomId, Track track) async {
    _error = null;
    try {
      await _repository.addVoteTrack(roomId, track);
      await fetchEvents(force: true);
    } catch (e) {
      _error = ApiErrorHandler.getMessage(e);
      notifyListeners();
      rethrow;
    }
  }

  // * Owner/admin edits a vote room's settings. Rethrows so the UI can surface
  //   the reason. Keeps the selected event and its loaded tracks in sync.
  Future<void> updateEvent(
    String roomId, {
    String? name,
    String? description,
    bool? isPublic,
    String? voteAccess,
  }) async {
    try {
      final updated = await _repository.updateRoom(
        roomId,
        name: name,
        description: description,
        isPublic: isPublic,
        voteAccess: voteAccess,
      );
      final idx = _events.indexWhere((e) => e.id == roomId);
      if (idx != -1) {
        final merged = updated.copyWith(tracks: _events[idx].tracks);
        _events[idx] = merged;
        if (_selectedEvent?.id == roomId) _selectedEvent = merged;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // * Owner-only: delete an event room. Rethrows so the UI can surface the
  //   error; drops it from the local list on success.
  Future<void> deleteEvent(String roomId) async {
    try {
      await _repository.deleteRoom(roomId);
      _events = _events.where((e) => e.id != roomId).toList();
      if (_selectedEvent?.id == roomId) _selectedEvent = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
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
      final created = _asOwner(
        await _repository.createRoom(
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
        ),
      );
      _events = [created, ..._events.where((event) => event.id != created.id)];
      _selectedEvent = created;
      notifyListeners();
      await fetchEvents(force: true);
      final idx = _events.indexWhere((e) => e.id == created.id);
      if (idx != -1) {
        _selectedEvent = _events[idx];
      } else {
        _events = [created, ..._events];
        _selectedEvent = created;
      }
      return created;
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
    final targetId = track.roomId;
    if (targetId == null) return;
    for (var i = 0; i < _events.length; i++) {
      final room = _events[i];
      if (room.id != targetId) continue;
      if (room.tracks.any((t) => t.id == track.id)) continue;
      final updatedTracks = List<Track>.from(room.tracks)..add(track);
      _events[i] = room.copyWith(tracks: updatedTracks);
      if (_selectedEvent?.id == room.id) {
        _selectedEvent = _events[i];
      }
    }
    notifyListeners();
  }

  /// V.6: reset user-scoped state on logout.
  void clear() {
    _events = [];
    _selectedEvent = null;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  void handleNowPlaying(String roomId, String? trackId, {DateTime? startedAt}) {
    var changed = false;
    for (var i = 0; i < _events.length; i++) {
      if (_events[i].id != roomId) continue;
      _events[i] = _events[i].copyWith(
        currentTrackId: trackId,
        currentTrackStartedAt: startedAt,
        playbackPausedAt: null,
      );
      if (_selectedEvent?.id == roomId) _selectedEvent = _events[i];
      changed = true;
    }
    if (changed) notifyListeners();
  }

  void applyPlayback(String roomId, DateTime? startedAt, DateTime? pausedAt) {
    var changed = false;
    for (var i = 0; i < _events.length; i++) {
      if (_events[i].id != roomId) continue;
      _events[i] = _events[i].copyWith(
        currentTrackStartedAt: startedAt,
        playbackPausedAt: pausedAt,
      );
      if (_selectedEvent?.id == roomId) _selectedEvent = _events[i];
      changed = true;
    }
    if (changed) notifyListeners();
  }

  Future<void> pausePlayback(String roomId) async {
    final updated = await _repository.pauseRoomPlayback(roomId);
    applyPlayback(
      roomId,
      updated.currentTrackStartedAt,
      updated.playbackPausedAt,
    );
  }

  Future<void> resumePlayback(String roomId) async {
    final updated = await _repository.resumeRoomPlayback(roomId);
    applyPlayback(
      roomId,
      updated.currentTrackStartedAt,
      updated.playbackPausedAt,
    );
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
}
