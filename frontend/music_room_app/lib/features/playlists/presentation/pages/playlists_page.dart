import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:music_room_app/core/routing/route_names.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/core/animations/staggered_list.dart';
import 'package:music_room_app/widgets/placeholder_card.dart';

//* Playlists page skeleton with Staggered Animations.
class PlaylistsPage extends StatelessWidget {
  const PlaylistsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<String> fakePlaylists = List.generate(
      8,
      (i) => 'My Playlist ${i + 1}',
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Playlists'), centerTitle: true),
      body: ListView.separated(
        padding: const EdgeInsets.all(AppDimens.lg),
        itemCount: fakePlaylists.length,
        separatorBuilder: (context, _) => const SizedBox(height: AppDimens.sm),
        itemBuilder: (context, index) {
          return StaggeredList(
            index: index,
            child: PlaceholderCard(
              title: fakePlaylists[index],
              subtitle: 'Collaborative Playlist',
              leading: Hero(
                tag: 'playlist_cover_$index',
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
                  ),
                  child: Icon(
                    Icons.playlist_play,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ),
              onTap: () => context.go(
                '$routePlaylists/$routePlaylistDetail',
                extra: {'index': index, 'name': fakePlaylists[index]},
              ),
            ),
          );
        },
      ),
    );
  }
}
