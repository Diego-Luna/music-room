import 'package:music_room_app/models/user.dart';

// * One page of user search results (GET /users/search). [items] are identity-
// * only profiles (id, displayName, avatarUrl, visibility); [total] is the full
// * match count so the UI knows whether more pages remain.
class UserSearchPage {
  final List<User> items;
  final int total;
  final int limit;
  final int offset;

  UserSearchPage({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  factory UserSearchPage.fromJson(Map<String, dynamic> json) {
    return UserSearchPage(
      items: (json['items'] as List? ?? [])
          .map((e) => User.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int? ?? 0,
      limit: json['limit'] as int? ?? 0,
      offset: json['offset'] as int? ?? 0,
    );
  }

  // True when more results exist beyond what's been loaded so far.
  bool get hasMore => offset + items.length < total;
}
