import 'package:flutter/material.dart';

import '../l10n/strings.dart';

Future<String?> askDrawingName(
  BuildContext context,
  String title, {
  String? heading,
}) => showDialog<String>(
  context: context,
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
    return AlertDialog(
      title: Text(widget.heading),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 60,
        decoration: InputDecoration(
          labelText: context.strings.title,
          errorText: valid ? null : context.strings.nameLengthError,
        ),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.strings.cancel),
        ),
        FilledButton(
          onPressed: valid
              ? () {
                  final current = controller.text.trim();
                  if (current.isNotEmpty && current.length <= 60) {
                    Navigator.pop(context, current);
                  }
                }
              : null,
          child: Text(context.strings.apply),
        ),
      ],
    );
  }
}
