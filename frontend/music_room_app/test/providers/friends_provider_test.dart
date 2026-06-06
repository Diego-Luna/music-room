import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:music_room_app/core/repositories/friends_repository.dart';
import 'package:music_room_app/models/friendship.dart';
import 'package:music_room_app/models/user.dart';
import 'package:music_room_app/providers/friends_provider.dart';

class MockFriendsRepository extends Mock implements FriendsRepository {}

void main() {
  late FriendsProvider provider;
  late MockFriendsRepository repository;

  setUp(() {
    repository = MockFriendsRepository();
    provider = FriendsProvider(repository: repository);
  });

  group('FriendsProvider Tests', () {
    test('initial state', () {
      expect(provider.friends, isEmpty);
      expect(provider.incomingRequests, isEmpty);
      expect(provider.outgoingRequests, isEmpty);
      expect(provider.isLoading, false);
      expect(provider.error, isNull);
      expect(provider.currentView, FriendsView.friends);
    });

    test('fetchFriendsData sets lists on success', () async {
      final mockFriends = [FriendDto(friendshipId: 'f-1', friendId: 'user-2')];
      final mockIncoming = [
        FriendshipDto(
          id: 'f-2',
          requesterId: 'user-3',
          addresseeId: 'user-1',
          status: 'PENDING',
          createdAt: DateTime.now(),
        ),
      ];
      final mockOutgoing = [
        FriendshipDto(
          id: 'f-3',
          requesterId: 'user-1',
          addresseeId: 'user-4',
          status: 'PENDING',
          createdAt: DateTime.now(),
        ),
      ];

      when(() => repository.getFriends()).thenAnswer((_) async => mockFriends);
      when(
        () => repository.getIncomingRequests(),
      ).thenAnswer((_) async => mockIncoming);
      when(
        () => repository.getOutgoingRequests(),
      ).thenAnswer((_) async => mockOutgoing);
      when(() => repository.getUserProfile(any())).thenAnswer(
        (inv) async => User(
          id: inv.positionalArguments[0] as String,
          email: 'test@42.fr',
          displayName: 'User',
        ),
      );

      await provider.fetchFriendsData();

      expect(provider.friends, equals(mockFriends));
      expect(provider.incomingRequests, equals(mockIncoming));
      expect(provider.outgoingRequests, equals(mockOutgoing));
      expect(provider.isLoading, false);
    });

    test('sendRequest triggers API and fetches profile', () async {
      final req = FriendshipDto(
        id: 'f-new',
        requesterId: 'user-1',
        addresseeId: 'user-2',
        status: 'PENDING',
        createdAt: DateTime.now(),
      );
      when(
        () => repository.sendFriendRequest(any()),
      ).thenAnswer((_) async => req);
      when(() => repository.getUserProfile(any())).thenAnswer(
        (_) async => User(id: 'user-2', email: 'u2@42.fr', displayName: 'U2'),
      );

      await provider.sendRequest('user-2');

      verify(() => repository.sendFriendRequest('user-2')).called(1);
      expect(provider.outgoingRequests.length, 1);
    });
  });
}
