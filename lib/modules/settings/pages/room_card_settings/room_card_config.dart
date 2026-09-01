import 'package:pure_live/common/index.dart';

class RoomCardConfig {
  // ===== 字体权重工具 =====
  static FontWeight getFontWeight(int index) {
    switch (index) {
      case 0:
        return FontWeight.w100;
      case 1:
        return FontWeight.w200;
      case 2:
        return FontWeight.w300;
      case 3:
        return FontWeight.w400;
      case 4:
        return FontWeight.w500;
      case 5:
        return FontWeight.w600;
      case 6:
        return FontWeight.w700;
      case 7:
        return FontWeight.w800;
      case 8:
        return FontWeight.w900;
      default:
        return FontWeight.w400;
    }
  }

  static int getFontWeightIndex(FontWeight weight) {
    if (weight == FontWeight.w100) return 0;
    if (weight == FontWeight.w200) return 1;
    if (weight == FontWeight.w300) return 2;
    if (weight == FontWeight.w400) return 3;
    if (weight == FontWeight.w500) return 4;
    if (weight == FontWeight.w600) return 5;
    if (weight == FontWeight.w700) return 6;
    if (weight == FontWeight.w800) return 7;
    if (weight == FontWeight.w900) return 8;
    return 3;
  }

  // ===== 封面转换 =====
  static BoxFit coverFit(int index) {
    switch (index) {
      case 0:
        return BoxFit.fill;
      case 1:
        return BoxFit.contain;
      case 2:
        return BoxFit.cover;
      case 3:
        return BoxFit.fitWidth;
      case 4:
        return BoxFit.fitHeight;
      case 5:
        return BoxFit.none;
      case 6:
        return BoxFit.scaleDown;
      default:
        return BoxFit.cover;
    }
  }

  static FilterQuality coverFilterQuality(int index) {
    switch (index) {
      case 0:
        return FilterQuality.low;
      case 1:
        return FilterQuality.medium;
      case 2:
        return FilterQuality.high;
      default:
        return FilterQuality.low;
    }
  }

  static Color coverPlaceholderColorValue(String hex) {
    if (hex.isEmpty) {
      final isDark = Get.isDarkMode;
      return isDark ? Colors.grey.shade900 : Colors.grey.shade100;
    }
    return HexColor(hex);
  }

  static Color coverFallbackColorValue(String hex) {
    if (hex.isEmpty) {
      final isDark = Get.isDarkMode;
      return isDark ? Colors.grey.shade900 : Colors.grey.shade100;
    }
    return HexColor(hex);
  }

  static Color platformBackgroundLightValue(String hex) {
    if (hex.isEmpty) return Colors.grey.shade200;
    return HexColor(hex);
  }

  static Color platformBackgroundDarkValue(String hex) {
    if (hex.isEmpty) return Colors.grey.shade800;
    return HexColor(hex);
  }

  static Color platformTextLightValue(String hex) {
    if (hex.isEmpty) return Colors.black87;
    return HexColor(hex);
  }

  static Color platformTextDarkValue(String hex) {
    if (hex.isEmpty) return Colors.white;
    return HexColor(hex);
  }

  static Color chipBackgroundColorValue(String hex) {
    if (hex.isEmpty) return Get.theme.primaryColor;
    return HexColor(hex);
  }

  static Color chipTextColorValue(String hex) {
    if (hex.isEmpty) return Colors.white;
    return HexColor(hex);
  }

  static Color badgeBackgroundValue(String hex) {
    if (hex.isEmpty) {
      final isDark = Get.isDarkMode;
      return isDark ? Colors.black.withValues(alpha: 0.58) : Colors.black.withValues(alpha: 0.48);
    }
    return HexColor(hex);
  }

  static Color badgeForegroundValue(String hex) {
    if (hex.isEmpty) return Colors.white;
    return HexColor(hex);
  }

  static Color metricBorderColorValue(String hex) {
    if (hex.isEmpty) return Get.theme.primaryColor.withValues(alpha: 0.12);
    return HexColor(hex);
  }

  static Color deleteButtonBackgroundColorValue(String hex) {
    if (hex.isEmpty) return Colors.black54;
    return HexColor(hex);
  }

  static Color deleteButtonIconColorValue(String hex) {
    if (hex.isEmpty) return Colors.white;
    return HexColor(hex);
  }

  static Color lightCardColorValue(String hex) {
    if (hex.isEmpty) return Colors.white;
    return HexColor(hex);
  }

  static Color darkCardColorValue(String hex) {
    if (hex.isEmpty) return Colors.grey.shade900;
    return HexColor(hex);
  }

  static Color lightTitleColorValue(String hex) {
    if (hex.isEmpty) return Colors.black87;
    return HexColor(hex);
  }

  static Color darkTitleColorValue(String hex) {
    if (hex.isEmpty) return Colors.white;
    return HexColor(hex);
  }

  static Color lightSubtitleColorValue(String hex) {
    if (hex.isEmpty) return Colors.grey.shade700;
    return HexColor(hex);
  }

  static Color darkSubtitleColorValue(String hex) {
    if (hex.isEmpty) return Colors.grey.shade400;
    return HexColor(hex);
  }
}
