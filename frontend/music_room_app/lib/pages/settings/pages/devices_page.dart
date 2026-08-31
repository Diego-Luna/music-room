import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:music_room_app/core/repositories/device_repository.dart';
import 'package:music_room_app/core/routing/app_router.dart';
import 'package:music_room_app/core/routing/route_names.dart';
import 'package:music_room_app/models/account_device.dart';
import 'package:music_room_app/models/music_control_delegation.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/core/animations/staggered_list.dart';
import 'package:music_room_app/core/animations/neumorphic_interactive_container.dart';
import 'package:music_room_app/widgets/primary_button.dart';
import 'package:music_room_app/widgets/user_search_sheet.dart';
import 'package:music_room_app/widgets/interactive_3d/floating_music_entities.dart';

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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _deviceRepo.getDevices(),
        _deviceRepo.getControlledDevices(),
      ]);

      setState(() {
        _myDevices = results[0] as List<AccountDevice>;
        _controlledDevices = results[1] as List<MusicControlDelegation>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load devices: $e';
        _isLoading = false;
      });
    }
  }

  void _delegateControl(String deviceId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UserSearchSheet(
        title: 'Delegate Control To',
        onSelected: (user) async {
          try {
            await _deviceRepo.delegateControl(deviceId, user.id);
            _showResult(true, 'Delegated to ${user.displayName}');
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
                    device.userAgent ?? 'Unknown Device',
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
                'Last seen: ${device.lastSeenAt!.toLocal()}',
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
              'Granted At: ${delegation.grantedAt.toLocal()}',
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
