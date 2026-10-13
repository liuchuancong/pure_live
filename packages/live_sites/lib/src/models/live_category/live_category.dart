import 'package:freezed_annotation/freezed_annotation.dart';

part 'live_category.freezed.dart';

/// A browsable category (a partition or board) as the shared contract
/// represents it. The parent grouping a platform shows lives in [parentId], so
/// the list stays flat rather than forcing every caller to know each site's
/// nesting depth. [icon] is a parsed URI, never a widget.
// ignore_for_file: unnecessary_type_name_in_constructor -- Freezed
// factories cannot use the `new` shorthand.
@freezed
abstract class LiveCategory with _$LiveCategory {
  /// Creates a category for [siteId] with the platform-specific [id].
  const factory LiveCategory({
    required String siteId,
    required String id,
    required String name,
    Uri? icon,
    String? parentId,
    int? sortOrder,
    @Default({}) Map<String, Object?> metadata,
  }) = _LiveCategory;
}
