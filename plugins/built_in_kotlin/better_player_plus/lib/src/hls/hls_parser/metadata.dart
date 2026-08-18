import 'package:better_player_plus/src/hls/hls_parser/hls_track_metadata_entry.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

@immutable
class Metadata {
  const Metadata(this.list);

  final List<HlsTrackMetadataEntry> list;

  @override
  bool operator ==(Object other) {
    if (other is Metadata) {
      return const ListEquality<HlsTrackMetadataEntry>().equals(other.list, list);
    }
    return false;
  }

  @override
  int get hashCode => list.hashCode;
}
