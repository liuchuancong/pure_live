import 'package:freezed_annotation/freezed_annotation.dart';

part 'iptv_group.freezed.dart';
part 'iptv_group.g.dart';

/// A channel group as the user ordered it.
///
/// The name is the key — it is what the playlist's `group-title` writes,
/// and a playlist is rewritten constantly while a library is kept. So a
/// group with no record here is not an error: it simply sorts after the
/// ones the user arranged, in the order its channels appear. [hidden]
/// takes the whole group out of the lists without touching the channels in
/// it, because "I never watch the shopping channels" is a statement about
/// a group, and un-hiding it must give back exactly what was there.
// ignore_for_file: unnecessary_type_name_in_constructor -- Freezed
// factories cannot use the `new` shorthand.
@freezed
abstract class IptvGroup with _$IptvGroup {
  /// A group record.
  const factory IptvGroup({
    required String name,
    @Default(0) int order,
    @Default(false) bool pinned,
    @Default(false) bool hidden,
  }) = _IptvGroup;

  /// Restores a group from JSON.
  factory IptvGroup.fromJson(Map<String, Object?> json) => _$IptvGroupFromJson(json);
}
