import 'package:hive_ce_flutter/hive_ce_flutter.dart';

class HiveConfig {
  // * Initialize Hive and open essential cache boxes
  static Future<void> initialize() async {
    await Hive.initFlutter();

    // ! Open general cache boxes
    await Hive.openBox<Map>('cached_rooms');
    await Hive.openBox<Map>('pending_actions');
    await Hive.openBox<Map>('cached_friends');
  }
}
