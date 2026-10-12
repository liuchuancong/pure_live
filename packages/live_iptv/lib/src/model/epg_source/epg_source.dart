import 'package:freezed_annotation/freezed_annotation.dart';

part 'epg_source.freezed.dart';
part 'epg_source.g.dart';

/// One guide source: a guide file the user imported, or a URL a sync can ask
/// again.
///
/// The fields keep the previous generation's names, so a source stored by it
/// reads back unchanged; [source] is the URL of a remote guide or the path of
/// an imported file, which is what [EpgSourceX.isRemote] tells apart.
// ignore_for_file: unnecessary_type_name_in_constructor -- Freezed
// factories cannot use the `new` shorthand.
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
