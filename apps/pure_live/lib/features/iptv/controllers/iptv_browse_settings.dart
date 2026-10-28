import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_iptv/live_iptv.dart' show IptvLibrary, iptvGroupKeyOf;
import 'package:live_storage/live_storage.dart' show StoragePrefs;

import 'package:pure_live/features/iptv/controllers/iptv_controller.dart' show iptvLibraryProvider;

/// What the module's channel lists and zapping show: the four switches the
/// my-tv reference puts in its settings dialog — the dial number, the
/// direction the up and down keys walk, the corner clock — plus the guide's
/// one line about what is on.
///
/// Every field is read where it paints, so a change lands on the next frame
/// without any restart: the reference behaves the same way, and a viewer
/// flipping 换台反转 expects the very next key press to obey it.
@immutable
final class IptvBrowseSettings {
  /// Creates the browse settings.
  const IptvBrowseSettings({
    required this.showChannelNumber,
    required this.reverseChannels,
    required this.showClock,
    required this.showProgrammeLine,
  });

  /// The reference's defaults: number and clock on, the keys walking
  /// forwards, the programme line under the channel's name.
  static const IptvBrowseSettings standard = IptvBrowseSettings(
    showChannelNumber: true,
    reverseChannels: false,
    showClock: true,
    showProgrammeLine: true,
  );

  /// Whether a channel's dial number rides beside its name.
  final bool showChannelNumber;

  /// Whether the up and down keys swap — 换台反转.
  final bool reverseChannels;

  /// Whether the player draws its corner clock.
  final bool showClock;

  /// Whether the on-air programme is named under the channel.
  final bool showProgrammeLine;

  /// A copy with selected switches replaced.
  IptvBrowseSettings copyWith({
    bool? showChannelNumber,
    bool? reverseChannels,
    bool? showClock,
    bool? showProgrammeLine,
  }) => IptvBrowseSettings(
    showChannelNumber: showChannelNumber ?? this.showChannelNumber,
    reverseChannels: reverseChannels ?? this.reverseChannels,
    showClock: showClock ?? this.showClock,
    showProgrammeLine: showProgrammeLine ?? this.showProgrammeLine,
  );

  @override
  bool operator ==(Object other) =>
      other is IptvBrowseSettings &&
      other.showChannelNumber == showChannelNumber &&
      other.reverseChannels == reverseChannels &&
      other.showClock == showClock &&
      other.showProgrammeLine == showProgrammeLine;

  @override
  int get hashCode => Object.hash(showChannelNumber, reverseChannels, showClock, showProgrammeLine);
}

/// The keys the four switches are kept under.
const String kIptvShowNumberPrefsKey = 'iptv.browse.channelNumber';
const String kIptvReverseChannelsPrefsKey = 'iptv.browse.channelReversal';
const String kIptvShowClockPrefsKey = 'iptv.browse.clock';
const String kIptvShowProgrammePrefsKey = 'iptv.browse.programmeLine';

/// Owns the browse switches, one preference each.
final class IptvBrowseSettingsController extends Notifier<IptvBrowseSettings> {
  @override
  IptvBrowseSettings build() => IptvBrowseSettings(
    showChannelNumber: _flag(kIptvShowNumberPrefsKey, fallback: true),
    reverseChannels: _flag(kIptvReverseChannelsPrefsKey, fallback: false),
    showClock: _flag(kIptvShowClockPrefsKey, fallback: true),
    showProgrammeLine: _flag(kIptvShowProgrammePrefsKey, fallback: true),
  );

  static bool _flag(String key, {required bool fallback}) {
    try {
      return StoragePrefs.getBool(key) ?? fallback;
    } on Object {
      return fallback;
    }
  }

  Future<void> _write(String key, bool value) async {
    try {
      await StoragePrefs.setBool(key, value);
    } on Object {
      // A preference; a closed store loses it.
    }
  }

  /// Shows or hides the dial number beside a channel's name.
  Future<void> setShowChannelNumber({required bool value}) async {
    state = state.copyWith(showChannelNumber: value);
    await _write(kIptvShowNumberPrefsKey, value);
  }

  /// Walks the channel list forwards or backwards on the up and down keys.
  Future<void> setReverseChannels({required bool value}) async {
    state = state.copyWith(reverseChannels: value);
    await _write(kIptvReverseChannelsPrefsKey, value);
  }

  /// Draws or clears the player's corner clock.
  Future<void> setShowClock({required bool value}) async {
    state = state.copyWith(showClock: value);
    await _write(kIptvShowClockPrefsKey, value);
  }

  /// Names or stays quiet about the programme on air.
  Future<void> setShowProgrammeLine({required bool value}) async {
    state = state.copyWith(showProgrammeLine: value);
    await _write(kIptvShowProgrammePrefsKey, value);
  }

  /// Back to the reference's defaults.
  Future<void> reset() async {
    state = IptvBrowseSettings.standard;
    await _write(kIptvShowNumberPrefsKey, true);
    await _write(kIptvReverseChannelsPrefsKey, false);
    await _write(kIptvShowClockPrefsKey, true);
    await _write(kIptvShowProgrammePrefsKey, true);
  }
}

/// The module's browse switches.
final iptvBrowseSettingsProvider = NotifierProvider<IptvBrowseSettingsController, IptvBrowseSettings>(
  IptvBrowseSettingsController.new,
);

/// One group as the settings page lists it: its name, how many channels it
/// holds, and whether the module leaves it out of the lists and the zapping.
typedef IptvGroupRow = ({String name, int channels, bool hidden});

/// The library's groups with their hidden flags, so a whole group can be
/// switched off without opening the browser.
///
/// The library owns the fact ([IptvLibrary.setGroupHidden]); this mirrors it
/// and writes through the same seam, which is why un-hiding a group gives
/// back exactly the line-up that was there before.
final class IptvGroupsController extends Notifier<List<IptvGroupRow>> {
  @override
  List<IptvGroupRow> build() => _rows(ref.watch(iptvLibraryProvider).value);

  static List<IptvGroupRow> _rows(IptvLibrary? library) {
    if (library == null) return const [];
    final counts = <String, int>{};
    for (final channel in library.channels) {
      counts[iptvGroupKeyOf(channel)] = (counts[iptvGroupKeyOf(channel)] ?? 0) + 1;
    }
    return [
      for (final name in library.groupNames)
        (name: name, channels: counts[name] ?? 0, hidden: library.isGroupHidden(name)),
    ];
  }

  /// Switches [name] out of the lists and the zapping, or back into them.
  Future<void> setHidden(String name, {required bool hidden}) async {
    final library = ref.read(iptvLibraryProvider).value;
    if (library == null) return;
    await library.setGroupHidden(name, hidden: hidden);
    state = _rows(library);
  }
}

/// The library's groups, largest first as the library orders them.
final iptvGroupsProvider = NotifierProvider<IptvGroupsController, List<IptvGroupRow>>(IptvGroupsController.new);
