import 'dart:math' as math;

import 'package:music_room_app/config/location_config.dart';
import 'package:music_room_app/models/room.dart';

/// A public geo-gated event the user is currently inside (VI.2 proximity).
class NearbyEvent {
  final Room room;
  final double distanceMeters;

  const NearbyEvent({required this.room, required this.distanceMeters});
}

/// Client-side geofence — same haversine idea as the backend vote gate.
/// Desktop demo: set [LocationConfig] to the venue, then scan.
class ProximityService {
  static const double _earthRadiusM = 6_371_000;

  /// Great-circle distance in meters between two WGS84 points.
  static double haversineMeters(GeoPoint a, GeoPoint b) {
    final dLat = _toRad(b.lat - a.lat);
    final dLng = _toRad(b.lng - a.lng);
    final lat1 = _toRad(a.lat);
    final lat2 = _toRad(b.lat);
    final h =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
    return 2 * _earthRadiusM * math.asin(math.sqrt(h));
  }

  /// Whether [position] is inside the room's voting / venue radius.
  static bool isInsideZone(Room room, GeoPoint position) {
    if (!room.isGeoGated) return false;
    final d = haversineMeters(
      position,
      GeoPoint(lat: room.voteLocationLat!, lng: room.voteLocationLng!),
    );
    return d <= room.voteLocationRadiusM!;
  }

  /// Public events whose venue zone contains [position], nearest first.
  static List<NearbyEvent> findNearbyPublicEvents({
    required GeoPoint position,
    required List<Room> events,
  }) {
    final hits = <NearbyEvent>[];
    for (final room in events) {
      if (!room.isPublic || !room.isGeoGated) continue;
      final d = haversineMeters(
        position,
        GeoPoint(lat: room.voteLocationLat!, lng: room.voteLocationLng!),
      );
      if (d <= room.voteLocationRadiusM!) {
        hits.add(NearbyEvent(room: room, distanceMeters: d));
      }
    }
    hits.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return hits;
  }

  /// Short “how to access” copy for the approach sheet.
  static String accessHint(Room room) {
    if (!room.isPublic) {
      return 'Private event — you need an invitation to find and join it.';
    }
    if (room.voteAccess == 'INVITED_ONLY') {
      return 'Public listing — only invited guests can vote. Ask the host for an invite.';
    }
    return 'Public event — open it from Events and join to suggest or vote.';
  }

  /// Music / vibe blurb (description), or a fallback.
  static String musicHint(Room room) {
    final desc = room.description?.trim();
    if (desc != null && desc.isNotEmpty) return desc;
    return 'Live vote session — check the track queue for the vibe.';
  }

  static double _toRad(double deg) => deg * math.pi / 180;
}
