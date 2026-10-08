// Module: test/platform_info_test.dart
// Purpose: Verify platform detection and that each platform's capability matrix says what it should.
// Author: liuchuancong
// Created: 2026-10-08
import 'package:pure_live_platform_info/pure_live_platform_info.dart';
import 'package:test/test.dart';

void main() {
  group('detectPlatform', () {
    test('test_detectPlatform_androidPhoneAndTelevision', () {
      expect(detectPlatform(os: 'android'), PlatformKind.android);
      expect(detectPlatform(os: 'android', isTelevisionDevice: true), PlatformKind.androidTv);
    });

    test('test_detectPlatform_caseIsIgnored', () {
      expect(detectPlatform(os: 'Android'), PlatformKind.android);
      expect(detectPlatform(os: 'macOS'), PlatformKind.macOS);
    });

    test('test_detectPlatform_webWinsOverTheOsName', () {
      expect(detectPlatform(os: 'unknown', isWeb: true), PlatformKind.web);
    });

    test('test_detectPlatform_tvOsIsItsOwnTarget', () {
      expect(detectPlatform(os: 'ios', isTelevisionDevice: true), PlatformKind.iOSTv);
    });

    test('test_detectPlatform_unrecognisedName_fallsBackToWeb', () {
      // An unknown name is treated as the most restricted target, so a new platform cannot silently
      // inherit desktop file-system rights.
      expect(detectPlatform(os: 'symbian'), PlatformKind.web);
    });

    test('test_detectPlatform_desktops', () {
      expect(detectPlatform(os: 'windows'), PlatformKind.windows);
      expect(detectPlatform(os: 'linux'), PlatformKind.linux);
    });
  });

  group('capabilitiesFor', () {
    test('test_capabilitiesFor_webHasNoSecureStorageOrFileSystem', () {
      final caps = capabilitiesFor(PlatformKind.web);

      expect(caps.hasSecureStorage, isFalse);
      expect(caps.supportsFileSystemAccess, isFalse);
      expect(caps.supportsBackgroundPlayback, isFalse);
    });

    test('test_capabilitiesFor_androidTv_isTelevisionAndNotTouch', () {
      final caps = capabilitiesFor(PlatformKind.androidTv);

      expect(caps.isTelevision, isTrue);
      expect(caps.isTouchPrimary, isFalse);
      expect(caps.supportsRemoteControl, isTrue);
      expect(caps.supportsPictureInPicture, isFalse);
      expect(caps.supportsFileSystemAccess, isFalse);
    });

    test('test_capabilitiesFor_androidPhone_isTouchWithFileSystem', () {
      final caps = capabilitiesFor(PlatformKind.android);

      expect(caps.isTouchPrimary, isTrue);
      expect(caps.isTelevision, isFalse);
      expect(caps.supportsFileSystemAccess, isTrue);
      expect(caps.hasSecureStorage, isTrue);
    });

    test('test_capabilitiesFor_iosHasNoArbitraryFileSystem', () {
      final caps = capabilitiesFor(PlatformKind.ios);

      expect(caps.supportsFileSystemAccess, isFalse);
      expect(caps.hasSecureStorage, isTrue);
      expect(caps.supportsBackgroundPlayback, isTrue);
    });

    test('test_capabilitiesFor_iOSTv_cannotPlayInBackground', () {
      final caps = capabilitiesFor(PlatformKind.iOSTv);

      expect(caps.isTelevision, isTrue);
      expect(caps.supportsBackgroundPlayback, isFalse);
      expect(caps.supportsMultiWindow, isFalse);
    });

    test('test_capabilitiesFor_desktopTargetsShareOneMatrix', () {
      for (final kind in <PlatformKind>[PlatformKind.macOS, PlatformKind.windows, PlatformKind.linux]) {
        final caps = capabilitiesFor(kind);
        expect(caps.supportsMultiWindow, isTrue, reason: kind.name);
        expect(caps.supportsFileSystemAccess, isTrue, reason: kind.name);
        expect(caps.isTouchPrimary, isFalse, reason: kind.name);
        expect(caps.isTelevision, isFalse, reason: kind.name);
      }
    });

    test('test_capabilitiesFor_everyKind_isCovered', () {
      // The switch is exhaustive, so a new PlatformKind fails to compile rather than returning null.
      for (final kind in PlatformKind.values) {
        expect(capabilitiesFor(kind), isA<PlatformCapabilities>(), reason: kind.name);
      }
    });
  });
}
