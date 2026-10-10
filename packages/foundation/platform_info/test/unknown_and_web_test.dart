// Module: test/unknown_and_web_test.dart
// Purpose: Verify an unrecognised target gets the floor, not a browser's assumptions, and that web input is
// stated rather than guessed.
// Author: liuchuancong
// Created: 2026-10-10

import 'package:pure_live_platform_info/pure_live_platform_info.dart';
import 'package:test/test.dart';

void main() {
  group('test_platformInfo_unknown', () {
    test('test_capabilitiesFor_unknown_assumesNothing', () {
      final caps = capabilitiesFor(PlatformKind.unknown);

      expect(caps.hasSecureStorage, isFalse);
      expect(caps.supportsBackgroundPlayback, isFalse);
      expect(caps.supportsPictureInPicture, isFalse);
      expect(caps.supportsFileSystemAccess, isFalse);
      expect(caps.supportsMultiWindow, isFalse);
      expect(caps.supportsRemoteControl, isFalse);
      expect(caps.isTouchPrimary, isFalse);
      expect(caps.isTelevision, isFalse);
    });

    test('test_detectPlatform_unknownIsNotWeb_soWebBranchesDoNotFire', () {
      // Code that asks "am I on the web?" must not answer yes for a device it simply does not recognise:
      // that question chooses storage and file-system paths, and guessing wrong writes to the wrong place.
      final kind = detectPlatform(os: 'harmonyos');

      expect(kind, isNot(PlatformKind.web));
      expect(kind, PlatformKind.unknown);
    });

    test('test_detectPlatform_webIsStillExplicitOnly', () {
      expect(detectPlatform(os: 'anything', isWeb: true), PlatformKind.web);
      expect(detectPlatform(os: 'anything'), PlatformKind.unknown);
    });
  });

  group('test_platformInfo_webInputMode', () {
    test('test_capabilitiesFor_webTouchOverride_isTheOnlyWayToChangeWebInput', () {
      // The default stays touch-first because that is the majority case for a browser, and the host passes
      // what it actually measured for the desktop one.
      expect(capabilitiesFor(PlatformKind.web).isTouchPrimary, isTrue);
      expect(capabilitiesFor(PlatformKind.web, webIsTouchPrimary: false).isTouchPrimary, isFalse);
    });

    test('test_capabilitiesFor_webOverrideChangesOnlyTheInputFlag', () {
      final overridden = capabilitiesFor(PlatformKind.web, webIsTouchPrimary: false);

      expect(overridden.supportsPictureInPicture, PlatformCapabilities.web.supportsPictureInPicture);
      expect(overridden.hasSecureStorage, PlatformCapabilities.web.hasSecureStorage);
      expect(overridden.supportsFileSystemAccess, PlatformCapabilities.web.supportsFileSystemAccess);
      expect(overridden.isTelevision, isFalse);
    });

    test('test_capabilitiesFor_theOverrideIsIgnoredOffWeb', () {
      expect(capabilitiesFor(PlatformKind.windows, webIsTouchPrimary: true).isTouchPrimary, isFalse);
      expect(capabilitiesFor(PlatformKind.androidTv, webIsTouchPrimary: true).isTelevision, isTrue);
    });
  });

  group('test_platformInfo_matrix_istable', () {
    test('test_capabilitiesFor_nativeTvTargetsNeverClaimTouch', () {
      for (final kind in <PlatformKind>[PlatformKind.androidTv, PlatformKind.iOSTv]) {
        expect(capabilitiesFor(kind).isTouchPrimary, isFalse, reason: '$kind is d-pad driven');
        expect(capabilitiesFor(kind).isTelevision, isTrue);
      }
    });

    test('test_capabilitiesFor_iOSTvIsTheOnlyTargetWithoutRemoteControlOrPip', () {
      // tvOS allows no background audio and no LAN control of the app, so a feature that offers either has a
      // dead button on exactly one target; the matrix has to be able to say so.
      final caps = capabilitiesFor(PlatformKind.iOSTv);

      expect(caps.supportsBackgroundPlayback, isFalse);
      expect(caps.supportsRemoteControl, isFalse);
      expect(caps.supportsPictureInPicture, isFalse);
    });
  });
}
