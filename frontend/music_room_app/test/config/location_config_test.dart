import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:music_room_app/config/location_config.dart';

void main() {
  setUp(() async {
    LocationConfig.resetForTest();
    Hive.init('./.dart_tool/test_hive_location_config');
    if (!Hive.isBoxOpen('app_settings')) {
      await Hive.openBox('app_settings');
    }
    await Hive.box('app_settings').clear();
  });

  tearDown(() async {
    LocationConfig.resetForTest();
    if (Hive.isBoxOpen('app_settings')) {
      await Hive.box('app_settings').clear();
    }
  });

  test('resolve returns null when no override', () async {
    expect(await LocationConfig.resolve(), isNull);
    expect(LocationConfig.hasOverride, isFalse);
  });

  test('setOverride persists and resolve returns it', () async {
    await LocationConfig.setOverride(lat: 48.8566, lng: 2.3522);
    final point = await LocationConfig.resolve();
    expect(point?.lat, 48.8566);
    expect(point?.lng, 2.3522);
    expect(LocationConfig.hasOverride, isTrue);

    LocationConfig.resetForTest();
    await LocationConfig.load();
    expect(LocationConfig.current?.lat, 48.8566);
    expect(LocationConfig.current?.lng, 2.3522);
  });

  test('setOverride rejects invalid latitude', () async {
    expect(
      () => LocationConfig.setOverride(lat: 91, lng: 0),
      throwsA(isA<FormatException>()),
    );
  });

  test('clearOverride removes persisted values', () async {
    await LocationConfig.setOverride(lat: 1, lng: 2);
    await LocationConfig.clearOverride();
    expect(LocationConfig.current, isNull);
    expect(Hive.box('app_settings').get('vote_location_lat'), isNull);
  });

  test('listenable notifies when the override changes', () async {
    var ticks = 0;
    void tick() => ticks++;
    LocationConfig.listenable.addListener(tick);
    addTearDown(() => LocationConfig.listenable.removeListener(tick));

    await LocationConfig.setOverride(lat: 48.8, lng: 2.3);
    expect(ticks, 1);
    await LocationConfig.setOverride(lat: 48.8, lng: 2.3);
    expect(ticks, 1);
    await LocationConfig.clearOverride();
    expect(ticks, 2);
  });
}
