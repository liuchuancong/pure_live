import 'package:pure_live/features/room/room_controller.dart' show RoomPresentation;
import 'package:pure_live/system/configuration/app_preferences.dart';

/// The portrait-adaptation rules — the answers the 竖屏直播适配 page stores,
/// read as decisions. Broken out of the widgets so each rule is testable
/// without pumping a room.

/// Whether the phone layout takes the tall-source shape (full-bleed picture
/// under a sheet); `compatibility` keeps even a vertical stream in the plain
/// letterboxed stack, and adaptation off keeps every stream there.
bool usesPortraitShape(AppPreferences preferences, {required bool verticalSource}) =>
    verticalSource && preferences.portraitAdapt && preferences.portraitLayoutMode != 'compatibility';

/// The panel stops the sheet opens with. The reference's 自适应高度 off fixes
/// the panel at the middle — the drag then only drives the fullscreen entry —
/// and 沉浸 opens at the floor so the picture keeps the body.
({double minimum, double middle, double maximum, double initial}) applyPanelStops(
  ({double minimum, double middle, double maximum, double initial}) stops,
  AppPreferences preferences,
) {
  if (!preferences.portraitAdaptiveHeight) {
    return (minimum: stops.middle, middle: stops.middle, maximum: stops.middle, initial: stops.middle);
  }
  final initial = preferences.portraitLayoutMode == 'immersive' ? stops.minimum : stops.initial;
  return (minimum: stops.minimum, middle: stops.middle, maximum: stops.maximum, initial: initial);
}

/// The direction a fullscreen entry takes for a vertical source.
/// [requested] is what the caller asked for — the landscape pill asks for the
/// sideways room, the sheet's down-drag asks for the upright one; the policy
/// answers which they get, and a per-room override (the reference's
/// portraitRoomOverrides) outranks the policy while it is remembered.
RoomPresentation resolveFullscreenEntry(
  RoomPresentation requested, {
  required AppPreferences preferences,
  required bool verticalSource,
  String? roomOverride,
}) {
  if (!verticalSource || !preferences.portraitAdapt) {
    return requested;
  }
  final override = preferences.rememberPortraitRoomOverride ? roomOverride : null;
  if (override != null) {
    return override == 'portrait' ? RoomPresentation.portraitFullscreen : RoomPresentation.fullscreen;
  }
  return switch ((requested, preferences.portraitFullscreenPolicy)) {
    (RoomPresentation.fullscreen, 'followSource') => RoomPresentation.portraitFullscreen,
    (RoomPresentation.portraitFullscreen, 'landscape') => RoomPresentation.fullscreen,
    _ => requested,
  };
}

/// The direction a manual fullscreen choice is remembered as.
String? fullscreenOverrideOf(RoomPresentation presentation) => switch (presentation) {
  RoomPresentation.portraitFullscreen => 'portrait',
  RoomPresentation.fullscreen => 'landscape',
  _ => null,
};

/// The barrage bounds over a vertical picture (竖屏弹幕布局): rows and band
/// the surface gets, never the stored global style numbers.
({int rows, double? area, bool hidden}) portraitBarrage(
  AppPreferences preferences, {
  required int globalRows,
}) => switch (preferences.portraitDanmakuMode) {
  'upperQuarter' => (rows: globalRows, area: 0.25, hidden: false),
  'reduced' => (rows: (globalRows ~/ 2).clamp(1, 16), area: null, hidden: false),
  'hidden' => (rows: globalRows, area: null, hidden: true),
  _ => (rows: globalRows, area: null, hidden: false),
};

/// The room key the direction override is stored under — the same
/// platform/room spelling the history records use.
String portraitRoomKey({required String siteId, required String roomId}) => '$siteId/$roomId';
