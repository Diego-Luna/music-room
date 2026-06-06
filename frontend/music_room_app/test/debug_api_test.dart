// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';

void main() {
  test('Debug API and Room Fetching', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000'));

    try {
      // 1. Login
      print('--- STEP 1: LOGIN ---');
      final loginRes = await dio.post(
        '/auth/login',
        data: {'email': 'diego@42.fr', 'password': 'Diego1@#'},
      );

      final accessToken = loginRes.data['accessToken'];
      print('Logged in successfully. AccessToken: $accessToken');

      dio.options.headers['Authorization'] = 'Bearer $accessToken';

      // 2. Fetch Rooms
      print('--- STEP 2: FETCH ROOMS ---');
      final roomsRes = await dio.get('/rooms');
      print('Rooms response: ${roomsRes.data}');

      final rooms = roomsRes.data as List;
      for (var r in rooms) {
        final roomId = r['id'];
        final roomName = r['name'];
        final roomKind = r['kind'];
        print('Found Room: $roomName ($roomId), Kind: $roomKind');

        if (roomKind == 'VOTE') {
          try {
            final tracksRes = await dio.get('/rooms/$roomId/tracks');
            print('Tracks for $roomName: ${tracksRes.data}');
          } catch (e) {
            print('Error getting tracks for $roomName: $e');
          }
        }
      }
    } catch (e) {
      print('Failed debug test: $e');
      if (e is DioException) {
        print('DioException response: ${e.response?.data}');
      }
    }
  });
}
