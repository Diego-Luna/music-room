import 'package:music_room_app/models/account_device.dart';
import 'package:music_room_app/models/music_control_delegation.dart';

abstract class DeviceRepository {
  Future<List<AccountDevice>> getDevices();
  Future<List<MusicControlDelegation>> getControlledDevices();
  Future<MusicControlDelegation> delegateControl(
    String deviceId,
    String delegateUserId,
  );
  Future<void> revokeControl(String deviceId);
  Future<void> playPlayback(String delegationId, {String? trackId});
  Future<void> pausePlayback(String delegationId);
  Future<void> nextTrack(String delegationId);
  Future<void> previousTrack(String delegationId);
  Future<void> setVolume(String delegationId, int percent);
}
