import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/core/routing/app_router.dart';
import 'package:music_room_app/models/room.dart';
import 'package:music_room_app/models/room_member.dart';
import 'package:music_room_app/providers/auth_provider.dart';
import 'package:music_room_app/providers/members_provider.dart';
import 'package:music_room_app/providers/socket_provider.dart';
import 'package:music_room_app/widgets/placeholder_card.dart';
import 'package:music_room_app/widgets/primary_button.dart';

// * Returned via Navigator.pop when the current user leaves the room, so the
// * caller (detail page) can pop back to the room list.
const String membersSheetLeftResult = 'left';

// * V.2.3 member management surface, shared by PlaylistDetail & EventDetail.
// * Owner can promote/demote and remove; admins can remove members; every
// * non-owner can leave. Permissions mirror the backend guard so we don't
// * offer actions that would 403.
class RoomMembersSheet extends StatefulWidget {
  final Room room;

  const RoomMembersSheet({super.key, required this.room});

  @override
  State<RoomMembersSheet> createState() => _RoomMembersSheetState();
}

class _RoomMembersSheetState extends State<RoomMembersSheet> {
  late final MembersProvider _provider;
  late final String? _currentUserId;
  StreamSubscription<String>? _membersChangedSub;

  @override
  void initState() {
    super.initState();
    _currentUserId = context.read<AuthProvider>().user?.id;
    _provider = MembersProvider(
      roomRepository: roomRepository,
      friendsRepository: friendsRepository,
    );
    _provider.load(widget.room.id);
    // * Live-refresh when another client changes this room's membership
    //   (member removed or role changed), scoped to our room only.
    _membersChangedSub = context
        .read<SocketProvider>()
        .roomMembersChanged
        .listen((roomId) {
          if (roomId == widget.room.id && mounted) {
            _provider.load(widget.room.id);
          }
        });
  }

  @override
  void dispose() {
    _membersChangedSub?.cancel();
    _provider.dispose();
    super.dispose();
  }

  bool get _amOwner => _currentUserId == widget.room.ownerId;

  RoomMemberRole? _myRole() {
    if (_amOwner) return RoomMemberRole.owner;
    final mine = _provider.members
        .where((m) => m.userId == _currentUserId)
        .toList();
    return mine.isEmpty ? null : mine.first.role;
  }

  // Owner may act on anyone but the owner; admins may remove plain members.
  bool _canRemove(RoomMember target) {
    if (target.role == RoomMemberRole.owner) return false;
    if (target.userId == _currentUserId) return false;
    if (_amOwner) return true;
    return _myRole() == RoomMemberRole.admin &&
        target.role == RoomMemberRole.member;
  }

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.redAccent : null,
      ),
    );
  }

  Future<void> _changeRole(RoomMember m, RoomMemberRole role) async {
    try {
      await _provider.changeRole(widget.room.id, m.userId, role);
      _snack('Role updated to ${roomMemberRoleLabel(role)}');
    } catch (_) {
      _snack(_provider.error ?? 'Could not change role', error: true);
    }
  }

  Future<void> _remove(RoomMember m) async {
    try {
      await _provider.removeMember(widget.room.id, m.userId);
      _snack('Member removed');
    } catch (_) {
      _snack(_provider.error ?? 'Could not remove member', error: true);
    }
  }

  Future<void> _join() async {
    try {
      await _provider.join(widget.room.id);
      _snack('You joined "${widget.room.name}"');
    } catch (_) {
      _snack(_provider.error ?? 'Could not join room', error: true);
    }
  }

  Future<void> _leave() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave room?'),
        content: Text('You will stop being a member of "${widget.room.name}".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _provider.leave(widget.room.id);
      if (!mounted) return;
      Navigator.pop(context, membersSheetLeftResult);
    } catch (_) {
      _snack(_provider.error ?? 'Could not leave room', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppDimens.radiusLarge),
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.lg,
            vertical: AppDimens.md,
          ),
          child: ListenableBuilder(
            listenable: _provider,
            builder: (context, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  Text(
                    'Members',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: AppTypography.bold,
                    ),
                  ),
                  const SizedBox(height: AppDimens.md),
                  Expanded(child: _buildBody(theme, scrollController)),
                  ..._buildFooter(theme),
                ],
              );
            },
          ),
        );
      },
    );
  }

  // Membership CTA: don't decide while the list is still loading (myRole would
  // wrongly read as null). Owner is always a member → never Join/Leave.
  List<Widget> _buildFooter(ThemeData theme) {
    if (_provider.isLoading) return const [];
    final role = _myRole();

    if (role == null) {
      if (!widget.room.isPublic) return const [];
      return [
        const SizedBox(height: AppDimens.sm),
        PrimaryButton(
          label: 'Join room',
          leading: Icon(
            Icons.group_add_rounded,
            color: theme.colorScheme.primary,
            size: AppDimens.iconMedium,
          ),
          onPressed: _join,
        ),
      ];
    }

    if (role != RoomMemberRole.owner) {
      return [
        const SizedBox(height: AppDimens.sm),
        PrimaryButton(
          label: 'Leave room',
          leading: const Icon(
            Icons.logout_rounded,
            color: Colors.redAccent,
            size: AppDimens.iconMedium,
          ),
          onPressed: _leave,
        ),
      ];
    }

    return const [];
  }

  Widget _buildBody(ThemeData theme, ScrollController controller) {
    if (_provider.isLoading && _provider.members.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_provider.members.isEmpty) {
      return Center(
        child: Text(_provider.error ?? 'No members found.'),
      );
    }
    return ListView.builder(
      controller: controller,
      itemCount: _provider.members.length,
      itemBuilder: (context, i) {
        final member = _provider.members[i];
        final user = _provider.userCache[member.userId];
        final name = user?.displayName ?? member.userId;
        return Padding(
          padding: const EdgeInsets.only(bottom: AppDimens.sm),
          child: PlaceholderCard(
            title: name,
            subtitle: roomMemberRoleLabel(member.role),
            leading: CircleAvatar(
              backgroundImage: user?.avatarUrl != null
                  ? NetworkImage(user!.avatarUrl!)
                  : null,
              child: user?.avatarUrl == null ? const Icon(Icons.person) : null,
            ),
            trailing: _buildTrailing(theme, member),
          ),
        );
      },
    );
  }

  Widget? _buildTrailing(ThemeData theme, RoomMember member) {
    final actions = <PopupMenuEntry<_MemberAction>>[];

    // Role changes are owner-only and never target the owner.
    if (_amOwner && member.role != RoomMemberRole.owner) {
      if (member.role == RoomMemberRole.member) {
        actions.add(
          const PopupMenuItem(
            value: _MemberAction.promote,
            child: Text('Promote to Admin'),
          ),
        );
      } else if (member.role == RoomMemberRole.admin) {
        actions.add(
          const PopupMenuItem(
            value: _MemberAction.demote,
            child: Text('Demote to Member'),
          ),
        );
      }
    }
    if (_canRemove(member)) {
      actions.add(
        const PopupMenuItem(
          value: _MemberAction.remove,
          child: Text('Remove', style: TextStyle(color: Colors.redAccent)),
        ),
      );
    }

    if (actions.isEmpty) return null;

    return PopupMenuButton<_MemberAction>(
      icon: const Icon(Icons.more_vert),
      onSelected: (action) {
        switch (action) {
          case _MemberAction.promote:
            _changeRole(member, RoomMemberRole.admin);
          case _MemberAction.demote:
            _changeRole(member, RoomMemberRole.member);
          case _MemberAction.remove:
            _remove(member);
        }
      },
      itemBuilder: (_) => actions,
    );
  }
}

enum _MemberAction { promote, demote, remove }
