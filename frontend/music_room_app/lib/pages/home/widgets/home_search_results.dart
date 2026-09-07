import 'package:flutter/material.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/models/track.dart';

/// Renders search results for tracks on the home screen with instant playback
class HomeSearchResults extends StatelessWidget {
  final String query;
  final List<Track> tracks;
  final bool isLoading;
  final String? errorMessage;
  final void Function(Track track, int index) onTrackTap;

  const HomeSearchResults({
    super.key,
    required this.query,
    required this.tracks,
    required this.isLoading,
    this.errorMessage,
    required this.onTrackTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppDimens.xxl * 2),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (errorMessage != null) {
      return _buildErrorState(theme);
    }

    if (tracks.isEmpty) {
      return _buildEmptyState(theme);
    }

    return _buildTrackList(theme);
  }

  Widget _buildErrorState(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.lg,
        vertical: AppDimens.xxl,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: AppDimens.md),
            Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.lg,
        vertical: AppDimens.xxl,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 48, color: theme.disabledColor),
            const SizedBox(height: AppDimens.md),
            Text(
              'No songs found for "$query"',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.disabledColor,
              ),
            ),
            const SizedBox(height: AppDimens.xs),
            Text(
              'Try searching for a different song or artist',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.disabledColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackList(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.lg,
            vertical: AppDimens.sm,
          ),
          child: Text(
            'Results for "$query"',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: AppTypography.bold,
            ),
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.lg,
            vertical: AppDimens.xs,
          ),
          itemCount: tracks.length,
          separatorBuilder: (context, _) =>
              const SizedBox(height: AppDimens.sm),
          itemBuilder: (context, index) {
            final track = tracks[index];
            return _HomeTrackTile(
              track: track,
              onTap: () => onTrackTap(track, index),
            );
          },
        ),
      ],
    );
  }
}

class _HomeTrackTile extends StatelessWidget {
  final Track track;
  final VoidCallback onTap;

  const _HomeTrackTile({required this.track, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.sm),
          child: Row(
            children: [
              _buildArtwork(theme),
              const SizedBox(width: AppDimens.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      track.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: AppTypography.semibold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${track.artist} • ${track.durationString}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.disabledColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.play_circle_fill,
                  size: 32,
                  color: theme.colorScheme.primary,
                ),
                onPressed: onTap,
                tooltip: 'Play track',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArtwork(ThemeData theme) {
    final url = track.artworkUrl;
    final hasArtwork = url != null && url.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
      child: Container(
        width: 48,
        height: 48,
        color: theme.colorScheme.primary.withValues(alpha: 0.1),
        child: hasArtwork
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, stack) =>
                    Icon(Icons.music_note, color: theme.colorScheme.primary),
              )
            : Icon(Icons.music_note, color: theme.colorScheme.primary),
      ),
    );
  }
}
