import 'package:flutter/material.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/core/routing/app_router.dart';
import 'package:music_room_app/models/track.dart';

/// Action run when the user picks a result (add to playlist, suggest, ...).
/// Awaited before the sheet closes so failures can keep it open.
typedef TrackAction = Future<void> Function(Track track);

/// Reusable bottom-sheet that searches tracks via [roomRepository.searchTracks]
/// (Deezer-backed) and lets the user pick one. Shared by the playlist
/// "add track" flow and the event "suggest track" flow so the search UI lives
/// in a single place.
class TrackSearchSheet extends StatefulWidget {
  final String title;
  final TrackAction onSelected;

  /// Builds the snackbar message shown after a successful pick.
  final String Function(Track track) confirmationBuilder;

  const TrackSearchSheet({
    super.key,
    required this.title,
    required this.onSelected,
    required this.confirmationBuilder,
  });

  @override
  State<TrackSearchSheet> createState() => _TrackSearchSheetState();
}

class _TrackSearchSheetState extends State<TrackSearchSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<Track> _searchResults = [];
  bool _isSearching = false;
  String? _errorMsg;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleSearch(String value) async {
    if (value.trim().isEmpty) return;
    setState(() {
      _isSearching = true;
      _errorMsg = null;
    });
    try {
      final tracks = await roomRepository.searchTracks(value.trim());
      if (!mounted) return;
      setState(() {
        _searchResults = tracks;
        if (tracks.isEmpty) _errorMsg = 'No tracks found.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMsg = 'Search failed. Make sure you are online.');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _select(Track track) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await widget.onSelected(track);
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(widget.confirmationBuilder(track)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
            _buildResultsList(theme),
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
          widget.title,
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
      autofocus: true,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search tracks...',
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

  Widget _buildResultsList(ThemeData theme) {
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
                    onPressed: () => _select(track),
                  ),
                );
              },
            ),
    );
  }
}
