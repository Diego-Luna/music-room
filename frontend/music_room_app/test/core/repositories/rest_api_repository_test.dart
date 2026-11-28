import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:music_room_app/config/api_client.dart';
import 'package:music_room_app/core/repositories/rest_api_repository.dart';
import 'package:music_room_app/models/room.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  test('a scheduled vote window is sent as a UTC instant', () async {
    final client = MockApiClient();
    when(() => client.post(any(), data: any(named: 'data'))).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: '/rooms'),
        data: {'id': 'r1', 'name': 'Party', 'ownerId': 'u1', 'kind': 'VOTE'},
      ),
    );
    final startsAt = DateTime(2026, 11, 28, 16);
    final endsAt = DateTime(2026, 11, 28, 18);

    await RestApiRepository(client: client).createRoom(
      name: 'Party',
      kind: RoomKind.vote,
      isPublic: true,
      voteWindow: 'SCHEDULED',
      voteStartsAt: startsAt,
      voteEndsAt: endsAt,
    );

    final body =
        verify(
              () => client.post(any(), data: captureAny(named: 'data')),
            ).captured.single
            as Map<String, dynamic>;
    final sentStart = body['voteStartsAt'] as String;
    final sentEnd = body['voteEndsAt'] as String;
    expect(sentStart, endsWith('Z'));
    expect(sentEnd, endsWith('Z'));
    expect(DateTime.parse(sentStart).isAtSameMomentAs(startsAt), isTrue);
    expect(DateTime.parse(sentEnd).isAtSameMomentAs(endsAt), isTrue);
  });
}
