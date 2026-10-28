import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;

import 'package:pure_live/modules/hongguo/official/hongguo_official.dart' show HongguoRendition;

/// The key the learned decoder failures are kept under.
const String kHongguoDecoderLessonsKey = 'hongguo.decoderFailures';

/// One learned failure: a codec at a size this machine could not decode at
/// runtime. The reference keeps exactly this set (codec + width + height) and
/// lets it override the platform's own claims.
String hongguoDecoderKey(String codec, int? width, int? height) =>
    '${codec.trim().toLowerCase()}|${width ?? 0}|${height ?? 0}';

/// The codec-and-size pairs this machine failed to decode, persisted across
/// restarts — the reference's `native-decoder-lessons-v1` store.
final class HongguoDecoderLessonsController extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    try {
      return {...?StoragePrefs.getStringList(kHongguoDecoderLessonsKey)};
    } on Object {
      return const {};
    }
  }

  /// Whether [codec] at [width]x[height] already failed here.
  bool fails(String codec, int? width, int? height) => state.contains(hongguoDecoderKey(codec, width, height));

  /// Whether [rendition] already failed here.
  bool failsRendition(HongguoRendition rendition) => fails(rendition.codec, rendition.width, rendition.height);

  /// Learns that [rendition] did not decode; answers whether it was new.
  bool learn(HongguoRendition rendition) {
    final key = hongguoDecoderKey(rendition.codec, rendition.width, rendition.height);
    if (state.contains(key)) return false;
    state = {...state, key};
    _persist();
    return true;
  }

  /// Forgets every learned failure, as the reference's reset does.
  Future<void> reset() async {
    state = const {};
    _persist();
  }

  void _persist() {
    try {
      unawaited(StoragePrefs.setStringList(kHongguoDecoderLessonsKey, [...state]));
    } on Object {
      // A closed store loses the lessons; the next failure writes again.
    }
  }
}

/// The learned decoder failures.
final hongguoDecoderLessonsProvider = NotifierProvider<HongguoDecoderLessonsController, Set<String>>(
  HongguoDecoderLessonsController.new,
);
