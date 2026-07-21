import 'package:flutter/material.dart';
import 'package:music_room_app/core/services/proximity_service.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/models/room.dart';
import 'package:music_room_app/widgets/primary_button.dart';

/// VI.2 — auto info when the user enters a public event's proximity zone.
class ProximityApproachSheet extends StatelessWidget {
  final NearbyEvent nearby;
  final VoidCallback onOpen;

  const ProximityApproachSheet({
    super.key,
    required this.nearby,
    required this.onOpen,
  });

  Room get room => nearby.room;

  static Future<void> show(
    BuildContext context, {
    required NearbyEvent nearby,
    required VoidCallback onOpen,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ProximityApproachSheet(nearby: nearby, onOpen: onOpen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final distance = nearby.distanceMeters < 1000
        ? '${nearby.distanceMeters.round()} m away'
        : '${(nearby.distanceMeters / 1000).toStringAsFixed(1)} km away';

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppDimens.xl,
          right: AppDimens.xl,
          top: AppDimens.xl,
          bottom: MediaQuery.viewInsetsOf(context).bottom + AppDimens.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.sensors, color: theme.colorScheme.primary),
                const SizedBox(width: AppDimens.sm),
                Text(
                  'Nearby event',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: AppTypography.semibold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.md),
            Text(
              room.name,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: AppTypography.bold,
              ),
            ),
            const SizedBox(height: AppDimens.xs),
            Text(
              distance,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.disabledColor,
              ),
            ),
            const SizedBox(height: AppDimens.lg),
            Text(
              'Music / vibe',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: AppTypography.semibold,
              ),
            ),
            const SizedBox(height: AppDimens.xs),
            Text(ProximityService.musicHint(room), style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppDimens.lg),
            Text(
              'How to access',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: AppTypography.semibold,
              ),
            ),
            const SizedBox(height: AppDimens.xs),
            Text(ProximityService.accessHint(room), style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppDimens.xl),
            PrimaryButton(
              onPressed: () {
                Navigator.of(context).pop();
                onOpen();
              },
              leading: const Icon(Icons.how_to_vote),
              label: 'Open event',
            ),
            const SizedBox(height: AppDimens.sm),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Dismiss'),
            ),
          ],
        ),
      ),
    );
  }
}
