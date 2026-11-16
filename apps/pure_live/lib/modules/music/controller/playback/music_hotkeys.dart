import 'dart:async' show StreamSubscription, unawaited;
import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart' show SingleActivator, VoidCallback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:media_core_audio/media_core_audio.dart'
    show AudioPlaybackState, GlobalHotkeyEvent, MethodChannelGlobalHotkeysTransport, MusicTrack;
import 'package:pure_live/modules/music/controller/music_dislikes.dart'
    show MusicDislikesController, musicDislikesProvider;
import 'package:pure_live/modules/music/controller/music_library.dart'
    show MusicFavouritesController, musicFavouritesProvider;
import 'package:pure_live/modules/music/controller/music_playback.dart' show MusicPlayerController, musicPlayerProvider;

/// One shortcut the module answers to, the reference's HOTKEY_PLAYER set.
/// Window verbs (minimize, hide, close) and the desktop-lyric toggles are
/// the shell's, not the music module's — they stay out of this table.
enum MusicHotkeyAction {
  togglePlay,
  next,
  prev,
  seekBackward,
  seekForward,
  volumeUp,
  volumeDown,
  volumeMute,
  musicLove,
  musicUnlove,
  musicDislike;

  /// The stored key's suffix, the reference's `player_<action>` trimmed to
  /// the action so the config stays readable.
  String get storageName => switch (this) {
    MusicHotkeyAction.togglePlay => 'togglePlay',
    MusicHotkeyAction.next => 'next',
    MusicHotkeyAction.prev => 'prev',
    MusicHotkeyAction.seekBackward => 'seekBackward',
    MusicHotkeyAction.seekForward => 'seekForward',
    MusicHotkeyAction.volumeUp => 'volumeUp',
    MusicHotkeyAction.volumeDown => 'volumeDown',
    MusicHotkeyAction.volumeMute => 'volumeMute',
    MusicHotkeyAction.musicLove => 'musicLove',
    MusicHotkeyAction.musicUnlove => 'musicUnlove',
    MusicHotkeyAction.musicDislike => 'musicDislike',
  };

  static MusicHotkeyAction? fromStorageName(String name) => switch (name) {
    'togglePlay' => MusicHotkeyAction.togglePlay,
    'next' => MusicHotkeyAction.next,
    'prev' => MusicHotkeyAction.prev,
    'seekBackward' => MusicHotkeyAction.seekBackward,
    'seekForward' => MusicHotkeyAction.seekForward,
    'volumeUp' => MusicHotkeyAction.volumeUp,
    'volumeDown' => MusicHotkeyAction.volumeDown,
    'volumeMute' => MusicHotkeyAction.volumeMute,
    'musicLove' => MusicHotkeyAction.musicLove,
    'musicUnlove' => MusicHotkeyAction.musicUnlove,
    'musicDislike' => MusicHotkeyAction.musicDislike,
    _ => null,
  };
}

/// A key combination in the reference's own notation — `mod+alt+arrowleft`
/// — so a stored config stays diffable against the LX defaults.
@immutable
final class MusicHotkeyCombo {
  const MusicHotkeyCombo({required this.modifiers, required this.key});

  /// `mod` (Ctrl on Windows/Linux, Cmd on macOS), ctrl, alt, shift, in that
  /// stable order regardless of how the viewer pressed them.
  final Set<String> modifiers;

  /// The non-modifier key's LX name: `f5`, `arrowleft`, `0`, `-`, letters
  /// lower-cased.
  final String key;

  static const List<String> _modifierOrder = ['mod', 'ctrl', 'alt', 'shift'];

  /// Parses a combo string; returns null for anything unusable rather than
  /// throwing — a hand-edited store must not break the module's boot.
  static MusicHotkeyCombo? parse(String text) {
    final parts = text.toLowerCase().split('+').map((part) => part.trim()).where((part) => part.isNotEmpty);
    final modifiers = <String>{};
    String? key;
    for (final part in parts) {
      if (_modifierOrder.contains(part)) {
        modifiers.add(part);
      } else {
        // A second non-modifier part makes the combo ambiguous.
        if (key != null) return null;
        key = part;
      }
    }
    if (key == null) return null;
    return MusicHotkeyCombo(modifiers: modifiers, key: key);
  }

  String serialize() => [..._modifierOrder.where(modifiers.contains), key].join('+');

  /// The display form, the reference's formatHotKeyName: arrows become
  /// glyphs, `mod` names the platform's key, words capitalize.
  String display({bool appleMod = false}) {
    const arrows = {'arrowleft': '←', 'arrowright': '→', 'arrowup': '↑', 'arrowdown': '↓'};
    String part;
    if (arrows[key] case final arrow?) {
      part = arrow;
    } else if (key.length == 1) {
      part = key.toUpperCase();
    } else {
      part = key[0].toUpperCase() + key.substring(1);
    }
    final names = [
      for (final modifier in _modifierOrder.where(modifiers.contains)) modifierName(modifier, appleMod: appleMod),
    ];
    return [...names, part].join(' + ');
  }

  static String modifierName(String modifier, {required bool appleMod}) => switch (modifier) {
    'mod' => appleMod ? 'Command' : 'Ctrl',
    'ctrl' => 'Ctrl',
    'alt' => 'Alt',
    'shift' => 'Shift',
    _ => modifier,
  };

  /// The in-app accelerator for this combo; `mod` reads as control.
  SingleActivator get activator => SingleActivator(
    _logicalKey,
    control: modifiers.contains('mod') || modifiers.contains('ctrl'),
    alt: modifiers.contains('alt'),
    shift: modifiers.contains('shift'),
  );

  LogicalKeyboardKey get _logicalKey {
    const named = {
      'arrowleft': LogicalKeyboardKey.arrowLeft,
      'arrowright': LogicalKeyboardKey.arrowRight,
      'arrowup': LogicalKeyboardKey.arrowUp,
      'arrowdown': LogicalKeyboardKey.arrowDown,
      'space': LogicalKeyboardKey.space,
      'enter': LogicalKeyboardKey.enter,
      'escape': LogicalKeyboardKey.escape,
      'tab': LogicalKeyboardKey.tab,
      'backspace': LogicalKeyboardKey.backspace,
      'delete': LogicalKeyboardKey.delete,
      'home': LogicalKeyboardKey.home,
      'end': LogicalKeyboardKey.end,
      'pageup': LogicalKeyboardKey.pageUp,
      'pagedown': LogicalKeyboardKey.pageDown,
    };
    if (named[key] case final known?) return known;
    if (key.length == 1) {
      const digits = [
        LogicalKeyboardKey.digit0,
        LogicalKeyboardKey.digit1,
        LogicalKeyboardKey.digit2,
        LogicalKeyboardKey.digit3,
        LogicalKeyboardKey.digit4,
        LogicalKeyboardKey.digit5,
        LogicalKeyboardKey.digit6,
        LogicalKeyboardKey.digit7,
        LogicalKeyboardKey.digit8,
        LogicalKeyboardKey.digit9,
      ];
      final code = key.codeUnitAt(0);
      if (code >= 0x30 && code <= 0x39) return digits[code - 0x30];
      if (code >= 0x61 && code <= 0x7A) return LogicalKeyboardKey(LogicalKeyboardKey.keyA.keyId + code - 0x61);
    }
    if (key.length >= 2 && key.codeUnitAt(0) == 0x66) {
      final number = int.tryParse(key.substring(1));
      if (number != null && number >= 1 && number <= 19) {
        return LogicalKeyboardKey(LogicalKeyboardKey.f1.keyId + number - 1);
      }
    }
    return LogicalKeyboardKey.space;
  }

  @override
  bool operator ==(Object other) => other is MusicHotkeyCombo && other.serialize() == serialize();

  @override
  int get hashCode => serialize().hashCode;
}

const String _kMusicHotkeysKey = 'music.hotkeys';

/// The module's shortcut table, the reference's hotKey config. Assigning a
/// combo that another action already holds takes it over — one combo, one
/// action, the way a registration table has to behave.
final class MusicHotkeyConfig {
  const MusicHotkeyConfig({required this.enabled, required this.globalEnabled, required this.assignments});

  factory MusicHotkeyConfig.read() {
    var enabled = true;
    var globalEnabled = false;
    final assignments = <MusicHotkeyAction, MusicHotkeyCombo>{...standard};
    try {
      final raw = StoragePrefs.getString(_kMusicHotkeysKey);
      if (raw case final String text when text.isNotEmpty) {
        // A tolerant read: unknown action names and broken combos drop out.
        final Object? decoded = jsonDecode(text);
        if (decoded case {'enabled': final Object flag}) enabled = flag == true;
        if (decoded case {'globalEnabled': final Object flag}) globalEnabled = flag == true;
        if (decoded case {'assignments': final Map<Object?, Object?> pairs}) {
          for (final entry in pairs.entries) {
            final action = MusicHotkeyAction.fromStorageName('${entry.key}');
            final combo = entry.value == null ? null : MusicHotkeyCombo.parse('${entry.value}');
            if (action == null) continue;
            if (combo == null) {
              assignments.remove(action);
            } else {
              assignments[action] = combo;
            }
          }
        }
      }
    } on FormatException {
      // Keep the defaults; a damaged store is not worth a boot failure.
    }
    return MusicHotkeyConfig(enabled: enabled, globalEnabled: globalEnabled, assignments: assignments);
  }

  final bool enabled;

  /// Whether the table also registers with the OS, the reference's
  /// `hotKey.config.global.enable` — off by default, as there too. Meaningful
  /// only while [enabled]; the same table serves both surfaces.
  final bool globalEnabled;

  /// Action to combo; an absent action has no shortcut.
  final Map<MusicHotkeyAction, MusicHotkeyCombo> assignments;

  /// The defaults follow the reference's global table — Mod+Alt over the
  /// arrows and F5 — so a first run already has working shortcuts.
  static const Map<MusicHotkeyAction, MusicHotkeyCombo> standard = {
    MusicHotkeyAction.togglePlay: MusicHotkeyCombo(modifiers: {'mod', 'alt'}, key: 'f5'),
    MusicHotkeyAction.prev: MusicHotkeyCombo(modifiers: {'mod', 'alt'}, key: 'arrowleft'),
    MusicHotkeyAction.next: MusicHotkeyCombo(modifiers: {'mod', 'alt'}, key: 'arrowright'),
    MusicHotkeyAction.volumeUp: MusicHotkeyCombo(modifiers: {'mod', 'alt'}, key: 'arrowup'),
    MusicHotkeyAction.volumeDown: MusicHotkeyCombo(modifiers: {'mod', 'alt'}, key: 'arrowdown'),
  };

  static Future<void> write(MusicHotkeyConfig config) {
    final json = {
      'enabled': config.enabled,
      'globalEnabled': config.globalEnabled,
      'assignments': {for (final entry in config.assignments.entries) entry.key.storageName: entry.value.serialize()},
    };
    return StoragePrefs.setString(_kMusicHotkeysKey, jsonEncode(json));
  }

  MusicHotkeyConfig withAssignment(MusicHotkeyAction action, MusicHotkeyCombo? combo) {
    final assignments = <MusicHotkeyAction, MusicHotkeyCombo>{...this.assignments};
    if (combo == null) {
      assignments.remove(action);
    } else {
      assignments.removeWhere((_, held) => held == combo);
      assignments[action] = combo;
    }
    return MusicHotkeyConfig(enabled: enabled, globalEnabled: globalEnabled, assignments: assignments);
  }
}

/// The shortcut provider; writes go through storage then state so a
/// rebuilt app reads the same table.
final musicHotkeysProvider = NotifierProvider<MusicHotkeysController, MusicHotkeyConfig>(MusicHotkeysController.new);

final class MusicHotkeysController extends Notifier<MusicHotkeyConfig> {
  MethodChannelGlobalHotkeysTransport? _global;
  StreamSubscription<GlobalHotkeyEvent>? _globalEvents;
  bool _globalSupported = false;

  @override
  MusicHotkeyConfig build() {
    final config = MusicHotkeyConfig.read();
    unawaited(_bindGlobal(config));
    ref.onDispose(_unbindGlobal);
    return config;
  }

  Future<void> setEnabled({required bool value}) async {
    final next = MusicHotkeyConfig(enabled: value, globalEnabled: state.globalEnabled, assignments: state.assignments);
    state = next;
    await MusicHotkeyConfig.write(next);
    unawaited(_applyGlobal(next));
  }

  /// Whether the table also registers with the OS, the reference's global
  /// half. Turning it on registers now; turning it off releases the table.
  Future<void> setGlobalEnabled({required bool value}) async {
    final next = MusicHotkeyConfig(enabled: state.enabled, globalEnabled: value, assignments: state.assignments);
    state = next;
    await MusicHotkeyConfig.write(next);
    unawaited(_applyGlobal(next));
  }

  /// Sets or clears [action]'s combo; a combo another action held moves
  /// here. Returns the config actually stored.
  Future<MusicHotkeyConfig> assign(MusicHotkeyAction action, MusicHotkeyCombo? combo) async {
    final next = state.withAssignment(action, combo);
    state = next;
    await MusicHotkeyConfig.write(next);
    unawaited(_applyGlobal(next));
    return next;
  }

  Future<void> reset() async {
    const next = MusicHotkeyConfig(enabled: true, globalEnabled: false, assignments: MusicHotkeyConfig.standard);
    state = next;
    await MusicHotkeyConfig.write(next);
    unawaited(_applyGlobal(next));
  }

  /// Reaches the OS registration once; platforms without one keep every
  /// later call a no-op, the same degradation the overlay window has.
  Future<void> _bindGlobal(MusicHotkeyConfig config) async {
    final transport = _global ??= MethodChannelGlobalHotkeysTransport();
    _globalSupported = await transport.isSupported();
    if (!_globalSupported) return;
    _globalEvents ??= transport.events.listen((event) => unawaited(_dispatchGlobal(event)));
    await _applyGlobal(config);
  }

  Future<void> _dispatchGlobal(GlobalHotkeyEvent event) => runMusicHotkeyAction(
    MusicHotkeyTargets(
      player: ref.read(musicPlayerProvider.notifier),
      state: ref.read(musicPlayerProvider),
      favourites: ref.read(musicFavouritesProvider.notifier),
      isFavourite: (track) => ref.read(musicFavouritesProvider).contains(track),
      dislikes: ref.read(musicDislikesProvider.notifier),
    ),
    event.action,
  );

  Future<void> _unbindGlobal() async {
    await _globalEvents?.cancel();
    _globalEvents = null;
    await _global?.dispose();
    _global = null;
  }

  /// Replaces the OS table atomically — released entirely, then rebuilt —
  /// the way the reference re-registers on every config change.
  Future<void> _applyGlobal(MusicHotkeyConfig config) async {
    final transport = _global;
    if (transport == null || !_globalSupported) return;
    if (!config.enabled || !config.globalEnabled || config.assignments.isEmpty) {
      await transport.clear();
      return;
    }
    await transport.replace({
      for (final entry in config.assignments.entries) entry.value.serialize(): entry.key.storageName,
    });
  }
}

/// The players a shortcut acts on, read once per fire. Both the page's
/// `WidgetRef` and the controller's `Ref` can assemble one, which is what
/// keeps a single action switch serving the in-app accelerators and the OS
/// level fires.
final class MusicHotkeyTargets {
  const MusicHotkeyTargets({
    required this.player,
    required this.state,
    required this.favourites,
    required this.isFavourite,
    required this.dislikes,
  });

  final MusicPlayerController player;
  final AudioPlaybackState state;
  final MusicFavouritesController favourites;
  final bool Function(MusicTrack track) isFavourite;
  final MusicDislikesController dislikes;
}

/// Runs a shortcut's action against the player — the module's side of the
/// reference's key_event wiring. In-app accelerators call this from the page;
/// the OS-level fires arrive here from the global registration.
Future<void> runMusicHotkeyAction(MusicHotkeyTargets targets, String actionName) async {
  final action = MusicHotkeyAction.fromStorageName(actionName);
  if (action == null) return;
  final player = targets.player;
  final state = targets.state;
  switch (action) {
    case MusicHotkeyAction.togglePlay:
      await player.toggle();
    case MusicHotkeyAction.next:
      await player.next();
    case MusicHotkeyAction.prev:
      await player.previous();
    case MusicHotkeyAction.seekBackward:
      await player.seek(state.position - const Duration(seconds: 5));
    case MusicHotkeyAction.seekForward:
      await player.seek(state.position + const Duration(seconds: 5));
    case MusicHotkeyAction.volumeUp:
      await player.setVolume((state.volume + 0.05).clamp(0.0, 1.0));
    case MusicHotkeyAction.volumeDown:
      await player.setVolume((state.volume - 0.05).clamp(0.0, 1.0));
    case MusicHotkeyAction.volumeMute:
      await player.setMuted(muted: !state.muted);
    case MusicHotkeyAction.musicLove:
      final track = state.track;
      if (track != null && !targets.isFavourite(track)) {
        await targets.favourites.toggle(track);
      }
    case MusicHotkeyAction.musicUnlove:
      final track = state.track;
      if (track != null && targets.isFavourite(track)) {
        await targets.favourites.toggle(track);
      }
    case MusicHotkeyAction.musicDislike:
      final track = state.track;
      if (track != null) await targets.dislikes.toggle(track);
  }
}

/// The page-facing form; global fires go through [runMusicHotkeyAction] from
/// the controller.
Future<void> dispatchMusicHotkey(WidgetRef ref, MusicHotkeyAction action) => runMusicHotkeyAction(
  MusicHotkeyTargets(
    player: ref.read(musicPlayerProvider.notifier),
    state: ref.read(musicPlayerProvider),
    favourites: ref.read(musicFavouritesProvider.notifier),
    isFavourite: (track) => ref.read(musicFavouritesProvider).contains(track),
    dislikes: ref.read(musicDislikesProvider.notifier),
  ),
  action.storageName,
);

/// The module's in-app accelerator table from the current config — local
/// hotkeys work today; `local` is exactly what the reference splits from
/// its global (OS) registrations.
Map<SingleActivator, VoidCallback> musicHotkeyBindings(WidgetRef ref) {
  final config = ref.read(musicHotkeysProvider);
  if (!config.enabled) return const {};
  return {
    for (final entry in config.assignments.entries)
      entry.value.activator: () => unawaited(dispatchMusicHotkey(ref, entry.key)),
  };
}
