import 'package:music_room_app/models/account_device.dart';
import 'package:music_room_app/models/music_control_delegation.dart';
import 'device_repository.dart';

class MockDeviceRepository implements DeviceRepository {
  @override
  Future<List<AccountDevice>> getDevices() async => [];

  @override
  Future<List<MusicControlDelegation>> getControlledDevices() async => [];

  @override
  Future<MusicControlDelegation> delegateControl(
    String deviceId,
    String delegateUserId,
  ) async {
    return MusicControlDelegation(
      id: 'mock',
      ownerId: 'mock',
      deviceId: deviceId,
      delegateUserId: delegateUserId,
      grantedAt: DateTime.now(),
    );
  }

  @override
  Future<void> revokeControl(String deviceId) async {}

  @override
  Future<void> playPlayback(
    String delegationId, {
    List<String>? uris,
    String? contextUri,
  }) async {}

  @override
  Future<void> pausePlayback(String delegationId) async {}

  @override
  Future<void> nextTrack(String delegationId) async {}

  @override
  Future<void> previousTrack(String delegationId) async {}

  @override
  Future<void> setVolume(String delegationId, int percent) async {}
}
