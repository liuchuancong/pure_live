import 'package:flutter/material.dart';

import 'package:pure_live/l10n/generated/strings.g.dart';

/// Asks for a group name; returns the trimmed name, or null when cancelled
/// or left empty. Used for both creation (empty [initial]) and rename.
Future<String?> showFollowGroupNameDialog(BuildContext context, {required String title, String? initial}) {
  final field = TextEditingController(text: initial ?? '');
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: field,
        autofocus: true,
        onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.t.common.cancel)),
        TextButton(
          onPressed: () => Navigator.of(context).pop(field.text.trim()),
          child: Text(context.t.common.confirm),
        ),
      ],
    ),
  );
}
