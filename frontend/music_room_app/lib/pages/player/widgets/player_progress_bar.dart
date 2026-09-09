import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/providers/player_provider.dart';

String _formatDuration(Duration d) {
  final minutes = d.inMinutes;
  final seconds = d.inSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

/// A dedicated 30-second progress bar for track previews with smooth
/// left-to-right progression, neumorphic styling, and touch/drag scrubbing.
class PlayerProgressBar extends StatelessWidget {
  static const Duration previewDuration = Duration(seconds: 30);

  const PlayerProgressBar({super.key});

  void _handleSeek(
    BuildContext context,
    double localDx,
    double totalWidth,
    PlayerProvider player,
  ) {
    if (totalWidth <= 0) return;
    final ratio = (localDx / totalWidth).clamp(0.0, 1.0);
    final targetMs = (ratio * previewDuration.inMilliseconds).round();
    player.seek(Duration(milliseconds: targetMs));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final player = context.watch<PlayerProvider>();

    final totalMs = previewDuration.inMilliseconds;
    final positionMs = player.position.inMilliseconds.clamp(0, totalMs);
    final progress = (positionMs / totalMs).clamp(0.0, 1.0);
    final elapsed = Duration(milliseconds: positionMs);
    final remaining = Duration(milliseconds: totalMs - positionMs);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ProgressBarSlider(
          progress: progress,
          onSeek: (dx, width) => _handleSeek(context, dx, width, player),
        ),
        const SizedBox(height: AppDimens.xs),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.xs),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(elapsed),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.disabledColor,
                  fontWeight: AppTypography.bold,
                ),
              ),
              Text(
                '-${_formatDuration(remaining)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.disabledColor,
                  fontWeight: AppTypography.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProgressBarSlider extends StatelessWidget {
  final double progress;
  final void Function(double dx, double width) onSeek;

  const _ProgressBarSlider({required this.progress, required this.onSeek});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppDesignTokens>();

    return Builder(
      builder: (barContext) {
        return GestureDetector(
          key: const Key('player_progress_bar_slider'),
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) {
            final box = barContext.findRenderObject() as RenderBox?;
            final width = box?.size.width ?? 0;
            onSeek(details.localPosition.dx, width);
          },
          onHorizontalDragUpdate: (details) {
            final box = barContext.findRenderObject() as RenderBox?;
            final width = box?.size.width ?? 0;
            onSeek(details.localPosition.dx, width);
          },
          child: Container(
            height: 12,
            width: double.infinity,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(AppDimens.radiusPill),
              boxShadow: tokens?.neumorphicPressedShadow,
            ),
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 250),
              curve: Curves.linear,
              tween: Tween<double>(begin: 0.0, end: progress),
              builder: (context, animatedValue, child) {
                return FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: animatedValue.clamp(0.0, 1.0),
                  child: child,
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
