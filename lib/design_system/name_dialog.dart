import 'package:flutter/material.dart';

Future<String?> askDrawingName(BuildContext context, String title) =>
    showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(title: title),
    );

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.title});
  final String title;
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
      title: const Text('Name your drawing'),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 60,
        decoration: InputDecoration(
          labelText: 'Title',
          errorText: valid ? null : 'Use a name of 1–60 characters',
        ),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
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
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
