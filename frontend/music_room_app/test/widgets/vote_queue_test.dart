import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_room_app/models/track.dart';
import 'package:music_room_app/pages/events/widgets/vote_queue.dart';

Track _track(
  String id, {
  int score = 0,
  int myVote = 0,
  String? title,
  String? previewUrl,
}) {
  return Track(
    id: id,
    providerId: id,
    title: title ?? id,
    artist: 'Artist',
    durationMs: 30000,
    score: score,
    myVote: myVote,
    previewUrl: previewUrl,
  );
}

void main() {
  testWidgets('vote is a button, and the playing track starts playback', (
    tester,
  ) async {
    final voted = <String>[];
    final heard = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VoteQueue(
            currentTrackId: 'now',
            isPaused: false,
            canControl: true,
            tracks: [
              _track(
                'now',
                score: 3,
                title: 'Current',
                previewUrl: 'https://example.com/preview.mp3',
              ),
              _track('next', title: 'Waiting'),
              _track('mine', myVote: 1, score: 1, title: 'Mine'),
            ],
            onToggle: (track) => voted.add(track.id),
            onTogglePlayback: (track) => heard.add(track.id),
          ),
        ),
      ),
    );

    expect(find.text('Vote'), findsOneWidget);
    expect(find.text('Voted'), findsOneWidget);
    expect(find.byIcon(Icons.thumb_up), findsNothing);
    expect(find.byIcon(Icons.thumb_down), findsNothing);
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

    await tester.tap(find.text('Current'));
    await tester.tap(find.text('Waiting'));
    await tester.tap(find.text('Mine'));
    await tester.pump();

    expect(heard, ['now']);
    expect(voted, ['next', 'mine']);
  });

  testWidgets('an empty event asks for a suggestion', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VoteQueue(
            currentTrackId: null,
            isPaused: false,
            canControl: false,
            tracks: const [],
            onToggle: _noop,
            onTogglePlayback: _noop,
          ),
        ),
      ),
    );

    expect(find.text('No tracks yet. Suggest one with +.'), findsOneWidget);
  });
}

void _noop(Track track) {}
