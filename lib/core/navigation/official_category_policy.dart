import 'package:pure_live/core/models/live_area.dart';

abstract final class OfficialCategoryPolicy {
  static bool Function(LiveArea area)? isOfficialCategory;
  static Uri? Function(LiveArea area)? officialCategoryUri;

  static bool isOfficial(LiveArea area) => isOfficialCategory?.call(area) ?? false;

  static Uri? uriFor(LiveArea area) => officialCategoryUri?.call(area);
}
