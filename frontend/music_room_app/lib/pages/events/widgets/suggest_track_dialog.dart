import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/providers/events_provider.dart';
import 'package:music_room_app/models/room.dart';
import 'package:music_room_app/models/track.dart';
import 'package:music_room_app/core/routing/app_router.dart';

class SuggestTrackDialog extends StatefulWidget {
  final Room room;

  const SuggestTrackDialog({super.key, required this.room});

  @override
  State<SuggestTrackDialog> createState() => _SuggestTrackDialogState();
}

class _SuggestTrackDialogState extends State<SuggestTrackDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<Track> _searchResults = [];
  bool _isSearching = false;
  String? _errorMsg;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final eventsProvider = context.read<EventsProvider>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppDimens.lg),
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppDimens.radiusLarge),
            topRight: Radius.circular(AppDimens.radiusLarge),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(theme),
            const SizedBox(height: AppDimens.md),
            _buildSearchField(theme),
            const SizedBox(height: AppDimens.md),
            if (_errorMsg != null) _buildError(theme),
            _buildResultsList(theme, eventsProvider, scaffoldMessenger),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Suggest Song',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildSearchField(ThemeData theme) {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search Spotify tracks...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _isSearching
            ? const SizedBox(
                width: 20,
                height: 20,
                child: Padding(
                  padding: EdgeInsets.all(12.0),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchResults = [];
                    _errorMsg = null;
                  });
                },
              ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        ),
      ),
      onSubmitted: _handleSearch,
    );
  }

  Future<void> _handleSearch(String value) async {
    if (value.trim().isEmpty) return;
    setState(() {
      _isSearching = true;
      _errorMsg = null;
    });
    try {
      final tracks = await roomRepository.searchSpotifyTracks(value.trim());
      setState(() {
        _searchResults = tracks;
        if (tracks.isEmpty) {
          _errorMsg = 'No tracks found or offline.';
        }
      });
    } catch (e) {
      setState(() {
        _errorMsg =
            'Search failed. Make sure you are online and Spotify is connected.';
      });
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  Widget _buildError(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.md),
        child: Text(
          _errorMsg!,
          style: TextStyle(color: theme.colorScheme.error),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildResultsList(
    ThemeData theme,
    EventsProvider eventsProvider,
    ScaffoldMessengerState scaffoldMessenger,
  ) {
    return Expanded(
      child: _isSearching
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final track = _searchResults[index];
                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
                    child:
                        track.artworkUrl != null && track.artworkUrl!.isNotEmpty
                        ? Image.network(
                            track.artworkUrl!,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, stack) =>
                                const Icon(Icons.music_note),
                          )
                        : const Icon(Icons.music_note),
                  ),
                  title: Text(track.title),
                  subtitle: Text(track.artist),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.add_circle_outline,
                      color: Colors.green,
                    ),
                    onPressed: () {
                      final navigator = Navigator.of(context);
                      eventsProvider.suggestTrack(widget.room.id, track).then((
                        _,
                      ) {
                        navigator.pop();
                        scaffoldMessenger.showSnackBar(
                          SnackBar(
                            content: Text('Suggested "${track.title}"!'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      });
                    },
                  ),
                );
              },
            ),
    );
  }
}
