import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:music_room_app/core/repositories/device_repository.dart';
import 'package:music_room_app/core/routing/app_router.dart';
import 'package:music_room_app/core/routing/route_names.dart';
import 'package:music_room_app/models/account_device.dart';
import 'package:music_room_app/models/music_control_delegation.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/core/animations/staggered_list.dart';
import 'package:music_room_app/core/animations/neumorphic_interactive_container.dart';
import 'package:music_room_app/widgets/primary_button.dart';
import 'package:music_room_app/widgets/interactive_3d/floating_music_entities.dart';
import 'package:music_room_app/providers/friends_provider.dart';
import 'package:music_room_app/providers/player_provider.dart';

class DevicesPage extends StatefulWidget {
  const DevicesPage({super.key});

  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
  final DeviceRepository _deviceRepo = deviceRepository;
  bool _isLoading = true;
  String? _error;

  List<AccountDevice> _myDevices = [];
  List<MusicControlDelegation> _controlledDevices = [];
  PlayerProvider? _player;

  @override
  void initState() {
    super.initState();
    _player = playerProvider;
    _player!.delegationRevision.addListener(_onDelegationRevoked);
    _loadData();
  }

  void _onDelegationRevoked() {
    _loadData();
  }

  @override
  void dispose() {
    _player?.delegationRevision.removeListener(_onDelegationRevoked);
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _deviceRepo.getDevices(),
        _deviceRepo.getControlledDevices(),
      ]);

      if (!mounted) return;
      setState(() {
        _myDevices = results[0] as List<AccountDevice>;
        _controlledDevices = results[1] as List<MusicControlDelegation>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load devices: $e';
        _isLoading = false;
      });
    }
  }

  void _delegateControl(String deviceId) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FriendDelegationSheet(
        onSelected: (friendId, displayName) async {
          try {
            await _deviceRepo.delegateControl(deviceId, friendId);
            _showResult(true, 'Delegated to $displayName');
            _loadData();
          } catch (e) {
            _showResult(false, e.toString());
          }
        },
      ),
    );
  }

  Future<void> _revokeControl(String deviceId) async {
    try {
      await _deviceRepo.revokeControl(deviceId);
      _showResult(true, 'Control revoked');
      _loadData();
    } catch (e) {
      _showResult(false, e.toString());
    }
  }

  void _showResult(bool ok, String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: ok ? Colors.green : Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        toolbarHeight: 76.0,
        title: const Text('Devices & Delegation'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
          const SizedBox(width: AppDimens.md),
        ],
      ),
      body: Stack(
        children: [
          const Opacity(opacity: 0.3, child: BackgroundFloaters()),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? _buildError(theme)
              : _buildContent(theme),
        ],
      ),
    );
  }

  Widget _buildError(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(_error!, style: theme.textTheme.bodyLarge),
          const SizedBox(height: AppDimens.lg),
          PrimaryButton(label: 'Retry', onPressed: _loadData),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(AppDimens.xl),
      children: [
        Text(
          'My Devices',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: AppTypography.bold,
          ),
        ),
        const SizedBox(height: AppDimens.md),
        if (_myDevices.isEmpty)
          const Text('No devices found.')
        else
          ..._myDevices.asMap().entries.map((entry) {
            final idx = entry.key;
            final dev = entry.value;
            return StaggeredList(
              index: idx,
              child: _buildDeviceCard(theme, dev),
            );
          }),

        const SizedBox(height: AppDimens.xxl),

        Text(
          'Controlled Devices',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: AppTypography.bold,
          ),
        ),
        const SizedBox(height: AppDimens.md),
        if (_controlledDevices.isEmpty)
          const Text('You do not control any devices.')
        else
          ..._controlledDevices.asMap().entries.map((entry) {
            final idx = entry.key;
            final del = entry.value;
            return StaggeredList(
              index: idx,
              child: _buildControlledDeviceCard(theme, del),
            );
          }),
      ],
    );
  }

  String _formatDeviceName(String? userAgent) {
    if (userAgent == null || userAgent.trim().isEmpty) {
      return 'Unknown Device';
    }
    final ua = userAgent.trim();

    String? browser;
    if (ua.contains('Edg/') || ua.contains('Edge/')) {
      browser = 'Edge';
    } else if (ua.contains('OPR/') || ua.contains('Opera')) {
      browser = 'Opera';
    } else if (ua.contains('Firefox/')) {
      browser = 'Firefox';
    } else if (ua.contains('Chrome/') || ua.contains('CriOS/')) {
      browser = 'Chrome';
    } else if (ua.contains('Safari/')) {
      browser = 'Safari';
    } else if (ua.contains('Dart/')) {
      browser = 'Music Room App';
    }

    String? os;
    if (ua.contains('Android')) {
      os = 'Android';
    } else if (ua.contains('iPhone') ||
        ua.contains('iPad') ||
        ua.contains('iPod')) {
      os = 'iOS';
    } else if (ua.contains('Macintosh') || ua.contains('Mac OS X')) {
      os = 'macOS';
    } else if (ua.contains('Windows')) {
      os = 'Windows';
    } else if (ua.contains('Linux')) {
      os = 'Linux';
    }

    if (browser != null && os != null) return '$browser on $os';
    if (os != null) return '$os Device';
    if (browser != null) return browser;
    return ua.length > 40 ? '${ua.substring(0, 37)}...' : ua;
  }

  String _formatTimestamp(DateTime dt) {
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  Widget _buildDeviceCard(ThemeData theme, AccountDevice device) {
    final hasDelegation = device.delegation != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.md),
      child: NeumorphicInteractiveContainer(
        padding: const EdgeInsets.all(AppDimens.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.devices, color: theme.colorScheme.primary),
                const SizedBox(width: AppDimens.md),
                Expanded(
                  child: Text(
                    _formatDeviceName(device.userAgent),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: AppTypography.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.sm),
            SelectableText(
              'Device ID: ${device.deviceId}',
              style: theme.textTheme.bodySmall ?? const TextStyle(),
            ),
            if (device.lastSeenAt != null)
              Text(
                'Last seen: ${_formatTimestamp(device.lastSeenAt!)}',
                style: theme.textTheme.bodySmall,
              ),

            const SizedBox(height: AppDimens.md),
            if (hasDelegation) ...[
              Container(
                padding: const EdgeInsets.all(AppDimens.sm),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning,
                      color: theme.colorScheme.error,
                      size: 16,
                    ),
                    const SizedBox(width: AppDimens.sm),
                    Expanded(
                      child: SelectableText(
                        'Delegated to: ${device.delegation!.delegateUserId}',
                        style: TextStyle(
                          color: theme.colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimens.sm),
              NeumorphicInteractiveContainer(
                onTap: () => _revokeControl(device.deviceId),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.lg,
                  vertical: AppDimens.md,
                ),
                child: Center(
                  child: Text(
                    'Revoke Control',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: AppTypography.bold,
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              ),
            ] else ...[
              NeumorphicInteractiveContainer(
                onTap: () => _delegateControl(device.deviceId),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.lg,
                  vertical: AppDimens.md,
                ),
                child: Center(
                  child: Text(
                    'Delegate Control',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: AppTypography.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildControlledDeviceCard(
    ThemeData theme,
    MusicControlDelegation delegation,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.md),
      child: NeumorphicInteractiveContainer(
        padding: const EdgeInsets.all(AppDimens.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings_remote, color: theme.colorScheme.secondary),
                const SizedBox(width: AppDimens.md),
                Expanded(
                  child: SelectableText(
                    'Owner: ${delegation.ownerId}',
                    style:
                        theme.textTheme.titleMedium?.copyWith(
                          fontWeight: AppTypography.bold,
                        ) ??
                        const TextStyle(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.sm),
            SelectableText(
              'Device ID: ${delegation.deviceId}',
              style: theme.textTheme.bodySmall ?? const TextStyle(),
            ),
            Text(
              'Granted At: ${_formatTimestamp(delegation.grantedAt)}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppDimens.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                NeumorphicInteractiveContainer(
                  onTap: () => context.push(
                    routeRemotePlayer,
                    extra: {'delegation': delegation},
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.md,
                    vertical: AppDimens.sm,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.play_circle, color: theme.colorScheme.primary),
                      const SizedBox(width: AppDimens.xs),
                      Text(
                        'Control',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: AppTypography.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// * V.2.2: Friends-only picker for delegating device playback control.
class _FriendDelegationSheet extends StatefulWidget {
  final Future<void> Function(String friendId, String displayName) onSelected;

  const _FriendDelegationSheet({required this.onSelected});

  @override
  State<_FriendDelegationSheet> createState() => _FriendDelegationSheetState();
}

class _FriendDelegationSheetState extends State<_FriendDelegationSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final friendsProvider = context.read<FriendsProvider>();
      if (friendsProvider.friends.isEmpty && !friendsProvider.isLoading) {
        friendsProvider.fetchFriendsData();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final friendsProvider = context.watch<FriendsProvider>();

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      padding: const EdgeInsets.all(AppDimens.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppDimens.radiusLarge),
          topRight: Radius.circular(AppDimens.radiusLarge),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Delegate Control To',
                  style: theme.textTheme.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.md),
          Expanded(child: _buildBody(theme, friendsProvider)),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme, FriendsProvider friendsProvider) {
    if (friendsProvider.isLoading && friendsProvider.friends.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (friendsProvider.friends.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
          child: Text(
            'Add friends first to delegate playback control.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: friendsProvider.friends.length,
      itemBuilder: (context, index) {
        final friend = friendsProvider.friends[index];
        final user = friendsProvider.userCache[friend.friendId];
        final displayName = user?.displayName ?? friend.friendId;
        final avatarUrl = user?.avatarUrl;

        return ListTile(
          leading: CircleAvatar(
            backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                ? NetworkImage(avatarUrl)
                : null,
            child: avatarUrl == null || avatarUrl.isEmpty
                ? Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                  )
                : null,
          ),
          title: Text(displayName),
          onTap: () {
            Navigator.of(context).pop();
            widget.onSelected(friend.friendId, displayName);
          },
        );
      },
    );
  }
}
