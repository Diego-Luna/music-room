import 'package:flutter/material.dart';
import 'package:music_room_app/config/api_config.dart';
import 'package:music_room_app/core/routing/app_router.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/widgets/neumorphic_form_field.dart';
import 'package:music_room_app/core/animations/neumorphic_interactive_container.dart';

/// V.5 — let testers point the app at any backend without rebuilding.
class BackendUrlSection extends StatefulWidget {
  const BackendUrlSection({super.key});

  @override
  State<BackendUrlSection> createState() => _BackendUrlSectionState();
}

class _BackendUrlSectionState extends State<BackendUrlSection> {
  late final TextEditingController _controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ApiConfig.baseUrl);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await applyBackendUrlChange(_controller.text);
      if (!mounted) return;
      _controller.text = ApiConfig.baseUrl;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Backend URL set to ${ApiConfig.baseUrl}'),
          backgroundColor: Colors.green,
        ),
      );
    } on FormatException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not update backend URL: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reset() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await resetBackendUrlToDefault();
      if (!mounted) return;
      _controller.text = ApiConfig.baseUrl;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Backend URL reset to ${ApiConfig.baseUrl}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not reset backend URL: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Backend',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: AppTypography.bold,
          ),
        ),
        const SizedBox(height: AppDimens.xs),
        Text(
          'API address used for tests (saved on this device).',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.disabledColor,
          ),
        ),
        const SizedBox(height: AppDimens.md),
        NeumorphicTextField(
          controller: _controller,
          label: 'Backend URL',
          hint: 'http://localhost:3000',
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: AppDimens.md),
        Row(
          children: [
            Expanded(
              child: NeumorphicInteractiveContainer(
                onTap: _saving ? null : _save,
                padding: const EdgeInsets.symmetric(
                  vertical: AppDimens.md,
                  horizontal: AppDimens.lg,
                ),
                child: Center(
                  child: _saving
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.primary,
                          ),
                        )
                      : Text(
                          'Save',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: AppTypography.bold,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(width: AppDimens.md),
            Expanded(
              child: NeumorphicInteractiveContainer(
                onTap: _saving ? null : _reset,
                padding: const EdgeInsets.symmetric(
                  vertical: AppDimens.md,
                  horizontal: AppDimens.lg,
                ),
                child: Center(
                  child: Text(
                    'Reset',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: AppTypography.semibold,
                      color: theme.disabledColor,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
