import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;

/// How the room page lays out a portrait stream (the reference's
/// `portraitLayoutMode`). [compatibility] keeps the regular 16:9 room page;
/// the other two give the picture a taller share, and [immersive] the
/// tallest.
enum PortraitLayoutMode {
  /// The picture and the chat share the page (the reference's balance).
  balanced,

  /// The picture keeps the larger share (the reference's panel starts at
  /// its lowest stop).
  immersive,

  /// The regular 16:9 room page.
  compatibility;

  /// The setting's value [name], else [balanced].
  static PortraitLayoutMode of(String? name) => values.asNameMap()[name] ?? balanced;
}

/// Which way the phone turns when a room goes to system fullscreen
/// (the reference's `FullscreenOrientation`, key `portraitFullscreenPolicy`).
enum PortraitFullscreenPolicy {
  /// Upright for a portrait stream, sideways for the rest.
  followSource,

  /// Whatever the phone is held as; the lock is released.
  followSystem,

  /// Always sideways.
  landscape;

  /// The setting's value [name], else [followSource].
  static PortraitFullscreenPolicy of(String? name) => values.asNameMap()[name] ?? followSource;
}

/// The viewer's preferences for portrait live streams.
typedef PortraitSettings = ({
  bool adaptation,
  bool adaptiveHeight,
  PortraitLayoutMode layoutMode,
  PortraitFullscreenPolicy fullscreenPolicy,
});

const PortraitSettings _defaults = (
  adaptation: true,
  adaptiveHeight: true,
  layoutMode: PortraitLayoutMode.balanced,
  fullscreenPolicy: PortraitFullscreenPolicy.followSource,
);

/// Owns the portrait-stream preferences, persisted under `playback.portrait*`.
/// The room page reads them when it lays a narrow room out; no other surface
/// changes the layout.
final class PortraitSettingsController extends Notifier<PortraitSettings> {
  /// Whether a portrait stream is detected and framed tall.
  static const String adaptationKey = 'playback.portraitAdaptation';

  /// Whether the tall frame takes an adaptive share of the page.
  static const String adaptiveHeightKey = 'playback.portraitAdaptiveHeight';

  /// The room page's layout mode for a portrait stream.
  static const String layoutModeKey = 'playback.portraitLayoutMode';

  /// Which way the phone turns when a room goes system-fullscreen.
  static const String fullscreenPolicyKey = 'playback.portraitFullscreenPolicy';

  @override
  PortraitSettings build() {
    try {
      return (
        adaptation: StoragePrefs.getBool(adaptationKey) ?? _defaults.adaptation,
        adaptiveHeight: StoragePrefs.getBool(adaptiveHeightKey) ?? _defaults.adaptiveHeight,
        layoutMode: PortraitLayoutMode.of(StoragePrefs.getString(layoutModeKey)),
        fullscreenPolicy: PortraitFullscreenPolicy.of(StoragePrefs.getString(fullscreenPolicyKey)),
      );
    } on Object {
      return _defaults;
    }
  }

  /// Turns portrait detection on or off; off keeps the regular 16:9 room.
  Future<void> setAdaptation({required bool value}) async {
    state = (
      adaptation: value,
      adaptiveHeight: state.adaptiveHeight,
      layoutMode: state.layoutMode,
      fullscreenPolicy: state.fullscreenPolicy,
    );
    await _write(() => StoragePrefs.setBool(adaptationKey, value));
  }

  /// Turns the adaptive height on or off; off keeps the regular 16:9 room.
  Future<void> setAdaptiveHeight({required bool value}) async {
    state = (
      adaptation: state.adaptation,
      adaptiveHeight: value,
      layoutMode: state.layoutMode,
      fullscreenPolicy: state.fullscreenPolicy,
    );
    await _write(() => StoragePrefs.setBool(adaptiveHeightKey, value));
  }

  /// Stores the layout mode; a stored value the choices do not know falls
  /// back to [PortraitLayoutMode.balanced].
  Future<void> setLayoutMode(PortraitLayoutMode mode) async {
    state = (
      adaptation: state.adaptation,
      adaptiveHeight: state.adaptiveHeight,
      layoutMode: mode,
      fullscreenPolicy: state.fullscreenPolicy,
    );
    await _write(() => StoragePrefs.setString(layoutModeKey, mode.name));
  }

  /// Stores the fullscreen orientation policy; an unknown stored value reads
  /// back as [PortraitFullscreenPolicy.followSource], as in the reference.
  Future<void> setFullscreenPolicy(PortraitFullscreenPolicy policy) async {
    state = (
      adaptation: state.adaptation,
      adaptiveHeight: state.adaptiveHeight,
      layoutMode: state.layoutMode,
      fullscreenPolicy: policy,
    );
    await _write(() => StoragePrefs.setString(fullscreenPolicyKey, policy.name));
  }

  /// Restores every portrait preference to its default (the reference's
  /// `resetPortraitStreamSettings`) and stores them. The remembered room
  /// framings (the room page's own `room.orientation` map) are reset by the
  /// same flow, through the room's choices provider.
  Future<void> resetToDefaults() async {
    state = _defaults;
    await _write(() async {
      await StoragePrefs.setBool(adaptationKey, _defaults.adaptation);
      await StoragePrefs.setBool(adaptiveHeightKey, _defaults.adaptiveHeight);
      await StoragePrefs.setString(layoutModeKey, _defaults.layoutMode.name);
      await StoragePrefs.setString(fullscreenPolicyKey, _defaults.fullscreenPolicy.name);
    });
  }

  Future<void> _write(Future<void> Function() write) async {
    try {
      await write();
    } on Object {
      // The choice is a preference; a closed store loses it.
    }
  }
}

/// The portrait-stream preferences.
final portraitSettingsProvider = NotifierProvider<PortraitSettingsController, PortraitSettings>(
  PortraitSettingsController.new,
);
