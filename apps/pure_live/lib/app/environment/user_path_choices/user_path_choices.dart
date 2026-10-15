import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_path_choices.freezed.dart';
part 'user_path_choices.g.dart';

/// The directories the user moved by hand, as persisted.
///
/// Keys are a `live_platform_path_provider` `StorageArea.name`; a value is an
/// absolute directory the user picked. An area is absent from the map exactly
/// when the user never moved it, which is what "the app's own default" means
/// on the path-management screen, and what 还原 deletes.
///
/// An unknown area name (a one removed from the enum, or a build that ships a
/// smaller layout) is kept rather than dropped: it costs nothing, and a
/// downgrade-and-upgrade round trip must not silently relocate someone's
/// recordings back onto their system drive.
// ignore_for_file: unnecessary_type_name_in_constructor -- Freezed
// factories cannot use the `new` shorthand.
@freezed
abstract class UserPathChoices with _$UserPathChoices {
  /// The chosen directories by area name.
  const factory UserPathChoices({
    /// Area name to absolute directory path; empty means the app defaults
    /// everywhere.
    @Default({}) Map<String, String> customByArea,
  }) = _UserPathChoices;

  /// Restores the choices from JSON.
  factory UserPathChoices.fromJson(Map<String, Object?> json) => _$UserPathChoicesFromJson(json);

  const UserPathChoices._();

  /// The directory the user chose for [areaId], null when they never moved it.
  String? pathFor(String areaId) => customByArea[areaId];

  /// [path] as the user's own answer for [areaId].
  UserPathChoices withPath(String areaId, String path) =>
      UserPathChoices(customByArea: {...customByArea, areaId: path});

  /// Back to the app's default for [areaId]; a no-op for an area that was
  /// never moved.
  UserPathChoices without(String areaId) =>
      UserPathChoices(customByArea: Map<String, String>.of(customByArea)..remove(areaId));

  /// Whether anything is customised — the "restore everything" affordance.
  bool get hasCustom => customByArea.isNotEmpty;
}
