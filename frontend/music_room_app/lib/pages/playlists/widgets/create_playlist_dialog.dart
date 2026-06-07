import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/core/routing/route_names.dart';
import 'package:music_room_app/core/utils/api_error_handler.dart';
import 'package:music_room_app/providers/playlists_provider.dart';
import 'package:music_room_app/widgets/primary_button.dart';
import 'package:music_room_app/widgets/neumorphic_form_field.dart';

// * Bottom sheet to create a collaborative PLAYLIST room with its visibility
// * (public/private) and edit license (everyone / invited-only).
class CreatePlaylistDialog extends StatefulWidget {
  const CreatePlaylistDialog({super.key});

  @override
  State<CreatePlaylistDialog> createState() => _CreatePlaylistDialogState();
}

class _CreatePlaylistDialogState extends State<CreatePlaylistDialog> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();

  bool _isPublic = true;
  String _editAccess = 'EVERYONE';
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final router = GoRouter.of(context);
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please enter a playlist name')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await context.read<PlaylistsProvider>().createPlaylist(
        name: name,
        description: _descController.text.trim().isEmpty
            ? null
            : _descController.text.trim(),
        isPublic: _isPublic,
        editAccess: _editAccess,
      );
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('Playlist "$name" created!')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);

      // * Premium gate (VI.3): the Playlist Editor is a paid-only feature.
      // * Surface a clear upgrade prompt instead of a raw 403.
      final isPremiumGate =
          e is DioException && e.response?.statusCode == 403;
      if (isPremiumGate) {
        navigator.pop();
        messenger.showSnackBar(
          SnackBar(
            content: const Text(
              'Creating playlists requires a Premium subscription.',
            ),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Upgrade',
              onPressed: () => router.go(routeSubscription),
            ),
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Could not create playlist: ${ApiErrorHandler.getMessage(e)}',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(AppDimens.lg),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppDimens.radiusLarge),
            topRight: Radius.circular(AppDimens.radiusLarge),
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'New Playlist',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.md),
              NeumorphicTextField(
                controller: _nameController,
                label: 'Playlist Name *',
                hint: 'e.g. Road Trip Bangers',
                autofocus: true,
              ),
              const SizedBox(height: AppDimens.md),
              NeumorphicTextField(
                controller: _descController,
                label: 'Description',
                hint: 'e.g. Songs for long drives',
              ),
              const SizedBox(height: AppDimens.md),
              NeumorphicToggleTile(
                title: 'Public Visibility',
                subtitle: 'Public: anyone can find it. Private: invited only.',
                value: _isPublic,
                onChanged: (val) => setState(() => _isPublic = val),
              ),
              const SizedBox(height: AppDimens.md),
              NeumorphicDropdown<String>(
                value: _editAccess,
                label: 'Who can edit?',
                items: const [
                  DropdownMenuItem(value: 'EVERYONE', child: Text('Everyone')),
                  DropdownMenuItem(
                    value: 'INVITED_ONLY',
                    child: Text('Invited only'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _editAccess = val);
                },
              ),
              const SizedBox(height: AppDimens.xl),
              Center(
                child: PrimaryButton(
                  onPressed: _submitting ? null : _handleSubmit,
                  isLoading: _submitting,
                  label: 'Create Playlist',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
