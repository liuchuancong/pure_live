import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/features/room/room_controller.dart' show RoomController, RoomPresentation, RoomState;
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/system/configuration/app_preferences_providers.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// 显示识别状态: what the room believes the picture's shape is, over the
/// picture itself — the setting's answer, which used to be stored and never
/// drawn.
///
/// The first line is the decoder's size and its ratio, or "等待首帧" before
/// the first frame; the second names where the answer came from — the
/// decoder, or the platform's own declaration — and the presentation the room
/// is in, which is what the portrait rules read.
final class PortraitDiagnosticsBadge extends ConsumerWidget {
  /// The badge for [controller].
  const new({required this.controller, required this.state, super.key});

  /// The room whose metrics are reported.
  final RoomController controller;

  /// The room's current state.
  final RoomState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(appPreferencesProvider).showPortraitDiagnostics) {
      return const SizedBox.shrink();
    }
    final t = context.t;
    final width = state.videoWidth;
    final height = state.videoHeight;
    final hasSize = width != null && height != null && width > 0 && height > 0;
    final ratio = hasSize ? (width / height).toStringAsFixed(2) : null;
    final source = hasSize ? t.room.diagnosticsFromDecoder : t.room.diagnosticsFromPlatform;
    final presentation = switch (state.presentation) {
      RoomPresentation.normal => t.room.diagnosticsNormal,
      RoomPresentation.fullscreen => t.room.diagnosticsFullscreen,
      RoomPresentation.portraitFullscreen => t.room.diagnosticsPortrait,
      RoomPresentation.pip || RoomPresentation.miniWindow => t.room.diagnosticsPip,
    };
    return IgnorePointer(
      child: DecoratedBox(
        key: const ValueKey('portrait-stream-diagnostics'),
        decoration: BoxDecoration(color: const Color(0xCC000000), borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hasSize ? t.room.diagnosticsSize(size: '$width×$height', ratio: ratio!) : t.room.diagnosticsWaiting,
                style: PureTheme.of(context).text.caption.copyWith(color: Colors.white, fontSize: 12),
              ),
              Text(
                '$source · $presentation',
                style: PureTheme.of(context).text.caption.copyWith(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
