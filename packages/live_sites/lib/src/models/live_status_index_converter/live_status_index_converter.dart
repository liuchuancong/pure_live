// The converter constructor spells its class name; the shorthand cannot.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:live_sites/src/models/live_status/live_status.dart';

/// Reads/writes a [LiveStatus] by its index, matching the stored room JSON.
class LiveStatusIndexConverter extends JsonConverter<LiveStatus, int> {
  /// The converter.
  const LiveStatusIndexConverter();

  @override
  LiveStatus fromJson(int json) =>
      json >= 0 && json < LiveStatus.values.length ? LiveStatus.values[json] : LiveStatus.unknown;

  @override
  int toJson(LiveStatus object) => object.index;
}
