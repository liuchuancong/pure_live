import 'package:live_iptv/src/model/epg_programme/epg_programme.dart';
import 'package:live_iptv/src/model/guide_channel/guide_channel.dart';

/// What a guide parser read.
///
/// Not stored as such: channels and programmes go into the library, and the
/// parse result is what an import reports back.
class ParsedGuide {
  /// A parse result.
  new({required List<GuideChannel> channels, required List<EpgProgramme> programmes})
    : channels = List.unmodifiable(channels),
      programmes = List.unmodifiable(programmes);

  /// The channels, in file order.
  final List<GuideChannel> channels;

  /// The programmes, in file order.
  final List<EpgProgramme> programmes;

  /// Whether the file carried nothing at all — a state worth reporting,
  /// because a guide that silently updates nothing looks like a working one.
  bool get isEmpty => channels.isEmpty && programmes.isEmpty;
}
