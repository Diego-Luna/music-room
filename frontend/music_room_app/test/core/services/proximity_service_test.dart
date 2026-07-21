import 'package:flutter_test/flutter_test.dart';
import 'package:music_room_app/config/location_config.dart';
import 'package:music_room_app/core/services/proximity_service.dart';
import 'package:music_room_app/models/room.dart';

void main() {
  group('ProximityService', () {
    test('haversineMeters is ~0 for identical points', () {
      const p = GeoPoint(lat: 48.8566, lng: 2.3522);
      expect(ProximityService.haversineMeters(p, p), lessThan(1));
    });

    test('haversineMeters Paris → Tour Eiffel is a few km', () {
      const a = GeoPoint(lat: 48.8566, lng: 2.3522);
      const b = GeoPoint(lat: 48.8584, lng: 2.2945);
      final d = ProximityService.haversineMeters(a, b);
      expect(d, greaterThan(3000));
      expect(d, lessThan(6000));
    });

    test('findNearbyPublicEvents returns only public geo hits inside radius', () {
      final inside = Room(
        id: 'in',
        name: 'Paris Party',
        ownerId: 'u1',
        isPublic: true,
        description: 'Electronic night',
        voteLocationLat: 48.8566,
        voteLocationLng: 2.3522,
        voteLocationRadiusM: 500,
      );
      final tooFar = Room(
        id: 'far',
        name: 'NYC',
        ownerId: 'u1',
        isPublic: true,
        voteLocationLat: 40.7128,
        voteLocationLng: -74.006,
        voteLocationRadiusM: 500,
      );
      final privateGeo = Room(
        id: 'priv',
        name: 'Private',
        ownerId: 'u1',
        isPublic: false,
        voteLocationLat: 48.8566,
        voteLocationLng: 2.3522,
        voteLocationRadiusM: 500,
      );
      final noGeo = Room(
        id: 'nogeo',
        name: 'Anywhere',
        ownerId: 'u1',
        isPublic: true,
      );

      final hits = ProximityService.findNearbyPublicEvents(
        position: const GeoPoint(lat: 48.8566, lng: 2.3522),
        events: [inside, tooFar, privateGeo, noGeo],
      );

      expect(hits, hasLength(1));
      expect(hits.first.room.id, 'in');
      expect(hits.first.distanceMeters, lessThan(1));
    });

    test('accessHint mentions invite when INVITED_ONLY', () {
      final room = Room(
        id: 'r',
        name: 'Gated',
        ownerId: 'u',
        isPublic: true,
        voteAccess: 'INVITED_ONLY',
      );
      expect(ProximityService.accessHint(room), contains('invited'));
    });

    test('musicHint falls back when description empty', () {
      final room = Room(id: 'r', name: 'Party', ownerId: 'u');
      expect(ProximityService.musicHint(room), contains('vibe'));
    });
  });
}
