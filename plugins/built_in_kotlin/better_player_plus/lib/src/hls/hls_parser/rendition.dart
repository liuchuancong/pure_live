import 'package:better_player_plus/src/hls/hls_parser/format.dart';

class Rendition {
  Rendition({this.url, required this.format, required this.groupId, required this.name});

  /// The rendition's url, or null if the tag does not have a URI attribute.
  final Uri? url;

  /// Format information associated with this rendition.
  final Format format;

  /// The group to which this rendition belongs.
  final String? groupId;

  /// The name of the rendition.
  final String? name;
}
