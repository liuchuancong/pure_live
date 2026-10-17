import 'package:flutter/material.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// Asks for a group name; returns the trimmed name, or null when cancelled
/// or left empty. Used for both creation (empty [initial]) and rename.
Future<String?> showFollowGroupNameDialog(BuildContext context, {required String title, String? initial}) {
  final field = TextEditingController(text: initial ?? '');
  return showPureDialog<String>(
    context: context,
    title: title,
    // A Builder so the field's submit pops the dialog route rather than the
    // page that asked for the name.
    child: Builder(
      builder: (fieldContext) => Focus(
        autofocus: true,
        child: PureTextField(
          controller: field,
          placeholder: fieldContext.t.follow.newGroup,
          onSubmitted: (value) => Navigator.of(fieldContext).pop(value.trim()),
        ),
      ),
    ),
    actions: (dialogContext) => [
      PureButton(
        label: dialogContext.t.common.cancel,
        variant: ButtonVariant.ghost,
        onPressed: () => Navigator.of(dialogContext).pop(),
      ),
      PureButton(
        label: dialogContext.t.common.confirm,
        onPressed: () => Navigator.of(dialogContext).pop(field.text.trim()),
      ),
    ],
  );
}
