import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart' show LivePlayLine;
import 'package:media_core/media_core.dart' show CastController, CastDevice, CastMedia;
import 'package:media_core_cast_dlna/media_core_cast_dlna.dart' show DlnaCastBackend;
import 'package:pure_live/l10n/translations.dart';

/// The app's one DLNA casting controller: SSDP discovery and the AVTransport
/// commands behind media_core's [CastController]. Discovery starts on first
/// use and stops with the provider.
final castControllerProvider = Provider<CastController>((ref) {
  final backend = DlnaCastBackend();
  final controller = CastController(backend: backend);
  unawaited(backend.startDiscovery());
  ref.onDispose(() {
    unawaited(controller.dispose());
    unawaited(backend.dispose());
  });
  return controller;
});

/// Opens the cast picker for [line]: the devices discovered on the local
/// network, a tap to send the stream to one, and a stop action while a
/// session runs.
///
/// The receiver fetches the line itself, so only a line it can reach works —
/// a signed header the TV cannot send surfaces as a cast failure, never as a
/// fake success.
Future<void> showCastDialog(
  BuildContext context, {
  required LivePlayLine line,
  required String? title,
}) {
  return showDsDialog<void>(
    context: context,
    builder: (context) => _CastDialog(line: line, title: title ?? context.t.room.castTitle),
  );
}

final class _CastDialog extends ConsumerWidget {
  const _CastDialog({required this.line, required this.title});

  final LivePlayLine line;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final controller = ref.watch(castControllerProvider);
    return DsDialog(
      title: Text(t.room.castTitle),
      description: SizedBox(
        width: 380,
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final devices = controller.devices;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              spacing: DsSpace.s8,
              children: [
                if (controller.isCasting)
                  DsListRow(
                    leading: const DsIcon(DsIcons.cast),
                    title: Text(controller.device?.name ?? ''),
                    description: Text(t.room.casting),
                    trailing: DsButton(
                      variant: DsButtonVariant.secondary,
                      size: DsSize.sm,
                      onPressed: () => unawaited(controller.stopCasting()),
                      child: Text(t.room.castStop),
                    ),
                  ),
                if (devices.isEmpty)
                  DsEmptyState(
                    icon: const DsIcon(DsIcons.cast),
                    title: Text(t.room.castSearching),
                    description: Text(t.room.castSearchingHint),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: SingleChildScrollView(
                      child: DsListSection(
                        header: Text(t.room.castDevices),
                        children: [
                          for (final device in devices)
                            DsListRow(
                              leading: const DsIcon(DsIcons.tv),
                              title: Text(device.name),
                              description: Text(device.modelName ?? device.typeName ?? device.backendId),
                              onPressed: () => unawaited(_cast(context, controller, device)),
                              trailing: const DsIcon(DsIcons.chevronRight),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      actions: [
        DsButton(
          variant: DsButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.common.close),
        ),
      ],
    );
  }

  Future<void> _cast(BuildContext context, CastController controller, CastDevice device) async {
    final room = context.t.room;
    try {
      await controller.cast(device, CastMedia(url: line.url, title: title, headers: line.headers.toMap()));
      if (!context.mounted) return;
      Navigator.of(context).pop();
      showDsToast(context: context, title: room.castStarted);
    } on Object {
      if (!context.mounted) return;
      showDsToast(context: context, title: room.castFailed);
    }
  }
}
