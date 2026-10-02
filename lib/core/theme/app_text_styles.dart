import 'package:pure_live/common/index.dart';
import 'package:pure_live/services/settings/font_settings_controller.dart';

class AppTextStyles {
  AppTextStyles._();

  static TextTheme get _base => Get.theme.textTheme;
  static ColorScheme get _colors => Get.theme.colorScheme;

  static FontSettingsController get _settings => SettingsService.to.font;

  // 🌟 1. 微型辅助文本 (Body Small)
  static TextStyle get t11 => (_base.bodySmall ?? const TextStyle()).copyWith(fontSize: _settings.fontSizeBodySmall.v);
  static TextStyle get t11Medium => t11.copyWith(fontWeight: FontWeight.w500);
  static TextStyle get t11Bold => t11.copyWith(fontWeight: FontWeight.w700);
  static TextStyle get t11Muted => t11.copyWith(color: Get.theme.hintColor.withValues(alpha: 0.6));
  static TextStyle get t11Primary => t11.copyWith(color: _colors.primary, fontWeight: FontWeight.w600);

  static TextStyle get t12 => (_base.bodySmall ?? const TextStyle()).copyWith(fontSize: _settings.fontSizeBodySmall.v);
  static TextStyle get t12Medium => t12.copyWith(fontWeight: FontWeight.w500);
  static TextStyle get t12Bold => t12.copyWith(fontWeight: FontWeight.w700);
  static TextStyle get t12Muted => t12.copyWith(color: Get.theme.hintColor);
  static TextStyle get t12Primary => t12.copyWith(color: _colors.primary, fontWeight: FontWeight.w600);
  static TextStyle get t12Error => t12.copyWith(color: _colors.error);

  // 🌟 2. 标准正文大小 (Body Medium)：直接动态绑定你设置的 fontSizeBodyMedium 变量
  static TextStyle get t13 =>
      (_base.bodyMedium ?? const TextStyle()).copyWith(fontSize: _settings.fontSizeBodyMedium.v);
  static TextStyle get t13Medium => t13.copyWith(fontWeight: FontWeight.w500);
  static TextStyle get t13SemiBold => t13.copyWith(fontWeight: FontWeight.w600);
  static TextStyle get t13Bold => t13.copyWith(fontWeight: FontWeight.w700);
  static TextStyle get t13Muted => t13.copyWith(color: Get.theme.hintColor);
  static TextStyle get t13Primary => t13.copyWith(color: _colors.primary);

  // 🌟 3. 加粗段落正文 (Body Large)：直接动态绑定你设置的 fontSizeBodyLarge 变量
  static TextStyle get t14 => (_base.bodyLarge ?? const TextStyle()).copyWith(fontSize: _settings.fontSizeBodyLarge.v);
  static TextStyle get t14Medium => t14.copyWith(fontWeight: FontWeight.w500);
  static TextStyle get t14SemiBold => t14.copyWith(fontWeight: FontWeight.w600);
  static TextStyle get t14Bold => t14.copyWith(fontWeight: FontWeight.w700);
  static TextStyle get t14Muted => t14.copyWith(color: Get.theme.hintColor);
  static TextStyle get t14Primary => t14.copyWith(color: _colors.primary);

  // 🌟 4. 中号卡片标题 (Title Medium)：直接动态绑定你设置的 fontSizeTitleMedium 变量
  static TextStyle get t15 =>
      (_base.titleMedium ?? const TextStyle()).copyWith(fontSize: _settings.fontSizeTitleMedium.v);
  static TextStyle get t15Medium => t15.copyWith(fontWeight: FontWeight.w500);
  static TextStyle get t15SemiBold => t15.copyWith(fontWeight: FontWeight.w600);
  static TextStyle get t15Bold => t15.copyWith(fontWeight: FontWeight.w700);
  static TextStyle get t15Primary => t15.copyWith(color: _colors.primary, fontWeight: FontWeight.w600);

  static TextStyle get t16 =>
      (_base.titleMedium ?? const TextStyle()).copyWith(fontSize: _settings.fontSizeTitleMedium.v);
  static TextStyle get t16Medium => t16.copyWith(fontWeight: FontWeight.w500);
  static TextStyle get t16SemiBold => t16.copyWith(fontWeight: FontWeight.w600);
  static TextStyle get t16Bold => t16.copyWith(fontWeight: FontWeight.w700);
  static TextStyle get t16Primary => t16.copyWith(color: _colors.primary);

  // 🌟 5. 大号顶栏标题 (Title Large)：直接动态绑定你设置的 fontSizeTitleLarge 变量
  static TextStyle get t18 =>
      (_base.titleLarge ?? const TextStyle()).copyWith(fontSize: _settings.fontSizeTitleLarge.v);
  static TextStyle get t18Medium => t18.copyWith(fontWeight: FontWeight.w500);
  static TextStyle get t18Bold => t18.copyWith(fontWeight: FontWeight.w700);

  static TextStyle get t20 =>
      (_base.titleLarge ?? const TextStyle()).copyWith(fontSize: _settings.fontSizeTitleLarge.v);
  static TextStyle get t20Medium => t20.copyWith(fontWeight: FontWeight.w500);
  static TextStyle get t20Bold => t20.copyWith(fontWeight: FontWeight.w700);

  static TextStyle get t24Bold => (_base.headlineSmall ?? const TextStyle()).copyWith(
    fontSize: (_settings.fontSizeTitleLarge.v * 1.2),
    fontWeight: FontWeight.w700,
  );
  static TextStyle get t32Bold => (_base.headlineLarge ?? const TextStyle()).copyWith(
    fontSize: (_settings.fontSizeTitleLarge.v * 1.6),
    fontWeight: FontWeight.w800,
  );
}
