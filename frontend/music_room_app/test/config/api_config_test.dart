import 'package:flutter_test/flutter_test.dart';
import 'package:music_room_app/config/api_config.dart';

void main() {
  // * Verify the default URL resolves to localhost for local development
  test('ApiConfig.baseUrl defaults to localhost', () {
    expect(ApiConfig.baseUrl, equals('http://localhost:3000'));
  });

  test('ApiConfig.wsUrl returns baseUrl', () {
    expect(ApiConfig.wsUrl, equals(ApiConfig.baseUrl));
  });
}
