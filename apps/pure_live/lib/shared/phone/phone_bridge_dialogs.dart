import 'dart:async' show Timer, unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/phone/phone_bridge.dart';
import 'package:pure_live/shared/phone/tv_phone_server.dart';
import 'package:pure_live/shared/widgets/app_dialog.dart';

/// Fills [request] on a phone: the code of a one-off page on this network;
/// the values when the phone sends them, null when cancelled.
Future<Map<String, String>?> showTvPhoneInput(BuildContext context, PhoneInputRequest request) =>
    showAppDialog<Map<String, String>>(
      context: context,
      builder: (context) => _PhoneServerDialog(
        title: request.title,
        start: () => TvPhoneServer.start(
          form: request,
          doneText: context.t.phone.doneSent,
          htmlTitle: context.t.phone.htmlTitle,
        ),
        steps: [context.t.phone.stepScan, context.t.phone.stepFill, context.t.phone.stepDone],
      ),
    );

/// Shows [text] on a phone: the code of a one-off page on this network (a
/// log is easier to read there).
Future<void> showTvPhoneView(BuildContext context, {required String title, required String text}) => showAppDialog<void>(
  context: context,
  builder: (context) => _PhoneServerDialog(
    title: title,
    start: () => TvPhoneServer.start(
      text: text,
      title: title,
      doneText: context.t.phone.doneSent,
      htmlTitle: context.t.phone.htmlTitle,
    ),
    steps: [context.t.phone.stepScan, context.t.phone.stepRead],
  ),
);

final class _PhoneServerDialog extends StatefulWidget {
  const _PhoneServerDialog({required this.title, required this.start, required this.steps});

  final String title;
  final Future<TvPhoneServer> Function() start;
  final List<String> steps;

  @override
  State<_PhoneServerDialog> createState() => _PhoneServerDialogState();
}

class _PhoneServerDialogState extends State<_PhoneServerDialog> {
  TvPhoneServer? _server;
  bool _failed = false;
  Timer? _poll;
  bool _opened = false;

  @override
  void initState() {
    super.initState();
    unawaited(_open());
  }

  Future<void> _open() async {
    try {
      final server = await widget.start();
      if (!mounted) {
        await server.close();
        return;
      }
      setState(() => _server = server);
      _poll = Timer.periodic(const Duration(seconds: 1), (_) {
        if (server.opened != _opened && mounted) setState(() => _opened = server.opened);
      });
      if (server.form != null) {
        final values = await server.submitted;
        if (mounted) Navigator.of(context).pop(values);
      }
    } on Object {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    unawaited(_server?.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final server = _server;
    return AppDialog(
      title: Text(widget.title),
      description: _failed
          ? Text(t.phone.failed)
          : server == null
          ? Text(t.phone.starting)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: DsSpace.s12,
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: PrettyQrView.data(data: server.url),
                  ),
                ),
                Center(
                  child: Text(
                    server.url,
                    style: DsTheme.of(context).typography.numeric(
                      DsTheme.of(context).typography.caption.copyWith(color: DsTheme.colorsOf(context).textMuted),
                    ),
                  ),
                ),
                Text(
                  _opened ? t.phone.opened : t.phone.running,
                  textAlign: TextAlign.center,
                  style: DsTheme.of(context).typography.caption.copyWith(color: DsTheme.colorsOf(context).textSubtle),
                ),
                for (final (index, step) in widget.steps.indexed)
                  Text(
                    '${index + 1}. $step',
                    style: DsTheme.of(context).typography.small.copyWith(color: DsTheme.colorsOf(context).text),
                  ),
              ],
            ),
      actions: [
        DsButton(
          variant: DsButtonVariant.secondary,
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.common.cancel),
        ),
      ],
    );
  }
}
