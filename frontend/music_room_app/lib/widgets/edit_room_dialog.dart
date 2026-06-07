import 'package:flutter/material.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/core/utils/api_error_handler.dart';
import 'package:music_room_app/models/room.dart';
import 'package:music_room_app/widgets/primary_button.dart';
import 'package:music_room_app/widgets/neumorphic_form_field.dart';

// Called on save with the edited settings. The dialog fills editAccess for
// PLAYLIST rooms and voteAccess for VOTE rooms (only one is ever non-null).
typedef EditRoomSubmit =
    Future<void> Function({
      required String name,
      String? description,
      required bool isPublic,
      String? editAccess,
      String? voteAccess,
    });

// * V.2.3 / V.3.2 — owner/admin edits an existing room's settings (rename,
// * description, visibility and the edit/vote license). Mirrors the create
// * dialogs but pre-filled from [room]. Vote schedule/location stay as set at
// * creation (not exposed here).
class EditRoomDialog extends StatefulWidget {
  final Room room;
  final EditRoomSubmit onSubmit;

  const EditRoomDialog({super.key, required this.room, required this.onSubmit});

  @override
  State<EditRoomDialog> createState() => _EditRoomDialogState();
}

class _EditRoomDialogState extends State<EditRoomDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late bool _isPublic;
  late String _license;
  bool _submitting = false;

  bool get _isPlaylist => widget.room.kind == RoomKind.playlist;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.room.name);
    _descController = TextEditingController(text: widget.room.description ?? '');
    _isPublic = widget.room.isPublic;
    _license =
        (_isPlaylist ? widget.room.editAccess : widget.room.voteAccess) ??
        'EVERYONE';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please enter a name')),
      );
      return;
    }

    setState(() => _submitting = true);
    final desc = _descController.text.trim();
    try {
      await widget.onSubmit(
        name: name,
        description: desc.isEmpty ? null : desc,
        isPublic: _isPublic,
        editAccess: _isPlaylist ? _license : null,
        voteAccess: _isPlaylist ? null : _license,
      );
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Room updated')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not update: ${ApiErrorHandler.getMessage(e)}'),
          backgroundColor: Colors.redAccent,
        ),
      );
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
                    'Edit Room',
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
                label: 'Name *',
                hint: 'Room name',
                autofocus: true,
              ),
              const SizedBox(height: AppDimens.md),
              NeumorphicTextField(
                controller: _descController,
                label: 'Description',
                hint: 'Optional description',
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
                value: _license,
                label: _isPlaylist ? 'Who can edit?' : 'Who can vote?',
                items: const [
                  DropdownMenuItem(value: 'EVERYONE', child: Text('Everyone')),
                  DropdownMenuItem(
                    value: 'INVITED_ONLY',
                    child: Text('Invited only'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _license = val);
                },
              ),
              const SizedBox(height: AppDimens.xl),
              Center(
                child: PrimaryButton(
                  onPressed: _submitting ? null : _handleSubmit,
                  isLoading: _submitting,
                  label: 'Save Changes',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
