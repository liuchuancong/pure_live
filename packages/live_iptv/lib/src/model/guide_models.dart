import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'guide_models.freezed.dart';
part 'guide_models.g.dart';

/// The storage key of one guide channel.
///
/// `epg:<json [sourceId, channelId]>`, byte for byte what the previous
/// generation wrote: rooms store this key as their guide id, so a different
/// spelling would orphan every saved room's programme list. The JSON array
/// is what keeps the two parts unambiguous — a separator like `:` inside an
/// id cannot fake another key.
String epgChannelKey(String sourceId, String channelId) => 'epg:${jsonEncode([sourceId, channelId])}';

/// A guide channel as a parser read it, before it is stored.
// ignore_for_file: unnecessary_type_name_in_constructor -- Freezed
// factories cannot use the `new` shorthand.
@freezed
abstract class GuideChannel with _$GuideChannel {
  /// A parsed guide channel.
  const factory GuideChannel({
    /// The guide's own channel id: `tvg-id` in a playlist matches it.
    required String id,

    /// Every `display-name` of the channel, in file order.
    @Default(<String>[]) List<String> displayNames,

    /// The channel's icon, when the guide names one.
    String? iconUrl,
  }) = _GuideChannel;
}

/// One guide source: a guide file the user imported, or a URL a sync can ask
/// again.
///
/// The fields keep the previous generation's names, so a source stored by it
/// reads back unchanged; [source] is the URL of a remote guide or the path of
/// an imported file, which is what [isRemote] tells apart.
@freezed
abstract class EpgSource with _$EpgSource {
  /// A guide source.
  const factory EpgSource({
    /// The source's id.
    required String id,

    /// The name shown in the interface.
    required String name,

    /// An http(s) URL, or the path of an imported file.
    required String source,

    /// When it was last imported or synced successfully.
    DateTime? lastRefresh,

    /// When it was first imported.
    DateTime? createdAt,

    /// Whether a sync may refresh it by itself.
    @Default(true) bool autoUpdate,
  }) = _EpgSource;

  /// Restores a source from JSON.
  factory EpgSource.fromJson(Map<String, Object?> json) => _$EpgSourceFromJson(json);
}

/// Whether [source] is a network URL rather than a file path.
extension EpgSourceX on EpgSource {
  /// Whether this source can be synced over the network.
  bool get isRemote => source.startsWith('http://') || source.startsWith('https://');
}

/// One channel of a stored guide.
@freezed
abstract class EpgChannel with _$EpgChannel {
  /// A stored guide channel.
  const factory EpgChannel({
    /// The source the channel came from.
    required String sourceId,

    /// The guide's own channel id.
    required String channelId,

    /// The name shown when the guide gives no better one.
    @Default('') String displayName,

    /// The channel's icon.
    String? iconUrl,
  }) = _EpgChannel;

  /// Restores a channel from JSON.
  factory EpgChannel.fromJson(Map<String, Object?> json) => _$EpgChannelFromJson(json);
}

/// One programme of a guide channel.
///
/// The times are stored in UTC: guides disagree about zones — XMLTV spells
/// them in attributes, JSON guides in ISO strings with or without an offset
/// — and a stored local time would be wrong the moment the viewer travels.
@freezed
abstract class EpgProgramme with _$EpgProgramme {
  /// A programme.
  const factory EpgProgramme({
    /// The guide channel this programme belongs to (its `channelId`).
    required String channelId,

    /// When it starts, in UTC.
    required DateTime start,

    /// When it stops, in UTC.
    required DateTime stop,

    /// The source the guide came from.
    @Default('') String sourceId,

    /// Its title.
    @Default('') String title,

    /// Its subtitle, when the guide has one.
    String? subtitle,

    /// Its description.
    String? description,

    /// Its category or genre.
    String? category,

    /// The episode number, in whatever form the guide writes it.
    String? episodeNum,

    /// The provider's id for replaying this programme, when the guide
    /// carries one; catch-up with `vod`-style modes needs it.
    String? catchupId,
  }) = _EpgProgramme;

  /// Restores a programme from JSON.
  factory EpgProgramme.fromJson(Map<String, Object?> json) => _$EpgProgrammeFromJson(json);
}

/// The [EpgMapping.origin] this package writes when the matcher made the
/// mapping itself.
///
/// A top-level constant rather than a static on the class: the generated
/// code uses it as a constructor default, and a static member of the
/// abstract class is not in scope there.
const String epgAutoMappingOrigin = 'auto';

/// One channel-to-guide mapping.
///
/// [origin] records who made the mapping: an automatic one may be rewritten
/// by a later import, a hand-made one may not, and a locked one is final
/// even when the guide channel it names disappears — which is what stops a
/// user's deliberate choice from being undone by the next sync.
@freezed
abstract class EpgMapping with _$EpgMapping {
  /// A mapping.
  const factory EpgMapping({
    /// The playlist channel it belongs to.
    required String channelId,

    /// The guide channel's storage key.
    required String epgChannelKey,

    /// The playlist it came from.
    @Default('') String playlistId,

    /// The guide source the key belongs to.
    @Default('') String epgSourceId,

    /// Whether the user pinned it.
    @Default(false) bool locked,

    /// Who created it: [epgAutoMappingOrigin] for the matcher, anything else
    /// for a human.
    @Default(epgAutoMappingOrigin) String origin,
  }) = _EpgMapping;

  /// Restores a mapping from JSON.
  factory EpgMapping.fromJson(Map<String, Object?> json) => _$EpgMappingFromJson(json);
}

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

/// A room's guide id, as the IPTV site and the library both name it.
extension EpgChannelKeyX on EpgChannel {
  /// The storage key of this channel.
  String get key => epgChannelKey(sourceId, channelId);

  /// The name to show for this channel.
  String get primaryName => displayName.isEmpty ? channelId : displayName;
}
