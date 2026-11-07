import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/surface/settings_widgets.dart' show SettingsConfigRow;
import 'package:pure_live/l10n/translations.dart';

/// 「局域网遥控」: the receiver's pane — a switch that serves the browser
/// remote, the six-digit code a phone pairs with, the QR and address it
/// opens, and the revoke that throws every paired phone off at once. The
/// page the phone sees is the receiver's own; nothing here talks to it.
final class LanRemotePane extends ConsumerWidget {
  /// The pane.
  const LanRemotePane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final remote = ref.watch(playbackRemoteProvider);
    final status = ref.watch(playbackRemoteStatus);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          header: Text(t.settings.navLanRemote),
          children: [
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.remote),
              title: t.settings.lanRemoteServe,
              description: t.settings.lanRemoteServeDesc,
              control: DsSwitch(value: status.running, onChanged: (value) => unawaited(_toggle(context, value))),
            ),
            if (status.running) ...[
              DsListRow(
                leading: const DsIcon(DsIcons.lock),
                title: Text(t.settings.lanRemoteCodeLabel),
                detail: Text(
                  status.code,
                  style: theme.typography.numeric(theme.typography.title.copyWith(color: colors.accent)),
                ),
              ),
              DsListRow(
                leading: const DsIcon(DsIcons.users),
                title: Text(t.settings.lanRemotePairedLabel),
                detail: Text('${status.paired}'),
                trailing: status.paired == 0
                    ? null
                    : DsButton(
                        variant: DsButtonVariant.secondary,
                        size: DsSize.xs,
                        onPressed: remote.revoke,
                        child: Text(t.settings.lanRemoteRevoke),
                      ),
              ),
            ],
          ],
        ),
        if (status.running && status.url.isNotEmpty)
          DsListSection(
            children: [
              DsListRow(
                leading: const DsIcon(DsIcons.qrCode),
                title: Text(status.url),
                description: Text(t.settings.lanRemoteAddressHint),
                trailing: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 132),
                  child: Padding(
                    padding: const EdgeInsets.all(DsSpace.s8),
                    child: PrettyQrView.data(data: status.url),
                  ),
                ),
              ),
            ],
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.s4),
          child: Text(t.settings.lanRemoteHint, style: theme.typography.caption.copyWith(color: colors.textSubtle)),
        ),
      ],
    );
  }

  Future<void> _toggle(BuildContext context, bool serve) async {
    final t = context.t;
    final remote = playbackRemote;
    try {
      if (serve) {
        await remote.start(labels: remotePageLabels(t));
      } else {
        await remote.stop();
      }
    } on Object {
      if (context.mounted) showDsToast(context: context, title: t.settings.lanRemoteFailed);
    }
  }
}
