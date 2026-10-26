// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'theme_settings.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$AppThemeSettings extends AppThemeSettings {
  @override
  final DsSeed? seed;
  @override
  final DsThemeMode mode;
  @override
  final DsContrast contrast;
  @override
  final DsCornerStyle cornerStyle;
  @override
  final DsDensity? density;
  @override
  final TargetPlatform? platform;
  @override
  final DsSelectionStyle selectionStyle;
  @override
  final bool autoClashRule;
  @override
  final Color? dangerOverride;
  @override
  final Color? successOverride;
  @override
  final Color? warningOverride;
  @override
  final DsColorsAdjuster? adjustColors;
  @override
  final DsShadowsAdjuster? adjustShadows;
  @override
  final DsRadiiAdjuster? adjustRadii;
  @override
  final DsSizesAdjuster? adjustSizes;
  @override
  final String? fontFamily;
  @override
  final String? monoFontFamily;
  @override
  final String? displayFontFamily;
  @override
  final String? fontPackage;
  @override
  final String? monoFontPackage;
  @override
  final String? displayFontPackage;
  @override
  final DsMotion motion;
  @override
  final DsHaptics? haptics;
  @override
  final BuiltList<DsThemeExtension<dynamic>> extensions;

  factory _$AppThemeSettings([
    void Function(AppThemeSettingsBuilder)? updates,
  ]) => (AppThemeSettingsBuilder()..update(updates))._build();

  _$AppThemeSettings._({
    this.seed,
    required this.mode,
    required this.contrast,
    required this.cornerStyle,
    this.density,
    this.platform,
    required this.selectionStyle,
    required this.autoClashRule,
    this.dangerOverride,
    this.successOverride,
    this.warningOverride,
    this.adjustColors,
    this.adjustShadows,
    this.adjustRadii,
    this.adjustSizes,
    this.fontFamily,
    this.monoFontFamily,
    this.displayFontFamily,
    this.fontPackage,
    this.monoFontPackage,
    this.displayFontPackage,
    required this.motion,
    this.haptics,
    required this.extensions,
  }) : super._();
  @override
  AppThemeSettings rebuild(void Function(AppThemeSettingsBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  AppThemeSettingsBuilder toBuilder() =>
      AppThemeSettingsBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AppThemeSettings &&
        seed == other.seed &&
        mode == other.mode &&
        contrast == other.contrast &&
        cornerStyle == other.cornerStyle &&
        density == other.density &&
        platform == other.platform &&
        selectionStyle == other.selectionStyle &&
        autoClashRule == other.autoClashRule &&
        dangerOverride == other.dangerOverride &&
        successOverride == other.successOverride &&
        warningOverride == other.warningOverride &&
        adjustColors == other.adjustColors &&
        adjustShadows == other.adjustShadows &&
        adjustRadii == other.adjustRadii &&
        adjustSizes == other.adjustSizes &&
        fontFamily == other.fontFamily &&
        monoFontFamily == other.monoFontFamily &&
        displayFontFamily == other.displayFontFamily &&
        fontPackage == other.fontPackage &&
        monoFontPackage == other.monoFontPackage &&
        displayFontPackage == other.displayFontPackage &&
        motion == other.motion &&
        haptics == other.haptics &&
        extensions == other.extensions;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, seed.hashCode);
    _$hash = $jc(_$hash, mode.hashCode);
    _$hash = $jc(_$hash, contrast.hashCode);
    _$hash = $jc(_$hash, cornerStyle.hashCode);
    _$hash = $jc(_$hash, density.hashCode);
    _$hash = $jc(_$hash, platform.hashCode);
    _$hash = $jc(_$hash, selectionStyle.hashCode);
    _$hash = $jc(_$hash, autoClashRule.hashCode);
    _$hash = $jc(_$hash, dangerOverride.hashCode);
    _$hash = $jc(_$hash, successOverride.hashCode);
    _$hash = $jc(_$hash, warningOverride.hashCode);
    _$hash = $jc(_$hash, adjustColors.hashCode);
    _$hash = $jc(_$hash, adjustShadows.hashCode);
    _$hash = $jc(_$hash, adjustRadii.hashCode);
    _$hash = $jc(_$hash, adjustSizes.hashCode);
    _$hash = $jc(_$hash, fontFamily.hashCode);
    _$hash = $jc(_$hash, monoFontFamily.hashCode);
    _$hash = $jc(_$hash, displayFontFamily.hashCode);
    _$hash = $jc(_$hash, fontPackage.hashCode);
    _$hash = $jc(_$hash, monoFontPackage.hashCode);
    _$hash = $jc(_$hash, displayFontPackage.hashCode);
    _$hash = $jc(_$hash, motion.hashCode);
    _$hash = $jc(_$hash, haptics.hashCode);
    _$hash = $jc(_$hash, extensions.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'AppThemeSettings')
          ..add('seed', seed)
          ..add('mode', mode)
          ..add('contrast', contrast)
          ..add('cornerStyle', cornerStyle)
          ..add('density', density)
          ..add('platform', platform)
          ..add('selectionStyle', selectionStyle)
          ..add('autoClashRule', autoClashRule)
          ..add('dangerOverride', dangerOverride)
          ..add('successOverride', successOverride)
          ..add('warningOverride', warningOverride)
          ..add('adjustColors', adjustColors)
          ..add('adjustShadows', adjustShadows)
          ..add('adjustRadii', adjustRadii)
          ..add('adjustSizes', adjustSizes)
          ..add('fontFamily', fontFamily)
          ..add('monoFontFamily', monoFontFamily)
          ..add('displayFontFamily', displayFontFamily)
          ..add('fontPackage', fontPackage)
          ..add('monoFontPackage', monoFontPackage)
          ..add('displayFontPackage', displayFontPackage)
          ..add('motion', motion)
          ..add('haptics', haptics)
          ..add('extensions', extensions))
        .toString();
  }
}

class AppThemeSettingsBuilder
    implements Builder<AppThemeSettings, AppThemeSettingsBuilder> {
  _$AppThemeSettings? _$v;

  DsSeed? _seed;
  DsSeed? get seed => _$this._seed;
  set seed(DsSeed? seed) => _$this._seed = seed;

  DsThemeMode? _mode;
  DsThemeMode? get mode => _$this._mode;
  set mode(DsThemeMode? mode) => _$this._mode = mode;

  DsContrast? _contrast;
  DsContrast? get contrast => _$this._contrast;
  set contrast(DsContrast? contrast) => _$this._contrast = contrast;

  DsCornerStyle? _cornerStyle;
  DsCornerStyle? get cornerStyle => _$this._cornerStyle;
  set cornerStyle(DsCornerStyle? cornerStyle) =>
      _$this._cornerStyle = cornerStyle;

  DsDensity? _density;
  DsDensity? get density => _$this._density;
  set density(DsDensity? density) => _$this._density = density;

  TargetPlatform? _platform;
  TargetPlatform? get platform => _$this._platform;
  set platform(TargetPlatform? platform) => _$this._platform = platform;

  DsSelectionStyle? _selectionStyle;
  DsSelectionStyle? get selectionStyle => _$this._selectionStyle;
  set selectionStyle(DsSelectionStyle? selectionStyle) =>
      _$this._selectionStyle = selectionStyle;

  bool? _autoClashRule;
  bool? get autoClashRule => _$this._autoClashRule;
  set autoClashRule(bool? autoClashRule) =>
      _$this._autoClashRule = autoClashRule;

  Color? _dangerOverride;
  Color? get dangerOverride => _$this._dangerOverride;
  set dangerOverride(Color? dangerOverride) =>
      _$this._dangerOverride = dangerOverride;

  Color? _successOverride;
  Color? get successOverride => _$this._successOverride;
  set successOverride(Color? successOverride) =>
      _$this._successOverride = successOverride;

  Color? _warningOverride;
  Color? get warningOverride => _$this._warningOverride;
  set warningOverride(Color? warningOverride) =>
      _$this._warningOverride = warningOverride;

  DsColorsAdjuster? _adjustColors;
  DsColorsAdjuster? get adjustColors => _$this._adjustColors;
  set adjustColors(DsColorsAdjuster? adjustColors) =>
      _$this._adjustColors = adjustColors;

  DsShadowsAdjuster? _adjustShadows;
  DsShadowsAdjuster? get adjustShadows => _$this._adjustShadows;
  set adjustShadows(DsShadowsAdjuster? adjustShadows) =>
      _$this._adjustShadows = adjustShadows;

  DsRadiiAdjuster? _adjustRadii;
  DsRadiiAdjuster? get adjustRadii => _$this._adjustRadii;
  set adjustRadii(DsRadiiAdjuster? adjustRadii) =>
      _$this._adjustRadii = adjustRadii;

  DsSizesAdjuster? _adjustSizes;
  DsSizesAdjuster? get adjustSizes => _$this._adjustSizes;
  set adjustSizes(DsSizesAdjuster? adjustSizes) =>
      _$this._adjustSizes = adjustSizes;

  String? _fontFamily;
  String? get fontFamily => _$this._fontFamily;
  set fontFamily(String? fontFamily) => _$this._fontFamily = fontFamily;

  String? _monoFontFamily;
  String? get monoFontFamily => _$this._monoFontFamily;
  set monoFontFamily(String? monoFontFamily) =>
      _$this._monoFontFamily = monoFontFamily;

  String? _displayFontFamily;
  String? get displayFontFamily => _$this._displayFontFamily;
  set displayFontFamily(String? displayFontFamily) =>
      _$this._displayFontFamily = displayFontFamily;

  String? _fontPackage;
  String? get fontPackage => _$this._fontPackage;
  set fontPackage(String? fontPackage) => _$this._fontPackage = fontPackage;

  String? _monoFontPackage;
  String? get monoFontPackage => _$this._monoFontPackage;
  set monoFontPackage(String? monoFontPackage) =>
      _$this._monoFontPackage = monoFontPackage;

  String? _displayFontPackage;
  String? get displayFontPackage => _$this._displayFontPackage;
  set displayFontPackage(String? displayFontPackage) =>
      _$this._displayFontPackage = displayFontPackage;

  DsMotion? _motion;
  DsMotion? get motion => _$this._motion;
  set motion(DsMotion? motion) => _$this._motion = motion;

  DsHaptics? _haptics;
  DsHaptics? get haptics => _$this._haptics;
  set haptics(DsHaptics? haptics) => _$this._haptics = haptics;

  ListBuilder<DsThemeExtension<dynamic>>? _extensions;
  ListBuilder<DsThemeExtension<dynamic>> get extensions =>
      _$this._extensions ??= ListBuilder<DsThemeExtension<dynamic>>();
  set extensions(ListBuilder<DsThemeExtension<dynamic>>? extensions) =>
      _$this._extensions = extensions;

  AppThemeSettingsBuilder() {
    AppThemeSettings._defaults(this);
  }

  AppThemeSettingsBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _seed = $v.seed;
      _mode = $v.mode;
      _contrast = $v.contrast;
      _cornerStyle = $v.cornerStyle;
      _density = $v.density;
      _platform = $v.platform;
      _selectionStyle = $v.selectionStyle;
      _autoClashRule = $v.autoClashRule;
      _dangerOverride = $v.dangerOverride;
      _successOverride = $v.successOverride;
      _warningOverride = $v.warningOverride;
      _adjustColors = $v.adjustColors;
      _adjustShadows = $v.adjustShadows;
      _adjustRadii = $v.adjustRadii;
      _adjustSizes = $v.adjustSizes;
      _fontFamily = $v.fontFamily;
      _monoFontFamily = $v.monoFontFamily;
      _displayFontFamily = $v.displayFontFamily;
      _fontPackage = $v.fontPackage;
      _monoFontPackage = $v.monoFontPackage;
      _displayFontPackage = $v.displayFontPackage;
      _motion = $v.motion;
      _haptics = $v.haptics;
      _extensions = $v.extensions.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(AppThemeSettings other) {
    _$v = other as _$AppThemeSettings;
  }

  @override
  void update(void Function(AppThemeSettingsBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  AppThemeSettings build() => _build();

  _$AppThemeSettings _build() {
    _$AppThemeSettings _$result;
    try {
      _$result =
          _$v ??
          _$AppThemeSettings._(
            seed: seed,
            mode: BuiltValueNullFieldError.checkNotNull(
              mode,
              r'AppThemeSettings',
              'mode',
            ),
            contrast: BuiltValueNullFieldError.checkNotNull(
              contrast,
              r'AppThemeSettings',
              'contrast',
            ),
            cornerStyle: BuiltValueNullFieldError.checkNotNull(
              cornerStyle,
              r'AppThemeSettings',
              'cornerStyle',
            ),
            density: density,
            platform: platform,
            selectionStyle: BuiltValueNullFieldError.checkNotNull(
              selectionStyle,
              r'AppThemeSettings',
              'selectionStyle',
            ),
            autoClashRule: BuiltValueNullFieldError.checkNotNull(
              autoClashRule,
              r'AppThemeSettings',
              'autoClashRule',
            ),
            dangerOverride: dangerOverride,
            successOverride: successOverride,
            warningOverride: warningOverride,
            adjustColors: adjustColors,
            adjustShadows: adjustShadows,
            adjustRadii: adjustRadii,
            adjustSizes: adjustSizes,
            fontFamily: fontFamily,
            monoFontFamily: monoFontFamily,
            displayFontFamily: displayFontFamily,
            fontPackage: fontPackage,
            monoFontPackage: monoFontPackage,
            displayFontPackage: displayFontPackage,
            motion: BuiltValueNullFieldError.checkNotNull(
              motion,
              r'AppThemeSettings',
              'motion',
            ),
            haptics: haptics,
            extensions: extensions.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'extensions';
        extensions.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'AppThemeSettings',
          _$failedField,
          e.toString(),
        );
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
