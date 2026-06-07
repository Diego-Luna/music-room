// ignore_for_file: avoid_print

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';

void main() {
  // * NOTE: THIS TEST IS ONLY ON LOCALHOST, SO IT WON'T RUN ON GITHUB ACTIONS
  // test('Debug Delegation API Integration', () async {
  //   final baseUrl =
  //       Platform.environment['BACKEND_API_URL'] ?? 'http://localhost:3000';
  //   final dio = Dio(
  //     BaseOptions(
  //       baseUrl: baseUrl,
  //       headers: {
  //         'x-device': 'debug-test-device-id',
  //         'user-agent': 'Dart/3.11 (Test)',
  //       },
  //     ),
  //   );

  //   try {
  //     // 1. Login
  //     print('--- DELEGATION TEST: STEP 1: LOGIN ---');
  //     final loginRes = await dio.post(
  //       '/auth/login',
  //       data: {'email': 'diego@42.fr', 'password': 'Diego1@#'},
  //     );

  //     final accessToken = loginRes.data['accessToken'];
  //     print('Logged in successfully. AccessToken: $accessToken');

  //     dio.options.headers['Authorization'] = 'Bearer $accessToken';

  //     // 2. Fetch Devices
  //     print('--- DELEGATION TEST: STEP 2: GET DEVICES ---');
  //     final devicesRes = await dio.get('/users/me/devices');
  //     print('Devices response: ${devicesRes.data}');

  //     // 3. Fetch Controlled Devices
  //     print('--- DELEGATION TEST: STEP 3: GET CONTROLLED DEVICES ---');
  //     final controlledRes = await dio.get('/users/me/controlled-devices');
  //     print('Controlled Devices response: ${controlledRes.data}');

  //     // 4. Test delegation cycle if we have at least one device
  //     final devices = devicesRes.data as List;
  //     if (devices.isNotEmpty) {
  //       final firstDevice = devices.first;
  //       final deviceId = firstDevice['deviceId'];
  //       print('Testing delegation on deviceId: $deviceId');

  //       try {
  //         print('--- DELEGATION TEST: STEP 4: PUT DELEGATE ---');
  //         final delegateRes = await dio.put(
  //           '/users/me/devices/$deviceId/delegate',
  //           data: {'delegateUserId': '00000000-0000-0000-0000-000000000000'},
  //         );
  //         print('Delegate PUT response: ${delegateRes.data}');
  //       } catch (e) {
  //         if (e is DioException) {
  //           print(
  //             'Delegate PUT Status: ${e.response?.statusCode}, Response: ${e.response?.data}',
  //           );
  //           expect(
  //             e.response?.statusCode,
  //             anyOf(equals(404), equals(403), equals(400)),
  //           );
  //         } else {
  //           rethrow;
  //         }
  //       }

  //       try {
  //         print('--- DELEGATION TEST: STEP 5: DELETE REVOKE ---');
  //         final revokeRes = await dio.delete(
  //           '/users/me/devices/$deviceId/delegate',
  //         );
  //         print('Revoke DELETE response: ${revokeRes.data}');
  //       } catch (e) {
  //         if (e is DioException) {
  //           print(
  //             'Revoke DELETE Status: ${e.response?.statusCode}, Response: ${e.response?.data}',
  //           );
  //           expect(e.response?.statusCode, anyOf(equals(404), equals(200)));
  //         } else {
  //           rethrow;
  //         }
  //       }
  //     } else {
  //       print(
  //         'No devices registered on this account. Skipped PUT/DELETE test.',
  //       );
  //     }
  //   } catch (e) {
  //     print('Failed debug delegation test: $e');
  //     if (e is DioException) {
  //       print('DioException response: ${e.response?.data}');
  //     }
  //     rethrow;
  //   }
  // });
}
