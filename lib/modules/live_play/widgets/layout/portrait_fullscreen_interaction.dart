import 'dart:async';

import 'package:pure_live/common/index.dart';

enum PortraitPanelDragDisposition { restorePanel, enterFullscreen }

const double portraitFullscreenRestoreGestureZone = 96;

PortraitPanelDragDisposition resolvePortraitPanelDragEnd({
  required bool entryEnabled,
  required double dismissOffset,
  required double panelHeight,
  required double velocity,
}) {
  if (!entryEnabled || dismissOffset <= 0 || panelHeight <= 0) {
    return PortraitPanelDragDisposition.restorePanel;
  }
  final distanceThreshold = (panelHeight * 0.30).clamp(72.0, 144.0).toDouble();
  final passedDistance = dismissOffset >= distanceThreshold;
  final passedFling = velocity >= 900 && dismissOffset >= 28;
  return passedDistance || passedFling
      ? PortraitPanelDragDisposition.enterFullscreen
      : PortraitPanelDragDisposition.restorePanel;
}

bool canEnterPortraitPanelFullscreen({
  required bool isPortraitSource,
  required bool adaptationEnabled,
  required bool adaptiveHeightEnabled,
  required bool compatibilityLayout,
  required bool mobilePlatform,
}) {
  return mobilePlatform &&
      isPortraitSource &&
      adaptationEnabled &&
      adaptiveHeightEnabled &&
      !compatibilityLayout;
}

bool shouldRestorePortraitPanelFromSwipe({
  required double upwardDistance,
  required double velocity,
}) {
  return upwardDistance >= 64 || (velocity <= -850 && upwardDistance >= 24);
}

/// Transient guidance shown only after the dedicated portrait fullscreen mode
/// has been entered. Player controls hide first; this affordance follows one
/// second later so the settled screen contains only video and overlay danmaku.
class PortraitFullscreenEntryHint extends StatefulWidget {
  const PortraitFullscreenEntryHint({super.key, this.visibleDuration = const Duration(seconds: 3)});

  final Duration visibleDuration;

  @override
  State<PortraitFullscreenEntryHint> createState() => _PortraitFullscreenEntryHintState();
}

class _PortraitFullscreenEntryHintState extends State<PortraitFullscreenEntryHint> {
  Timer? _hideTimer;
  bool _visible = true;

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(widget.visibleDuration, () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void initState() {
    super.initState();
    _scheduleHide();
  }

  @override
  void didUpdateWidget(covariant PortraitFullscreenEntryHint oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visibleDuration == widget.visibleDuration) return;
    _visible = true;
    _scheduleHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SafeArea(
        minimum: const EdgeInsets.only(bottom: 18),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: AnimatedOpacity(
            key: const ValueKey('portrait-fullscreen-entry-hint-opacity'),
            opacity: _visible ? 1 : 0,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOut,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.66),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 6),
                    Text(
                      i18n('portrait_fullscreen_restore_hint'),
                      key: const ValueKey('portrait-fullscreen-entry-hint'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
