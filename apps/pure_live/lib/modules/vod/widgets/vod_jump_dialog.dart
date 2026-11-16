/// Asks for a position in a list and answers it; an empty or unknown answer
/// leaves the caller where it was. The two player pages' 跳转 dialogs were
/// one shape drawn twice — the parts' `P` numbers here, the episodes' index
/// numbers there — and are one dialog now: the caller keeps its own parse.
library;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/shared.dart';

/// The ask: a number field over `1–[count]`, cancelled or confirmed. The
/// parse runs on the caller's terms — a `P` number, an episode index, a
/// plain row position are each their own reading.
Future<int?> showVodJumpDialog(
  BuildContext context, {
  required String title,
  required int count,
  required int? Function(String typed) parse,
}) async {
  final controller = TextEditingController();
  final position = await showAppDialog<int>(
    context: context,
    builder: (dialogContext) {
      final t = dialogContext.t;
      return AppDialog(
        title: Text(title),
        description: DsTextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          placeholder: '1–$count',
          onSubmitted: (_) => Navigator.of(dialogContext).pop(parse(controller.text)),
        ),
        actions: [
          DsButton(
            variant: DsButtonVariant.ghost,
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(t.common.cancel),
          ),
          DsButton(
            onPressed: () => Navigator.of(dialogContext).pop(parse(controller.text)),
            child: Text(t.common.confirm),
          ),
        ],
      );
    },
  );
  controller.dispose();
  return position;
}
