// Module: test/design_tokens_test.dart
// Purpose: Pins the arithmetic every style adapter inherits: aimability, floors, reduce-motion and persistence.
// Author: liuchuancong
// Created: 2026-10-10

import 'dart:convert';

import 'package:pure_live_design/pure_live_design.dart';
import 'package:test/test.dart';

void main() {
  group('control sizes', () {
    test('test_controlKind_isAimableAtEveryModeItDefines', () {
      for (final kind in ControlKind.values) {
        for (final mode in InputMode.values) {
          expect(
            kind.isAimable(
              height: kind.heightFor(mode: mode),
              mode: mode,
            ),
            isTrue,
            reason: '$kind at $mode is smaller than its own stated minimum target',
          );
        }
      }
    });

    test('test_controlKind_remoteRowsAreTallerThanPhoneRows', () {
      expect(
        ControlKind.listItem.baseHeight(InputMode.remote),
        greaterThan(ControlKind.listItem.baseHeight(InputMode.touch)),
      );
      expect(
        ControlKind.toolbar.baseHeight(InputMode.remote),
        greaterThan(ControlKind.toolbar.baseHeight(InputMode.pointer)),
      );
    });

    test('test_controlKind_densityScalesWithoutTouchingText', () {
      final compact = ControlKind.button.heightFor(mode: InputMode.touch, density: Density.compact);
      final standard = ControlKind.button.heightFor(mode: InputMode.touch);
      final comfortable = ControlKind.button.heightFor(mode: InputMode.touch, density: Density.comfortable);

      expect(compact, lessThan(standard));
      expect(comfortable, greaterThan(standard));
    });

    test('test_density_forPlatformPicksADefaultTheUserCanOverride', () {
      expect(Density.forPlatform(PlatformProfile.androidTv), Density.comfortable);
      expect(Density.forPlatform(PlatformProfile.windows), Density.compact);
      expect(Density.forPlatform(PlatformProfile.androidPhone), Density.standard);
    });
  });

  group('text', () {
    test('test_typeRole_remoteFloorRaisesSmallTextWithoutClampingLargeText', () {
      // A TV at three metres: bodySmall is unreadable at 12, but a title is already big enough.
      expect(TypeRole.bodySmall.sizeFor(textScale: 1, mode: InputMode.remote), 16);
      expect(TypeRole.titleLarge.sizeFor(textScale: 1, mode: InputMode.remote), TypeRole.titleLarge.basePx);
    });

    test('test_typeRole_textScaleAboveOneIsAlwaysApplied', () {
      expect(TypeRole.bodyMedium.sizeFor(textScale: 1.6), TypeRole.bodyMedium.basePx * 1.6);
      expect(TypeRole.labelSmall.sizeFor(textScale: 3, mode: InputMode.remote), greaterThan(16));
    });

    test('test_resolveDesignTokens_refusesToShrinkTheUsersText', () {
      final tokens = resolveDesignTokens(platform: PlatformProfile.androidPhone, textScale: 0.7);

      expect(tokens.textScale, 1, reason: 'a style may not undo a user\'s font setting by going below 1');
    });

    test('test_designTokens_typeSizeFollowsTheResolvedInputMode', () {
      final tv = resolveDesignTokens(platform: PlatformProfile.androidTv);
      final phone = resolveDesignTokens(platform: PlatformProfile.androidPhone);

      expect(tv.input, InputMode.remote);
      expect(tv.typeSize(TypeRole.bodySmall), greaterThanOrEqualTo(16));
      expect(phone.typeSize(TypeRole.bodySmall), TypeRole.bodySmall.basePx);
    });
  });

  group('motion and focus', () {
    test('test_motionProfile_reducedZeroesDurationsInsteadOfShorteningThem', () {
      const reduced = MotionProfile.reduced;

      expect(reduced.instant, Duration.zero);
      expect(reduced.standard, Duration.zero);
      expect(reduced.slow, Duration.zero);
      expect(reduced.scaleOnFocusAllowed, isFalse);
    });

    test('test_motionProfile_reduceMotionBeatsTheMode', () {
      final resolved = MotionProfile.resolve(mode: InputMode.touch, reduceMotion: true);

      expect(resolved, same(MotionProfile.reduced));
    });

    test('test_motionProfile_remoteNeverScalesAFocusedControl', () {
      // Growth moves the rows under the focus, which on a d-pad reads as the interface flinching.
      expect(MotionProfile.forMode(InputMode.remote).scaleOnFocusAllowed, isFalse);
      expect(MotionProfile.forMode(InputMode.touch).scaleOnFocusAllowed, isTrue);
    });

    test('test_focusVisual_remoteRingIsThickerThanTheTouchOne', () {
      final remote = FocusVisual.forMode(InputMode.remote);
      final touch = FocusVisual.forMode(InputMode.touch);

      expect(remote.width, greaterThanOrEqualTo(3));
      expect(touch.width, lessThan(remote.width));
      expect(remote.isFindable, isTrue);
    });

    test('test_focusVisual_aThinLowContrastRingIsFlagged', () {
      const weak = FocusVisual(shape: FocusShape.glow, width: 1, offset: 0, color: ColorRole.focus, contrastRatio: 1.5);

      expect(weak.isFindable, isFalse);
    });
  });

  group('compatibility and persistence', () {
    test('test_legacyTokenNamesStillCarryTheShippedNumbers', () {
      // ui_kit renders with these; adopting the enums must not have restyled it by accident. Dart cannot fold
      // an enum field access into a constant, so the two spellings are asserted equal instead of linked.
      expect(PureLiveSpacing.xs, SpaceToken.space4.px);
      expect(PureLiveSpacing.sm, SpaceToken.space8.px);
      expect(PureLiveSpacing.md, SpaceToken.space16.px);
      expect(PureLiveSpacing.lg, SpaceToken.space24.px);
      expect(PureLiveSpacing.xl, SpaceToken.space32.px);
      expect(PureLiveSpacing.xxl, SpaceToken.space48.px);
      expect(PureLiveRadius.sm, RadiusToken.small.px);
      expect(PureLiveRadius.md, RadiusToken.medium.px);
      expect(PureLiveRadius.lg, RadiusToken.large.px);
      expect(PureLiveSpacing.md, 16);
      expect(PureLiveRadius.lg, 20);
    });

    test('test_appearanceSettings_roundTripsThroughJson', () {
      const settings = AppearanceSettings(
        styleName: 'yaru',
        brightness: 'dark',
        density: Density.compact,
        reduceMotion: true,
        textScale: 1.3,
        preferredInput: InputMode.remote,
        background: BackgroundConfig(kind: BackgroundKind.image, source: 'file:///bg.jpg', opacity: 0.5, blurSigma: 8),
      );

      final read = AppearanceSettings.parse(settings.encode());
      expect(read.styleName, 'yaru');
      expect(read.brightness, 'dark');
      expect(read.density, Density.compact);
      expect(read.reduceMotion, isTrue);
      expect(read.textScale, 1.3);
      expect(read.preferredInput, InputMode.remote);
      expect(read.background.kind, BackgroundKind.image);
      expect(read.background.source, 'file:///bg.jpg');
    });

    test('test_appearanceSettings_anUnknownStyleNameSurvivesTheRoundTrip', () {
      // A settings screen written before a style existed has to keep it selectable, so the style is a string.
      final read = AppearanceSettings.fromJson(<String, Object?>{'style': 'a-style-added-later'});

      expect(read.styleName, 'a-style-added-later');
      expect(read.density, isNull, reason: 'absent means "follow the platform", not "standard"');
    });

    test('test_appearanceSettings_defaultsAreTheMaterialLightSystemPick', () {
      const defaults = AppearanceSettings();

      expect(defaults.styleName, 'material');
      expect(defaults.brightness, 'system');
      expect(defaults.textScale, 1);
      expect(defaults.background.isActive, isFalse);
    });

    test('test_backgroundConfig_anUnknownKindReadsAsNoneRatherThanThrowing', () {
      final read = BackgroundConfig.fromJson(<String, Object?>{'kind': 'hologram', 'opacity': 0.4});

      expect(read.kind, BackgroundKind.none);
      expect(read.isActive, isFalse);
    });

    test('test_resolveDesignTokens_aRemoteAttachedPcUsesTheRemoteRules', () {
      // The platform is a pointer family; the input the user actually has is not.
      final tokens = resolveDesignTokens(platform: PlatformProfile.windows, preferredInput: InputMode.remote);

      expect(tokens.input, InputMode.remote);
      expect(tokens.height(ControlKind.listItem), greaterThan(ControlKind.listItem.baseHeight(InputMode.pointer)));
      expect(tokens.focus.width, greaterThanOrEqualTo(3));
    });

    test('test_designTokens_gapBetweenIsLargerForListRows', () {
      final tokens = resolveDesignTokens(platform: PlatformProfile.androidTv);

      expect(tokens.gapBetween(ControlKind.listItem), greaterThan(tokens.gapBetween(ControlKind.chip)));
      expect(jsonEncode(tokens.density.name), '"comfortable"');
    });
  });
}
