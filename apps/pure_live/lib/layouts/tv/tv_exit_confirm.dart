import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:flutter/widgets.dart';

import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/layouts/tv/tv_dialog.dart' show showTvDialog;

/// The remote's back at the app's root: the shell route cannot pop, so Back
/// asks whether the viewer is done for the day. The reference autofocuses
/// the confirm, so a second press lands on it; leaving takes one more press
/// than abandoning takes.
Future<void> showTvExitConfirm(BuildContext context) => showTvDialog<void>(
  context: context,
  dismissible: false,
  builder: (context) => DsDialog(
    title: Text(context.t.common.exitAppTitle),
    description: Text(context.t.common.exitAppMessage),
    actions: [
      DsButton(
        variant: DsButtonVariant.secondary,
        onPressed: () => Navigator.of(context).pop(),
        child: Text(context.t.common.cancel),
      ),
      DsButton(
        autofocus: true,
        onPressed: () {
          Navigator.of(context).pop();
          unawaited(SystemNavigator.pop());
        },
        child: Text(context.t.common.exitApp),
      ),
    ],
  ),
);
