import 'package:better_player_plus/src/hls/hls_parser/scheme_data.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

@immutable
class DrmInitData {
  const DrmInitData({this.schemeType, this.schemeData = const []});

  final List<SchemeData> schemeData;
  final String? schemeType;

  @override
  bool operator ==(Object other) {
    if (other is DrmInitData) {
      return schemeType == other.schemeType && const ListEquality<SchemeData>().equals(other.schemeData, schemeData);
    }
    return false;
  }

  @override
  int get hashCode => Object.hash(schemeType, schemeData);
}
