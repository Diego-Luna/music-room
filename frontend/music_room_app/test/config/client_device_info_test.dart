import 'package:flutter_test/flutter_test.dart';
import 'package:music_room_app/config/client_device_info.dart';

void main() {
  tearDown(ClientDeviceInfo.resetCacheForTest);

  test('asHttpHeaders exposes V.6 tags + stable device id', () {
    const info = ClientDeviceInfo(
      platform: 'IOS',
      deviceLabel: 'iPhone 15',
      deviceId: 'dev_abc',
      appVersion: '1.2.3+4',
    );

    expect(info.asHttpHeaders(), {
      'x-platform': 'IOS',
      'x-device': 'iPhone 15',
      'x-device-id': 'dev_abc',
      'x-app-version': '1.2.3+4',
    });
  });

  test('asSocketAuth mirrors tags for web handshake', () {
    const info = ClientDeviceInfo(
      platform: 'WEB',
      deviceLabel: 'Chrome (Google Inc.)',
      deviceId: 'dev_web',
      appVersion: '1.0.0',
    );

    expect(info.asSocketAuth(), {
      'platform': 'WEB',
      'device': 'Chrome (Google Inc.)',
      'deviceId': 'dev_web',
      'appVersion': '1.0.0',
    });
  });
}
