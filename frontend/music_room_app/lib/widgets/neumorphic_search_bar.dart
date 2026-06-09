import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/widgets/neumorphic_form_field.dart';

class NeumorphicSearchBar extends StatefulWidget {
  final ValueChanged<String> onChanged;
  final String hintText;
  final TextEditingController? controller;

  const NeumorphicSearchBar({
    super.key,
    required this.onChanged,
    this.hintText = 'Search...',
    this.controller,
  });

  @override
  State<NeumorphicSearchBar> createState() => _NeumorphicSearchBarState();
}

class _NeumorphicSearchBarState extends State<NeumorphicSearchBar> {
  late final TextEditingController _controller;
  late final bool _isLocalController;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
      _isLocalController = false;
    } else {
      _controller = TextEditingController();
      _isLocalController = true;
    }
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    if (_isLocalController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onTextChanged() {
    final rawText = _controller.text;
    // * Sanitizing the input to deny injection vectors
    String sanitized = rawText.replaceAll(RegExp(r'[<>\\\[\]{};*]'), '').trim();
    sanitized = sanitized.replaceAll(RegExp(r'\s+'), ' ');
    widget.onChanged(sanitized);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return NeumorphicInset(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.md,
        vertical: AppDimens.xs,
      ),
      child: TextField(
        key: const Key('neumorphic_search_text_field'),
        controller: _controller,
        inputFormatters: [
          LengthLimitingTextInputFormatter(50),
          FilteringTextInputFormatter.deny(RegExp(r'[<>\\\[\]{};*]')),
        ],
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: widget.hintText,
          prefixIcon: Icon(
            Icons.search,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          suffixIcon: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              if (_controller.text.isEmpty) {
                return const SizedBox.shrink();
              }
              return IconButton(
                icon: Icon(
                  Icons.clear,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                onPressed: () {
                  _controller.clear();
                },
              );
            },
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: AppDimens.md),
        ),
      ),
    );
  }
}
