import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/core/animations/neumorphic_interactive_container.dart';
import 'package:music_room_app/models/music_control_delegation.dart';
import 'package:music_room_app/providers/player_provider.dart';
import 'package:music_room_app/widgets/interactive_3d/floating_music_entities.dart';

// * Remote control surface for a DELEGATED device (V.5 Music Control
// * Delegation). The current user is the delegate: every transport action is
// * relayed by the backend (POST/PUT /delegations/:id/playback/...) to the
// * owner's player, which mirrors it via the `playback:command` socket event.
class RemoteControlPage extends StatefulWidget {
  final MusicControlDelegation delegation;

  const RemoteControlPage({super.key, required this.delegation});

  @override
  State<RemoteControlPage> createState() => _RemoteControlPageState();
}

class _RemoteControlPageState extends State<RemoteControlPage> {
  // * Optimistic local view of the remote player state. We have no reliable
  //   read-back of the owner's player, so we just flip the icon on each action.
  bool _isPlaying = false;
  double _volume = 50;

  late final PlayerProvider _player;

  @override
  void initState() {
    super.initState();
    // Grab the provider once and target this delegation for every command.
    _player = context.read<PlayerProvider>();
    _player.setActiveDelegation(widget.delegation.id);
  }

  @override
  void dispose() {
    // Stop relaying once we leave, so the local player is back to itself.
    _player.clearActiveDelegation();
    super.dispose();
  }

  void _surfaceError(PlayerProvider player) {
    final error = player.error;
    if (error == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.redAccent),
      );
      player.clearError();
    });
  }

  Future<void> _togglePlayPause(PlayerProvider player) async {
    if (_isPlaying) {
      await player.sendPauseCommand();
    } else {
      await player.sendPlayCommand();
    }
    if (!mounted) return;
    setState(() => _isPlaying = !_isPlaying);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final player = context.watch<PlayerProvider>();
    _surfaceError(player);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        toolbarHeight: 76.0,
        title: const Text('Remote Control'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          const Opacity(opacity: 0.3, child: BackgroundFloaters()),
          ListView(
            padding: const EdgeInsets.all(AppDimens.xl),
            children: [
              _buildTargetCard(theme),
              const SizedBox(height: AppDimens.xxl),
              _buildTransportControls(theme, player),
              const SizedBox(height: AppDimens.xxl),
              _buildVolume(theme, player),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTargetCard(ThemeData theme) {
    return NeumorphicInteractiveContainer(
      onTap: () {},
      padding: const EdgeInsets.all(AppDimens.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.settings_remote, color: theme.colorScheme.secondary),
              const SizedBox(width: AppDimens.md),
              Expanded(
                child: Text(
                  'Controlling a delegated device',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: AppTypography.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.sm),
          SelectableText(
            'Owner: ${widget.delegation.ownerId}',
            style: theme.textTheme.bodySmall ?? const TextStyle(),
          ),
          SelectableText(
            'Device ID: ${widget.delegation.deviceId}',
            style: theme.textTheme.bodySmall ?? const TextStyle(),
          ),
        ],
      ),
    );
  }

  Widget _buildTransportControls(ThemeData theme, PlayerProvider player) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _circleButton(
          theme,
          icon: Icons.skip_previous_rounded,
          size: 36,
          onTap: () => player.sendPreviousCommand(),
        ),
        _circleButton(
          theme,
          icon: _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          size: 48,
          padding: AppDimens.lg,
          onTap: () => _togglePlayPause(player),
        ),
        _circleButton(
          theme,
          icon: Icons.skip_next_rounded,
          size: 36,
          onTap: () => player.sendNextCommand(),
        ),
      ],
    );
  }

  Widget _circleButton(
    ThemeData theme, {
    required IconData icon,
    required double size,
    required VoidCallback onTap,
    double padding = AppDimens.md,
  }) {
    return NeumorphicInteractiveContainer(
      onTap: onTap,
      margin: const EdgeInsets.symmetric(horizontal: AppDimens.xs),
      padding: EdgeInsets.all(padding),
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: Icon(icon, size: size, color: theme.colorScheme.primary),
    );
  }

  Widget _buildVolume(ThemeData theme, PlayerProvider player) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.volume_up_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: AppDimens.sm),
            Text(
              'Volume: ${_volume.round()}%',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: AppTypography.bold,
              ),
            ),
          ],
        ),
        Slider(
          value: _volume,
          min: 0,
          max: 100,
          divisions: 20,
          label: '${_volume.round()}%',
          onChanged: (v) => setState(() => _volume = v),
          onChangeEnd: (v) => player.sendVolumeCommand(v.round()),
        ),
      ],
    );
  }
}
