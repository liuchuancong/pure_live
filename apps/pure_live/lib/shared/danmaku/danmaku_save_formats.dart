import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;

import 'package:pure_live/shared/danmaku/danmaku_format.dart';

/// The key the saved-danmaku formats are kept under.
const String kDanmakuSaveFormatsKey = 'danmaku.saveFormats';

/// Which formats a saved danmaku set is written in.
///
/// One choice serves every surface that saves danmaku — a live recording's
/// chat file and a downloaded video's sidecar — because they save the same
/// thing. XML is the default and is never the only possible state: turning the
/// last format off leaves XML on, so a save always writes something.
final class DanmakuSaveFormatsController extends Notifier<Set<DanmakuFormat>> {
  @override
  Set<DanmakuFormat> build() {
    try {
      final saved = StoragePrefs.getString(kDanmakuSaveFormatsKey);
      if (saved == null || saved.trim().isEmpty) return _defaults;
      final formats = <DanmakuFormat>{};
      for (final id in saved.split(',')) {
        final format = DanmakuFormat.byId(id.trim());
        if (format != null) formats.add(format);
      }
      return formats.isEmpty ? _defaults : formats;
    } on Object {
      return _defaults;
    }
  }

  static const Set<DanmakuFormat> _defaults = {DanmakuFormat.xml};

  /// Turns [format] on or off; XML stays on when it would be the last one off.
  Future<void> toggle(DanmakuFormat format) async {
    final next = {...state};
    if (!next.remove(format)) next.add(format);
    if (next.isEmpty) next.add(DanmakuFormat.xml);
    state = next;
    await _save();
  }

  /// Replaces the whole choice, keeping at least one format.
  Future<void> setAll(Set<DanmakuFormat> formats) async {
    final next = formats.isEmpty ? _defaults : formats;
    state = next;
    await _save();
  }

  Future<void> _save() async {
    try {
      unawaited(StoragePrefs.setString(kDanmakuSaveFormatsKey, state.map((format) => format.id).join(',')));
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

/// The formats saved danmaku takes.
final danmakuSaveFormatsProvider = NotifierProvider<DanmakuSaveFormatsController, Set<DanmakuFormat>>(
  DanmakuSaveFormatsController.new,
);
