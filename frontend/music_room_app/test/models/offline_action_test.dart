import 'package:flutter_test/flutter_test.dart';
import 'package:music_room_app/models/offline_action.dart';

void main() {
  test('should serialize and deserialize OfflineAction correctly', () {
    // * Arrange
    final action = OfflineAction(
      id: 'test-uuid-123',
      roomId: 'room-abc',
      type: 'vote',
      payload: {'trackId': 'track-456', 'value': 1},
      createdAt: DateTime(2026, 5, 30),
    );

    // * Act
    final json = action.toJson();
    final result = OfflineAction.fromJson(json);

    // * Assert
    expect(result.id, 'test-uuid-123');
    expect(result.roomId, 'room-abc');
    expect(result.type, 'vote');
    expect(result.payload['trackId'], 'track-456');
    expect(result.payload['value'], 1);
    expect(result.createdAt, DateTime(2026, 5, 30));
  });
}
