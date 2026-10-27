import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;

/// How a portrait stream fills the full-screen surface (the reference's
/// `portraitFullscreenDisplayMode`).
enum PortraitFullscreenMode {
  /// The whole picture, letterboxed.
  complete,

  /// The whole picture over a soft ambient backdrop.
  ambient,

  /// Fills more of the screen, cropping a little.
  balanced,

  /// Fills the screen, cropping the sides.
  cover;

  /// Parses a stored value; unknown answers [ambient], the reference default.
  static PortraitFullscreenMode of(String? value) => values.where((mode) => mode.name == value).firstOrNull ?? ambient;
}

/// Where the flying danmaku may sit in portrait full screen (the reference's
/// `portraitDanmakuMode`).
enum PortraitDanmakuMode {
  /// The room's own area.
  followGlobal,

  /// Only the upper quarter.
  upperQuarter,

  /// Half the room's area.
  reduced,

  /// No flying danmaku.
  hidden;

  /// Parses a stored value; unknown answers [followGlobal].
  static PortraitDanmakuMode of(String? value) =>
      values.where((mode) => mode.name == value).firstOrNull ?? followGlobal;
}

/// A room's saved portrait choice.
typedef PortraitRoomOverride = ({PortraitFullscreenMode display, PortraitDanmakuMode danmaku});

/// The portrait-fullscreen choices: the two global modes, whether a room's
/// own choice is remembered, the diagnostics overlay and every remembered
/// room override.
typedef PortraitFullscreenState = ({
  PortraitFullscreenMode display,
  PortraitDanmakuMode danmaku,
  bool rememberRoom,
  bool diagnostics,
  Map<String, PortraitRoomOverride> overrides,
});

const PortraitFullscreenState _defaults = (
  display: PortraitFullscreenMode.ambient,
  danmaku: PortraitDanmakuMode.followGlobal,
  rememberRoom: true,
  diagnostics: false,
  overrides: {},
);

/// The choice a room opens with: its saved override when remembering is on,
/// else the current global modes.
extension PortraitFullscreenChoice on PortraitFullscreenState {
  /// The display and danmaku modes for [roomKey].
  ({PortraitFullscreenMode display, PortraitDanmakuMode danmaku}) modeFor(String roomKey) {
    final saved = rememberRoom ? overrides[roomKey] : null;
    return (display: saved?.display ?? display, danmaku: saved?.danmaku ?? danmaku);
  }
}

/// The pref keys.
const String _displayKey = 'playback.portraitFullscreenDisplayMode';
const String _danmakuKey = 'playback.portraitDanmakuMode';
const String _rememberKey = 'playback.rememberPortraitRoomOverride';
const String _diagnosticsKey = 'playback.showPortraitDiagnostics';
const String _overridesKey = 'playback.portraitRoomOverrides';

/// Owns the portrait-fullscreen settings and the per-room map.
final class PortraitFullscreenController extends Notifier<PortraitFullscreenState> {
  @override
  PortraitFullscreenState build() {
    try {
      return (
        display: PortraitFullscreenMode.of(StoragePrefs.getString(_displayKey)),
        danmaku: PortraitDanmakuMode.of(StoragePrefs.getString(_danmakuKey)),
        rememberRoom: StoragePrefs.getBool(_rememberKey) ?? _defaults.rememberRoom,
        diagnostics: StoragePrefs.getBool(_diagnosticsKey) ?? _defaults.diagnostics,
        overrides: _readOverrides(),
      );
    } on Object {
      return _defaults;
    }
  }

  static Map<String, PortraitRoomOverride> _readOverrides() {
    try {
      final raw = StoragePrefs.getString(_overridesKey);
      if (raw == null || raw.trim().isEmpty) return const {};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      final result = <String, PortraitRoomOverride>{};
      decoded.forEach((key, value) {
        if (key is! String || value is! Map) return;
        result[key] = (
          display: PortraitFullscreenMode.of(value['display'] as String?),
          danmaku: PortraitDanmakuMode.of(value['danmaku'] as String?),
        );
      });
      return result;
    } on Object {
      return const {};
    }
  }

  /// The mode this room opens with: its saved override when remembering is
  /// on, else the global choice.
  ({PortraitFullscreenMode display, PortraitDanmakuMode danmaku}) modeFor(String roomKey) {
    final saved = state.rememberRoom ? state.overrides[roomKey] : null;
    return (display: saved?.display ?? state.display, danmaku: saved?.danmaku ?? state.danmaku);
  }

  /// Stores the in-room choice: the global default always follows, and a
  /// room override is written only while remembering is on.
  Future<void> remember(String roomKey, PortraitRoomOverride choice) async {
    final overrides = {...state.overrides, if (state.rememberRoom && roomKey.isNotEmpty) roomKey: choice};
    state = (
      display: choice.display,
      danmaku: choice.danmaku,
      rememberRoom: state.rememberRoom,
      diagnostics: state.diagnostics,
      overrides: overrides,
    );
    await _writeString(_displayKey, choice.display.name);
    await _writeString(_danmakuKey, choice.danmaku.name);
    await _writeOverrides(overrides);
  }

  /// Flips the remember switch; turning it off drops every saved room choice.
  Future<void> setRemember({required bool value}) async {
    state = (
      display: state.display,
      danmaku: state.danmaku,
      rememberRoom: value,
      diagnostics: state.diagnostics,
      overrides: value ? state.overrides : const {},
    );
    await _writeBool(_rememberKey, value);
    if (!value) await _writeOverrides(const {});
  }

  /// Flips the diagnostics overlay.
  Future<void> setDiagnostics({required bool value}) async {
    state = (
      display: state.display,
      danmaku: state.danmaku,
      rememberRoom: state.rememberRoom,
      diagnostics: value,
      overrides: state.overrides,
    );
    await _writeBool(_diagnosticsKey, value);
  }

  /// Restores every portrait-fullscreen preference and clears overrides.
  Future<void> resetToDefaults() async {
    state = _defaults;
    await _writeString(_displayKey, _defaults.display.name);
    await _writeString(_danmakuKey, _defaults.danmaku.name);
    await _writeBool(_rememberKey, _defaults.rememberRoom);
    await _writeBool(_diagnosticsKey, _defaults.diagnostics);
    await _writeOverrides(const {});
  }

  /// Clears every room override, keeping the two global modes.
  Future<void> clearOverrides() async {
    state = (
      display: state.display,
      danmaku: state.danmaku,
      rememberRoom: state.rememberRoom,
      diagnostics: state.diagnostics,
      overrides: const {},
    );
    await _writeOverrides(const {});
  }

  Future<void> _writeOverrides(Map<String, PortraitRoomOverride> overrides) async {
    try {
      await StoragePrefs.setString(
        _overridesKey,
        jsonEncode({
          for (final entry in overrides.entries)
            entry.key: {'display': entry.value.display.name, 'danmaku': entry.value.danmaku.name},
        }),
      );
    } on Object {
      // A preference; a closed store loses it.
    }
  }

  Future<void> _writeString(String key, String value) async {
    try {
      await StoragePrefs.setString(key, value);
    } on Object {
      // A preference; a closed store loses it.
    }
  }

  Future<void> _writeBool(String key, bool value) async {
    try {
      await StoragePrefs.setBool(key, value);
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

/// The portrait-fullscreen choices.
final portraitFullscreenProvider = NotifierProvider<PortraitFullscreenController, PortraitFullscreenState>(
  PortraitFullscreenController.new,
);
