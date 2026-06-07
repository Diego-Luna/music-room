import 'package:flutter/material.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/core/routing/app_router.dart';
import 'package:music_room_app/core/utils/api_error_handler.dart';
import 'package:music_room_app/models/user.dart';
import 'package:music_room_app/widgets/primary_button.dart';
import 'package:music_room_app/widgets/interactive_3d/floating_music_entities.dart';

// * Read-only view of another user's public profile (GET /users/:id). The
// * backend already filters fields by the target's visibility and the viewer's
// * friendship, so we just render whatever comes back.
class UserProfilePage extends StatefulWidget {
  final String userId;

  const UserProfilePage({super.key, required this.userId});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  User? _user;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await friendsRepository.getUserProfile(widget.userId);
      if (!mounted) return;
      setState(() => _user = user);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = ApiErrorHandler.getMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        toolbarHeight: 76.0,
        title: const Text('Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          const Opacity(opacity: 0.3, child: BackgroundFloaters()),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_user == null)
            _buildError(theme)
          else
            _buildContent(theme, _user!),
        ],
      ),
    );
  }

  Widget _buildError(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _error ?? 'This profile is not available.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: AppDimens.lg),
          PrimaryButton(label: 'Retry', onPressed: _load),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeData theme, User user) {
    return ListView(
      padding: const EdgeInsets.all(AppDimens.xl),
      children: [
        const SizedBox(height: AppDimens.lg),
        Center(
          child: CircleAvatar(
            radius: 48,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            backgroundImage: user.avatarUrl != null
                ? NetworkImage(user.avatarUrl!)
                : null,
            child: user.avatarUrl == null
                ? Icon(Icons.person, size: 48, color: theme.colorScheme.primary)
                : null,
          ),
        ),
        const SizedBox(height: AppDimens.md),
        Center(
          child: Text(
            user.displayName,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: AppTypography.extraBold,
            ),
          ),
        ),
        const SizedBox(height: AppDimens.xl),
        if (user.musicPreferences.isNotEmpty)
          _section(theme, 'Music Preferences', user.musicPreferences.join(', ')),
        if (user.publicInfo != null && user.publicInfo!.isNotEmpty)
          _section(theme, 'Public Information', user.publicInfo!),
        if (user.friendsInfo != null && user.friendsInfo!.isNotEmpty)
          _section(theme, 'Friends Only Info', user.friendsInfo!),
      ],
    );
  }

  Widget _section(ThemeData theme, String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: AppTypography.bold,
              color: theme.disabledColor,
            ),
          ),
          const SizedBox(height: AppDimens.sm),
          Text(value, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }
}
