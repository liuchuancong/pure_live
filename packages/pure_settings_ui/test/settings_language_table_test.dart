// The dispatch table is the whole package's spine: every design language must
// name its theme, the five upstream borrowings must keep naming the rendering
// one by accident.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_settings_ui/src/pure/languages/forui_settings_language.dart';
import 'package:pure_settings_ui/src/pure/languages/glass_settings_language.dart';
import 'package:pure_settings_ui/src/pure/languages/neumorphic_settings_language.dart';
import 'package:pure_settings_ui/src/pure/languages/wind_settings_language.dart';
import 'package:pure_settings_ui/src/pure/settings_language.dart';
import 'package:pure_settings_ui/src/vendor/utils/platform_utils.dart';
import 'package:pure_uikit/pure_uikit.dart';

void main() {
  test('every design language declares a settings theme', () {
    for (final language in PureDesignLanguage.values) {
      expect(
        settingsLanguages.containsKey(language),
        isTrue,
        reason: 'no entry declares ${language.name}; add '
            'languages/${language.name}_settings_language.dart and list it',
      );
    }
    expect(settingsLanguages.length, PureDesignLanguage.values.length);
  });

  test('the five upstream borrowings name the rendering they borrow', () {
    expect(devicePlatformOf(PureDesignLanguage.material), DevicePlatform.android);
    expect(devicePlatformOf(PureDesignLanguage.cupertino), DevicePlatform.iOS);
    expect(devicePlatformOf(PureDesignLanguage.macos), DevicePlatform.macOS);
    expect(devicePlatformOf(PureDesignLanguage.fluent), DevicePlatform.windows);
    expect(devicePlatformOf(PureDesignLanguage.yaru), DevicePlatform.linux);
  });

  test('the four languages upstream cannot draw resolve to the pure style', () {
    for (final language in [
      PureDesignLanguage.forui,
      PureDesignLanguage.glass,
      PureDesignLanguage.neumorphic,
      PureDesignLanguage.wind,
    ]) {
      expect(devicePlatformOf(language), DevicePlatform.pure, reason: language.name);
    }
  });

  test('each entry is its own constant, never a shared branch', () {
    final entries = settingsLanguages.values.toList();
    for (var i = 0; i < entries.length; i++) {
      for (var j = i + 1; j < entries.length; j++) {
        expect(identical(entries[i], entries[j]), isFalse, reason: 'two languages share one theme');
      }
    }
  });

  test('the pure styles state the facts their docs claim', () {
    // Wind's WCard paints no surface, so it is the theme that turns the border
    // on; the other three cards are real surfaces of their own.
    expect(windSettingsLanguage.style.cardBordered, isTrue);
    for (final language in [foruiSettingsLanguage, glassSettingsLanguage, neumorphicSettingsLanguage]) {
      expect(language.style.cardBordered, isFalse, reason: language.runtimeType.toString());
    }
    // Forui and glass run their rows edge to edge and separate them with the
    // library's own divider.
    expect(foruiSettingsLanguage.style.cardPadding, EdgeInsets.zero);
    expect(glassSettingsLanguage.style.cardPadding, EdgeInsets.zero);
    expect(foruiSettingsLanguage.style.rowDividers, isTrue);
    expect(glassSettingsLanguage.style.rowDividers, isTrue);
    // A neumorphic card is its shadow: rows inset by the emboss width, and no
    // hairline — the depth does the grouping.
    expect(neumorphicSettingsLanguage.style.cardPadding, const EdgeInsets.all(PureSpacing.xs));
    expect(neumorphicSettingsLanguage.style.rowDividers, isFalse);
  });
}
