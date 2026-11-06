import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:pure_live/l10n/translations.dart';

/// The quality a Bilibili video opens with, as the source's numeric `qn`.
///
/// The menu always shows what the source actually served — a preference is a
/// request, not a promise, and the ladder a session is handed is the account's
/// own ceiling. These are the definitions the play endpoint names, with the
/// tiers a paid account reaches listed beside them; an unreachable one simply
/// never appears in the player's menu, and asking for it costs nothing, since
/// the request names the whole ladder and this number picks from it.
enum VodQualityChoice {
  /// `qn=64`: 720P, the ceiling of an anonymous session.
  p720(64),

  /// `qn=80`: 1080P, the first tier that needs a sign-in.
  p1080(80),

  /// `qn=112`: 1080P 高码率.
  p1080Plus(112),

  /// `qn=116`: 1080P60 高帧率.
  p1080P60(116),

  /// `qn=120`: 4K.
  p4k(120),

  /// `qn=125`: HDR 真彩.
  pHdr(125),

  /// `qn=126`: 杜比视界.
  pDolby(126),

  /// `qn=127`: 8K.
  p8k(127);

  VodQualityChoice(this.qn);

  /// The source's quality id.
  final int qn;

  /// The choice's short name.
  String label(Translations t) => switch (this) {
    VodQualityChoice.p720 => t.settings.vodQuality720,
    VodQualityChoice.p1080 => t.settings.vodQuality1080,
    VodQualityChoice.p1080Plus => t.settings.vodQuality1080Plus,
    VodQualityChoice.p1080P60 => t.settings.vodQuality1080P60,
    VodQualityChoice.p4k => t.settings.vodQuality4K,
    VodQualityChoice.pHdr => t.settings.vodQualityHdr,
    VodQualityChoice.pDolby => t.settings.vodQualityDolby,
    VodQualityChoice.p8k => t.settings.vodQuality8K,
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
      // A closed store falls back to the designed default.
    }
    // 1080P rather than 720P: a signed-in viewer's own player opens there, and
    // an account that cannot reach it is answered with its ceiling anyway.
    return VodQualityChoice.p1080;
  }

  /// Chooses [choice] and stores it for the next video.
  void select(VodQualityChoice choice) {
    if (choice == state) return;
    state = choice;
    try {
      unawaited(StoragePrefs.setInt(_qualityPref, choice.qn).catchError((Object _) => false));
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

/// The station's starting quality.
final vodQualityProvider = NotifierProvider<VodQualityController, VodQualityChoice>(VodQualityController.new);
