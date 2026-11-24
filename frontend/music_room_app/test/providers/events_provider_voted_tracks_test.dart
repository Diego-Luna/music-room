import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:music_room_app/core/repositories/room_repository.dart';
import 'package:music_room_app/models/room.dart';
import 'package:music_room_app/models/track.dart';
import 'package:music_room_app/providers/events_provider.dart';

class MockRoomRepository extends Mock implements RoomRepository {}

void main() {
  test('a vote is still there after the list reloads', () async {
    final repo = MockRoomRepository();
    final room = Room(id: 'room1', name: 'Party', ownerId: 'user-1');
    final track = Track(
      id: 'track1',
      providerId: 'p1',
      title: 'Song',
      artist: 'Artist',
      durationMs: 30000,
    );
    when(
      () => repo.getRooms(kind: any(named: 'kind')),
    ).thenAnswer((_) async => [room]);
    when(
      () => repo.getVoteTracks('room1'),
    ).thenAnswer((_) async => [track.copyWith(myVote: 1, score: 1)]);
    when(
      () => repo.voteForTrack(
        any(),
        any(),
        any(),
        lat: any(named: 'lat'),
        lng: any(named: 'lng'),
      ),
    ).thenAnswer((_) async {});

    final provider = EventsProvider(repository: repo);

    await provider.voteForTrack('room1', 'track1', 1);

    expect(provider.events.single.tracks.single.myVote, 1);
    expect(provider.events.single.tracks.single.score, 1);
  });

  test('voting another track moves the vote off the previous one', () async {
    final repo = MockRoomRepository();
    final held = Track(
      id: 'held',
      providerId: 'p1',
      title: 'Held',
      artist: 'Artist',
      durationMs: 30000,
      score: 3,
      myVote: 1,
    );
    final next = Track(
      id: 'next',
      providerId: 'p2',
      title: 'Next',
      artist: 'Artist',
      durationMs: 30000,
      score: 1,
    );
    final room = Room(
      id: 'room1',
      name: 'Party',
      ownerId: 'user-1',
      tracks: [held, next],
    );
    when(
      () => repo.getRooms(kind: any(named: 'kind')),
    ).thenAnswer((_) async => [room]);
    when(
      () => repo.getVoteTracks('room1'),
    ).thenAnswer((_) async => [held, next]);

    final vote = Completer<void>();
    when(
      () => repo.voteForTrack(
        any(),
        any(),
        any(),
        lat: any(named: 'lat'),
        lng: any(named: 'lng'),
      ),
    ).thenAnswer((_) => vote.future);

    final provider = EventsProvider(repository: repo);
    await provider.fetchEvents();

    final pending = provider.voteForTrack('room1', 'next', 1);
    await Future<void>.delayed(Duration.zero);

    final tracks = provider.events.single.tracks;
    expect(tracks.firstWhere((track) => track.id == 'held').myVote, 0);
    expect(tracks.firstWhere((track) => track.id == 'held').score, 2);
    expect(tracks.firstWhere((track) => track.id == 'next').myVote, 1);
    expect(tracks.firstWhere((track) => track.id == 'next').score, 2);

    when(
      () => repo.getRooms(kind: any(named: 'kind')),
    ).thenAnswer((_) async => [room]);
    when(() => repo.getVoteTracks('room1')).thenAnswer(
      (_) async => [
        next.copyWith(myVote: 1, score: 2),
        held.copyWith(myVote: 0, score: 2),
      ],
    );
    vote.complete();
    await pending;

    expect(
      provider.events.single.tracks.firstWhere((t) => t.id == 'held').myVote,
      0,
    );
    expect(
      provider.events.single.tracks.firstWhere((t) => t.id == 'next').myVote,
      1,
    );
  });
}
