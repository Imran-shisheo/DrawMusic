import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import 'creative_panel.dart';
import 'doodimo_icon.dart';
import 'immersive_surface.dart';

Future<String?> askDrawingName(
  BuildContext context,
  String title, {
  String? heading,
  Rect? sourceBounds,
}) => showCreativePanel<String>(
  context: context,
  sourceBounds: sourceBounds,
  builder: (_) => _NameDialog(
    title: title,
    heading: heading ?? context.strings.nameYourDrawing,
  ),
);

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.title, required this.heading});
  final String title, heading;
  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final controller = TextEditingController(text: widget.title);
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = controller.text.trim();
    final valid = name.isNotEmpty && name.length <= 60;
    void apply() {
      final current = controller.text.trim();
      if (current.isNotEmpty && current.length <= 60) {
        Navigator.pop(context, current);
      }
    }

    return CreativePanel(
      title: widget.heading,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.strings.cancel),
        ),
        PrismAction(
          onPressed: valid ? apply : null,
          label: context.strings.apply,
          icon: const DoodimoIcon(DoodimoGlyph.check),
        ),
      ],
      child: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 60,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) {
          if (valid) apply();
        },
        decoration: InputDecoration(
          labelText: context.strings.title,
          errorText: valid ? null : context.strings.nameLengthError,
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }
}
