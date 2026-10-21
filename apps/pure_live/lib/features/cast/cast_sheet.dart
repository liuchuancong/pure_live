import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_core/media_core.dart' show CastDevice, CastMedia, CastTransportState;
import 'package:pure_live/features/cast/cast_providers.dart';
import 'package:pure_live/features/settings/widgets/settings_surface.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// Opens the cast surface: the renderers on the LAN, the live session's state,
/// and the stop control. [media] is what a picked device will be asked to
/// fetch — the caller builds it from the room's current line; null (a line a
/// TV could never take) leaves the surface as a status/stop panel only.
///
/// The body brings no scroll view of its own: [showSettingsSurface] owns it, and
/// it centres on a desktop window rather than rising from the bottom edge.
Future<void> showCastSheet(
  BuildContext context,
  WidgetRef ref, {
  required CastMedia? media,
  VoidCallback? onCastStarted,
}) => showSettingsSurface<void>(
  context,
  ref.settingsFormFactor,
  title: null,
  body: (surfaceContext) => _CastSheet(media: media, onCastStarted: onCastStarted),
);

class _CastSheet extends ConsumerStatefulWidget {
  const new({required this.media, this.onCastStarted});

  final CastMedia? media;
  final VoidCallback? onCastStarted;

  @override
  ConsumerState<_CastSheet> createState() => _CastSheetState();
}

class _CastSheetState extends ConsumerState<_CastSheet> {
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(ref.read(castServiceProvider).startDiscovery());
  }

  Future<void> _pick(CastDevice device) async {
    final media = widget.media;
    if (media == null) {
      return;
    }
    try {
      await ref.read(castServiceProvider).castTo(device, media);
      if (!mounted) {
        return;
      }
      widget.onCastStarted?.call();
      Navigator.of(context).pop();
    } on Object {
      // A receiver that refuses the item says so here; the honest answer is
      // the device could not fetch the URL, not a silent dead sheet.
      if (mounted) {
        setState(() => _error = context.t.cast.failed);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = PureTheme.of(context);
    final service = ref.watch(castServiceProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, PureSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(t.cast.title, style: theme.text.title)),
                if (service.isCasting)
                  PureButton(
                    key: const ValueKey('cast-stop'),
                    label: t.cast.stop,
                    icon: Icons.stop_circle_outlined,
                    size: ControlSize.sm,
                    variant: ButtonVariant.danger,
                    onPressed: () => unawaited(service.stop()),
                  ),
              ],
            ),
            const SizedBox(height: PureSpacing.xs),
            Text(
              service.isCasting ? t.cast.castingTo(name: service.device?.name ?? '') : t.cast.hint,
              style: theme.text.bodySmall.copyWith(color: theme.colors.textSecondary),
            ),
            if (_error case final error?)
              Padding(
                key: const ValueKey('cast-error'),
                padding: const EdgeInsets.only(top: 6),
                child: Text(error, style: theme.text.bodySmall.copyWith(color: theme.colors.error)),
              ),
            const SizedBox(height: PureSpacing.sm),
            // The list is a plain column: the surface that hosts this body owns
            // the scroll view, and a `Flexible`/`ListView` pair inside one asks
            // for a height it is never given.
            if (service.devices.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Center(
                  child: Text(
                    t.cast.searching,
                    key: const ValueKey('cast-searching'),
                    style: theme.text.bodySmall.copyWith(color: theme.colors.textSecondary),
                  ),
                ),
              )
            else
              for (final device in service.devices)
                _DeviceRow(
                  device: device,
                  current: service.device?.id == device.id,
                  state: service.device?.id == device.id ? service.transportState : null,
                  onTap: widget.media == null ? null : () => unawaited(_pick(device)),
                ),
          ],
        ),
      ),
    );
  }
}

/// One renderer: its advertised name, who makes it, and — when it is the
/// session's device — what the receiver says playback is doing.
final class _DeviceRow extends StatelessWidget {
  const new({required this.device, required this.current, required this.state, required this.onTap});

  final CastDevice device;
  final bool current;
  final CastTransportState? state;
  final VoidCallback? onTap;

  String? _stateLabel(BuildContext context) {
    final t = context.t;
    return switch (state) {
      CastTransportState.playing => t.cast.statePlaying,
      CastTransportState.paused => t.cast.statePaused,
      CastTransportState.transitioning => t.cast.stateBuffering,
      CastTransportState.stopped || CastTransportState.noMedia => t.cast.stateStopped,
      CastTransportState.unknown => t.cast.stateUnreachable,
      null => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final detail = [
      device.manufacturer,
      device.modelName,
    ].whereType<String>().where((s) => s.trim().isNotEmpty).join(' · ');
    return PureListRow(
      key: ValueKey('cast-device-${device.id}'),
      leading: Icon(
        current ? Icons.cast_connected : Icons.cast,
        color: current ? PureTheme.of(context).colors.primary : null,
      ),
      title: device.name,
      subtitle: [if (detail.isNotEmpty) detail, ?_stateLabel(context)].join(' · '),
      trailing: current
          ? null
          : onTap == null
          ? null
          : const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
