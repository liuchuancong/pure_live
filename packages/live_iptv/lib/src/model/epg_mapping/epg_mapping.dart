import 'package:freezed_annotation/freezed_annotation.dart';

part 'epg_mapping.freezed.dart';
part 'epg_mapping.g.dart';

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
// ignore_for_file: unnecessary_type_name_in_constructor -- Freezed
// factories cannot use the `new` shorthand.
@freezed
abstract class EpgMapping with _$EpgMapping {
  /// A mapping.
  const factory EpgMapping({
    /// The playlist channel it belongs to.
    required String channelId,

    /// The guide channel's storage key, as `epgChannelKey` writes it.
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
