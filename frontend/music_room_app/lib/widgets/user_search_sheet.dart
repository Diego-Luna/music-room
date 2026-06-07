import 'dart:async';
import 'package:flutter/material.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/core/routing/app_router.dart';
import 'package:music_room_app/core/repositories/friends_repository.dart';
import 'package:music_room_app/core/utils/api_error_handler.dart';
import 'package:music_room_app/models/user.dart';

// * Reusable user picker backed by GET /users/search. Searches by display name
// * (empty query = browse all visible users) with offset pagination loaded on
// * scroll. Used to add friends and to pick a delegate, replacing raw-UUID
// * entry. Calls [onSelected] with the chosen user and closes.
class UserSearchSheet extends StatefulWidget {
  final String title;
  final void Function(User user) onSelected;

  const UserSearchSheet({
    super.key,
    required this.title,
    required this.onSelected,
  });

  @override
  State<UserSearchSheet> createState() => _UserSearchSheetState();
}

class _UserSearchSheetState extends State<UserSearchSheet> {
  static const int _limit = 20;
  final FriendsRepository _repo = friendsRepository;
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  Timer? _debounce;

  String _query = '';
  List<User> _items = [];
  int _total = 0;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;

  bool get _hasMore => _items.length < _total;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _load(reset: false);
    }
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _query = value;
      _load(reset: true);
    });
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _items = [];
        _total = 0;
      });
    } else {
      if (_loadingMore || _loading || !_hasMore) return;
      setState(() => _loadingMore = true);
    }

    final queryAtCall = _query.trim();
    try {
      final page = await _repo.searchUsers(
        query: queryAtCall.isEmpty ? null : queryAtCall,
        limit: _limit,
        offset: reset ? 0 : _items.length,
      );
      if (!mounted || queryAtCall != _query.trim()) return; // stale response
      setState(() {
        _total = page.total;
        _items = reset ? page.items : [..._items, ...page.items];
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = ApiErrorHandler.getMessage(e));
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  void _select(User user) {
    widget.onSelected(user);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppDimens.radiusLarge),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(
            AppDimens.lg,
            AppDimens.md,
            AppDimens.lg,
            0,
          ),
          child: Column(
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppDimens.md),
                  decoration: BoxDecoration(
                    color: theme.disabledColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: AppTypography.bold,
                  ),
                ),
              ),
              const SizedBox(height: AppDimens.md),
              TextField(
                controller: _searchController,
                onChanged: _onQueryChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search by name…',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: AppDimens.md),
              Expanded(child: _buildBody(theme)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    if (_items.isEmpty) {
      return const Center(child: Text('No users found.'));
    }
    return ListView.builder(
      controller: _scrollController,
      itemCount: _items.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i >= _items.length) {
          return const Padding(
            padding: EdgeInsets.all(AppDimens.md),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final user = _items[i];
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: user.avatarUrl != null
                ? NetworkImage(user.avatarUrl!)
                : null,
            child: user.avatarUrl == null ? const Icon(Icons.person) : null,
          ),
          title: Text(user.displayName),
          subtitle: Text(_visibilityLabel(user.visibility)),
          trailing: const Icon(Icons.add_circle_outline),
          onTap: () => _select(user),
        );
      },
    );
  }

  String _visibilityLabel(UserVisibility v) {
    switch (v) {
      case UserVisibility.public:
        return 'Public';
      case UserVisibility.friendsOnly:
        return 'Friends only';
      case UserVisibility.private:
        return 'Private';
    }
  }
}
