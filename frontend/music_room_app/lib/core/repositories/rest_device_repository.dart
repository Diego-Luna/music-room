import 'package:music_room_app/config/api_client.dart';
import 'package:music_room_app/models/account_device.dart';
import 'package:music_room_app/models/music_control_delegation.dart';
import 'device_repository.dart';

// * the metods for use the REST API
class RestDeviceRepository implements DeviceRepository {
  final ApiClient _client;

  RestDeviceRepository({required ApiClient client}) : _client = client;

  @override
  Future<List<AccountDevice>> getDevices() async {
    final response = await _client.get('/users/me/devices');
    return (response.data as List)
        .map((json) => AccountDevice.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<MusicControlDelegation>> getControlledDevices() async {
    final response = await _client.get('/users/me/controlled-devices');
    return (response.data as List)
        .map(
          (json) =>
              MusicControlDelegation.fromJson(json as Map<String, dynamic>),
        )
        .toList();
  }

  @override
  Future<MusicControlDelegation> delegateControl(
    String deviceId,
    String delegateUserId,
  ) async {
    final response = await _client.put(
      '/users/me/devices/$deviceId/delegate',
      data: {'delegateUserId': delegateUserId},
    );
    return MusicControlDelegation.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  @override
  Future<void> revokeControl(String deviceId) async {
    await _client.delete('/users/me/devices/$deviceId/delegate');
  }

  @override
  Future<void> playPlayback(String delegationId, {String? trackId}) async {
    await _client.post(
      '/delegations/$delegationId/playback/play',
      data: {'trackId': ?trackId},
    );
  }

  @override
  Future<void> pausePlayback(String delegationId) async {
    await _client.post('/delegations/$delegationId/playback/pause');
  }

  @override
  Future<void> nextTrack(String delegationId) async {
    await _client.post('/delegations/$delegationId/playback/next');
  }

  @override
  Future<void> previousTrack(String delegationId) async {
    await _client.post('/delegations/$delegationId/playback/previous');
  }

  @override
  Future<void> setVolume(String delegationId, int percent) async {
    await _client.put(
      '/delegations/$delegationId/playback/volume',
      data: {'percent': percent},
    );
  }
}
