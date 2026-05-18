import 'package:flutter/material.dart';
import 'package:music_room_app/core/repositories/mock_api_repository.dart';
import 'package:music_room_app/models/event.dart';
import 'package:music_room_app/models/track.dart';

class EventsProvider extends ChangeNotifier {
	final MockApiRepository _repository;
	List<Event> _events = [];
	bool _isLoading = false;
	String? _error;

	EventsProvider({required MockApiRepository repository}) : _repository = repository;

	List<Event> get events => _events;
	bool get isLoading => _isLoading;
	String? get error => _error;

	Future<void> fetchEvents() async {
		_isLoading = true;
		_error = null;
		notifyListeners();
		try {
			_events = await _repository.getEvents();
		} catch (e) {
			_error = e.toString();
		} finally {
			_isLoading = false;
			notifyListeners();
		}
	}

	Future<void> voteForTrack(String eventId, String trackId, bool hasVoted) async {
		try {
			await _repository.voteForTrack(eventId, trackId, hasVoted);
			_events = await _repository.getEvents();
			notifyListeners();
		} catch (e) {
			_error = e.toString();
			notifyListeners();
		}
	}

	Future<void> suggestTrack(String eventId, Track track) async {
		try {
			await _repository.suggestTrack(eventId, track);
			_events = await _repository.getEvents();
			notifyListeners();
		} catch (e) {
			_error = e.toString();
			notifyListeners();
		}
	}
}
