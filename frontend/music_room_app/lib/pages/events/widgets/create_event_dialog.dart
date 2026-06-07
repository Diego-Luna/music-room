import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/providers/events_provider.dart';
import 'package:music_room_app/widgets/neumorphic_form_field.dart';
import 'package:music_room_app/widgets/primary_button.dart';

class CreateEventDialog extends StatefulWidget {
  const CreateEventDialog({super.key});

  @override
  State<CreateEventDialog> createState() => _CreateEventDialogState();
}

class _CreateEventDialogState extends State<CreateEventDialog> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _latController = TextEditingController(text: '48.8566');
  final _lngController = TextEditingController(text: '2.3522');
  final _radiusController = TextEditingController(text: '100');

  bool _isPublic = true;
  String _voteAccess = 'EVERYONE';
  bool _isGeoGated = false;
  bool _isScheduled = false;
  DateTime _startsAt = DateTime.now();
  DateTime _endsAt = DateTime.now().add(const Duration(hours: 4));

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _radiusController.dispose();
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
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppDimens.radiusLarge),
            topRight: Radius.circular(AppDimens.radiusLarge),
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(theme),
              const SizedBox(height: AppDimens.md),
              _buildBasicFields(theme),
              const SizedBox(height: AppDimens.md),
              _buildGeoGatingSection(theme),
              const SizedBox(height: AppDimens.md),
              _buildSchedulingSection(theme),
              const SizedBox(height: AppDimens.xl),
              _buildSubmitButton(theme, eventsProvider, scaffoldMessenger),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Create Event (VOTE Room)',
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

  Widget _buildBasicFields(ThemeData theme) {
    return Column(
      children: [
        NeumorphicTextField(
          controller: _nameController,
          label: 'Event Name *',
          hint: 'e.g. Summer Pool Party',
        ),
        const SizedBox(height: AppDimens.md),
        NeumorphicTextField(
          controller: _descController,
          label: 'Description',
          hint: 'e.g. Vote for electronic tracks...',
        ),
        const SizedBox(height: AppDimens.md),
        NeumorphicToggleTile(
          title: 'Public Visibility',
          subtitle: 'All users can search and discover this event',
          value: _isPublic,
          onChanged: (val) => setState(() => _isPublic = val),
        ),
        const SizedBox(height: AppDimens.md),
        NeumorphicDropdown<String>(
          value: _voteAccess,
          label: 'Who can vote?',
          items: const [
            DropdownMenuItem(value: 'EVERYONE', child: Text('Everyone')),
            DropdownMenuItem(
              value: 'INVITED_ONLY',
              child: Text('Invited Only'),
            ),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _voteAccess = val);
          },
        ),
      ],
    );
  }

  Widget _buildGeoGatingSection(ThemeData theme) {
    return Column(
      children: [
        NeumorphicToggleTile(
          title: 'Enable Geo-Gating',
          subtitle: 'Restrict voting to a specific location',
          value: _isGeoGated,
          onChanged: (val) => setState(() => _isGeoGated = val),
        ),
        if (_isGeoGated) ...[
          const SizedBox(height: AppDimens.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: NeumorphicTextField(
                  controller: _latController,
                  label: 'Latitude (-90 to 90)',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
              const SizedBox(width: AppDimens.md),
              Expanded(
                child: NeumorphicTextField(
                  controller: _lngController,
                  label: 'Longitude (-180 to 180)',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.md),
          NeumorphicTextField(
            controller: _radiusController,
            label: 'Radius in meters (min 10)',
            keyboardType: TextInputType.number,
          ),
        ],
      ],
    );
  }

  Widget _buildSchedulingSection(ThemeData theme) {
    return Column(
      children: [
        NeumorphicToggleTile(
          title: 'Schedule Voting Window',
          subtitle: 'Only allow voting within a specific time',
          value: _isScheduled,
          onChanged: (val) => setState(() => _isScheduled = val),
        ),
        if (_isScheduled) ...[
          const SizedBox(height: AppDimens.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _dateSelector('Starts', _startsAt, _selectStartDate),
              ),
              const SizedBox(width: AppDimens.md),
              Expanded(child: _dateSelector('Ends', _endsAt, _selectEndDate)),
            ],
          ),
        ],
      ],
    );
  }

  Widget _dateSelector(String label, DateTime date, VoidCallback onTap) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppDimens.xs,
            bottom: AppDimens.xs,
          ),
          child: Text(label, style: theme.textTheme.labelLarge),
        ),
        GestureDetector(
          onTap: onTap,
          child: NeumorphicInset(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.md,
              vertical: AppDimens.sm,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: AppDimens.iconSmall,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: AppDimens.sm),
                Expanded(
                  child: Text(
                    date.toString().substring(0, 16),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _selectStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startsAt,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_startsAt),
      );
      if (time != null && mounted) {
        setState(() {
          _startsAt = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _selectEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endsAt,
      firstDate: _startsAt,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_endsAt),
      );
      if (time != null && mounted) {
        setState(() {
          _endsAt = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Widget _buildSubmitButton(
    ThemeData theme,
    EventsProvider eventsProvider,
    ScaffoldMessengerState scaffoldMessenger,
  ) {
    return Center(
      child: PrimaryButton(
        onPressed: () => _handleSubmit(eventsProvider, scaffoldMessenger),
        label: 'Create Event',
      ),
    );
  }

  void _handleSubmit(
    EventsProvider eventsProvider,
    ScaffoldMessengerState scaffoldMessenger,
  ) {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Please enter an event name')),
      );
      return;
    }
    final desc = _descController.text.trim();

    double? lat;
    double? lng;
    double? radius;
    if (_isGeoGated) {
      lat = double.tryParse(_latController.text);
      lng = double.tryParse(_lngController.text);
      radius = double.tryParse(_radiusController.text);
      if (lat == null || lat < -90 || lat > 90) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Latitude must be between -90 and 90')),
        );
        return;
      }
      if (lng == null || lng < -180 || lng > 180) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Longitude must be between -180 and 180'),
          ),
        );
        return;
      }
      if (radius == null || radius < 10) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Radius must be at least 10 meters')),
        );
        return;
      }
    }

    if (_isScheduled && _endsAt.isBefore(_startsAt)) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('End time must be after start time')),
      );
      return;
    }

    final navigator = Navigator.of(context);
    eventsProvider
        .createEvent(
          name: name,
          description: desc,
          isPublic: _isPublic,
          voteAccess: _voteAccess,
          voteWindow: _isScheduled ? 'SCHEDULED' : 'ALWAYS',
          voteStartsAt: _isScheduled ? _startsAt : null,
          voteEndsAt: _isScheduled ? _endsAt : null,
          voteLocationLat: lat,
          voteLocationLng: lng,
          voteLocationRadiusM: radius,
        )
        .then((_) {
          navigator.pop();
          scaffoldMessenger.showSnackBar(
            SnackBar(content: Text('Event "$name" created successfully!')),
          );
        })
        .catchError((err) {
          scaffoldMessenger.showSnackBar(
            SnackBar(content: Text('Error: $err')),
          );
        });
  }
}
