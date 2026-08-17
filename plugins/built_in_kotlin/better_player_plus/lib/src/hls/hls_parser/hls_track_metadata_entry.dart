import 'package:better_player_plus/src/hls/hls_parser/variant_info.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

@immutable
class HlsTrackMetadataEntry {
  const HlsTrackMetadataEntry({this.groupId, this.name, this.variantInfos});

  /// The GROUP-ID value of this track, if the track is derived from an EXT-X-MEDIA tag. Null if the
  /// track is not derived from an EXT-X-MEDIA TAG.
  final String? groupId;

  /// The NAME value of this track, if the track is derived from an EXT-X-MEDIA tag. Null if the
  /// track is not derived from an EXT-X-MEDIA TAG.
  final String? name;

  /// The EXT-X-STREAM-INF tags attributes associated with this track. This field is non-applicable (and therefore empty) if this track is derived from an EXT-X-MEDIA tag.
  final List<VariantInfo>? variantInfos;

  @override
  bool operator ==(Object other) {
    if (other is HlsTrackMetadataEntry) {
      return other.groupId == groupId &&
          other.name == name &&
          const ListEquality<VariantInfo>().equals(other.variantInfos, variantInfos);
    }
    return false;
  }

  @override
  int get hashCode => Object.hash(groupId, name, variantInfos);
}
