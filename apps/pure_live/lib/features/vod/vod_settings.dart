import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:pure_live/l10n/translations.dart';

/// The quality a Bilibili video opens with, as the source's numeric `qn`.
///
/// The menu always shows what the source actually served — a preference is
/// a request, not a promise, and without a sign-in the endpoint may answer
/// 720P or lower. These are the renditions the play endpoint names.
enum VodQualityChoice {
  /// `qn=64`: 720P, the highest the progressive endpoint usually serves.
  p720(64),

  /// `qn=80`: 1080P.
  p1080(80),

  /// `qn=112`: 1080P+.
  p1080Plus(112),

  /// `qn=120`: 4K.
  p4k(120);

  VodQualityChoice(this.qn);

  /// The source's quality id.
  final int qn;

  /// The choice's short name.
  String label(Translations t) => switch (this) {
    VodQualityChoice.p720 => t.settings.vodQuality720,
    VodQualityChoice.p1080 => t.settings.vodQuality1080,
    VodQualityChoice.p1080Plus => t.settings.vodQuality1080Plus,
    VodQualityChoice.p4k => t.settings.vodQuality4K,
  };
}

/// The preference the starting quality is kept under.
const String _qualityPref = 'vod.quality.qn';

/// The station's starting-quality preference, read at boot and written on
/// every change; the video page asks the source for it when it opens a part.
final class VodQualityController extends Notifier<VodQualityChoice> {
  @override
  VodQualityChoice build() {
    try {
      final qn = StoragePrefs.getInt(_qualityPref);
      for (final choice in VodQualityChoice.values) {
        if (choice.qn == qn) return choice;
      }
    } on Object {
      // A closed store falls back to 720P.
    }
    return VodQualityChoice.p720;
  }

  /// Chooses [choice] and stores it for the next video.
  void select(VodQualityChoice choice) {
    if (choice == state) return;
    state = choice;
    try {
      unawaited(StoragePrefs.setInt(_qualityPref, choice.qn));
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

/// The station's starting quality.
final vodQualityProvider = NotifierProvider<VodQualityController, VodQualityChoice>(VodQualityController.new);
