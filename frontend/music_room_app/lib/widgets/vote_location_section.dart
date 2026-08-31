import 'package:flutter/material.dart';
import 'package:music_room_app/config/location_config.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/widgets/neumorphic_form_field.dart';
import 'package:music_room_app/core/animations/neumorphic_interactive_container.dart';

/// V.2.1 — coordinates sent with votes for location-licensed events.
class VoteLocationSection extends StatefulWidget {
  const VoteLocationSection({super.key});

  @override
  State<VoteLocationSection> createState() => _VoteLocationSectionState();
}

class _VoteLocationSectionState extends State<VoteLocationSection> {
  late final TextEditingController _latController;
  late final TextEditingController _lngController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final current = LocationConfig.current;
    _latController = TextEditingController(text: current?.lat.toString() ?? '');
    _lngController = TextEditingController(text: current?.lng.toString() ?? '');
  }

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());
    if (lat == null || lng == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Enter valid latitude and longitude numbers.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await LocationConfig.setOverride(lat: lat, lng: lng);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Vote location set to $lat, $lng'),
          backgroundColor: Colors.green,
        ),
      );
    } on FormatException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.redAccent),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not save location: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _useParisDemo() async {
    _latController.text = '48.8566';
    _lngController.text = '2.3522';
    await _save();
  }

  Future<void> _clear() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await LocationConfig.clearOverride();
      if (!mounted) return;
      _latController.clear();
      _lngController.clear();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Vote location cleared'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not clear location: $e'),
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
          'Vote location',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: AppTypography.bold,
          ),
        ),
        const SizedBox(height: AppDimens.xs),
        Text(
          'Sent with each vote when an event is location-licensed. '
          'Also the position used to detect nearby public events (VI.2). '
          'Match the venue coords (or use the Paris demo).',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.disabledColor,
          ),
        ),
        const SizedBox(height: AppDimens.md),
        Row(
          children: [
            Expanded(
              child: NeumorphicTextField(
                controller: _latController,
                label: 'Latitude',
                hint: '48.8566',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
              ),
            ),
            const SizedBox(width: AppDimens.md),
            Expanded(
              child: NeumorphicTextField(
                controller: _lngController,
                label: 'Longitude',
                hint: '2.3522',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
              ),
            ),
          ],
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
                onTap: _saving ? null : _useParisDemo,
                padding: const EdgeInsets.symmetric(
                  vertical: AppDimens.md,
                  horizontal: AppDimens.lg,
                ),
                child: Center(
                  child: Text(
                    'Paris demo',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: AppTypography.semibold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimens.sm),
        NeumorphicInteractiveContainer(
          onTap: _saving ? null : _clear,
          padding: const EdgeInsets.symmetric(
            vertical: AppDimens.md,
            horizontal: AppDimens.lg,
          ),
          child: Center(
            child: Text(
              'Clear',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: AppTypography.semibold,
                color: theme.disabledColor,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
