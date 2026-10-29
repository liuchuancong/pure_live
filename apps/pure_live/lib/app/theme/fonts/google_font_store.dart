import 'package:flutter/foundation.dart' show debugPrint, immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart' show GoogleFonts;
import 'package:live_storage/live_storage.dart' show StoragePrefs;

import 'package:pure_live/app/theme/fonts/font_defaults.dart' show isGoogleFontFamily;

/// What the manager knows about Google's catalogue on this device.
@immutable
final class GoogleFontStoreState {
  /// Creates a reading.
  const GoogleFontStoreState({this.downloaded = const {}, this.active = const {}, this.failed = const {}});

  /// Families whose file is on this device, kept across boots.
  final Set<String> downloaded;

  /// Families being fetched right now.
  final Set<String> active;

  /// Families whose last fetch failed.
  final Set<String> failed;

  /// Whether [family]'s file is on this device.
  bool isDownloaded(String family) => downloaded.contains(family);

  /// Whether [family] is being fetched.
  bool isDownloading(String family) => active.contains(family);

  GoogleFontStoreState copyWith({Set<String>? downloaded, Set<String>? active, Set<String>? failed}) =>
      GoogleFontStoreState(
        downloaded: downloaded ?? this.downloaded,
        active: active ?? this.active,
        failed: failed ?? this.failed,
      );
}

/// Fetches Google families ahead of use and remembers which ones landed.
///
/// The files themselves belong to `google_fonts`, which caches them on the
/// device; this store only mirrors that record so the manager can tell a
/// family that is already here from one that still has to travel.
final class GoogleFontStore extends Notifier<GoogleFontStoreState> {
  static const String _key = 'fonts.google.downloaded';

  @override
  GoogleFontStoreState build() => GoogleFontStoreState(downloaded: {...?StoragePrefs.getStringList(_key)});

  /// Fetches [family] without applying it; false when the host could not be
  /// reached or the family is unknown.
  Future<bool> download(String family) async {
    if (state.isDownloading(family) || !isGoogleFontFamily(family)) return false;
    state = state.copyWith(active: {...state.active, family}, failed: {...state.failed}..remove(family));
    var ok = false;
    try {
      // Asking for the style is what queues the file; the package fetches it
      // once and keeps it for the next boot.
      GoogleFonts.getFont(family);
      await GoogleFonts.pendingFonts();
      ok = true;
    } on Object catch (error) {
      debugPrint('Google font $family could not be fetched: $error');
    }
    if (!ok) {
      state = state.copyWith(active: {...state.active}..remove(family), failed: {...state.failed, family});
      return false;
    }
    final next = {...state.downloaded, family};
    state = state.copyWith(downloaded: next, active: {...state.active}..remove(family));
    await StoragePrefs.setStringList(_key, next.toList());
    return true;
  }
}

/// The Google catalogue's download record.
final googleFontStoreProvider = NotifierProvider<GoogleFontStore, GoogleFontStoreState>(GoogleFontStore.new);
