import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/features/room/portrait_rules.dart';
import 'package:pure_live/features/room/room_controller.dart' show RoomPresentation;
import 'package:pure_live/system/configuration/app_preferences.dart';

final AppPreferences _p = AppPreferences();

({double minimum, double middle, double maximum, double initial}) _stops() =>
    (minimum: 200, middle: 400, maximum: 600, initial: 400);

void main() {
  group('usesPortraitShape', () {
    test('a vertical source takes the sheet shape', () {
      expect(usesPortraitShape(_p, verticalSource: true), isTrue);
    });

    test('adaptation off or compatibility mode keeps the plain stack', () {
      expect(usesPortraitShape(AppPreferences(portraitAdapt: false), verticalSource: true), isFalse);
      expect(
        usesPortraitShape(AppPreferences(portraitLayoutMode: 'compatibility'), verticalSource: true),
        isFalse,
      );
    });

    test('a landscape source never takes it', () {
      expect(usesPortraitShape(_p, verticalSource: false), isFalse);
    });
  });

  group('applyPanelStops', () {
    test('the fixed-height answer pins all three stops at the middle', () {
      final stops = applyPanelStops(_stops(), AppPreferences(portraitAdaptiveHeight: false));
      expect(stops.minimum, 400);
      expect(stops.maximum, 400);
      expect(stops.initial, 400);
    });

    test('immersive opens at the floor', () {
      final stops = applyPanelStops(_stops(), AppPreferences(portraitLayoutMode: 'immersive'));
      expect(stops.initial, 200);
      expect(stops.maximum, 600);
    });

    test('balanced keeps the reference stops', () {
      final stops = applyPanelStops(_stops(), _p);
      expect((stops.minimum, stops.middle, stops.maximum, stops.initial), (200.0, 400.0, 600.0, 400.0));
    });
  });

  group('resolveFullscreenEntry', () {
    test('followSource turns the sideways request upright for a tall source', () {
      expect(
        resolveFullscreenEntry(RoomPresentation.fullscreen, preferences: _p, verticalSource: true),
        RoomPresentation.portraitFullscreen,
      );
    });

    test('landscape policy turns the upright request sideways', () {
      final p = AppPreferences(portraitFullscreenPolicy: 'landscape');
      expect(
        resolveFullscreenEntry(RoomPresentation.portraitFullscreen, preferences: p, verticalSource: true),
        RoomPresentation.fullscreen,
      );
    });

    test('followSystem leaves the caller\u2019s direction alone', () {
      final p = AppPreferences(portraitFullscreenPolicy: 'followSystem');
      expect(
        resolveFullscreenEntry(RoomPresentation.fullscreen, preferences: p, verticalSource: true),
        RoomPresentation.fullscreen,
      );
    });

    test('a remembered room outranks the policy, and forgetting ignores it', () {
      final remembered = resolveFullscreenEntry(
        RoomPresentation.fullscreen,
        preferences: _p,
        verticalSource: true,
        roomOverride: 'landscape',
      );
      expect(remembered, RoomPresentation.fullscreen);
      final notRemembered = resolveFullscreenEntry(
        RoomPresentation.fullscreen,
        preferences: AppPreferences(rememberPortraitRoomOverride: false),
        verticalSource: true,
        roomOverride: 'landscape',
      );
      expect(notRemembered, RoomPresentation.portraitFullscreen);
    });

    test('a landscape source always goes where asked', () {
      expect(
        resolveFullscreenEntry(
          RoomPresentation.fullscreen,
          preferences: _p,
          verticalSource: false,
          roomOverride: 'portrait',
        ),
        RoomPresentation.fullscreen,
      );
    });
  });

  group('portraitBarrage', () {
    test('followGlobal passes the room\u2019s own rows through', () {
      expect(portraitBarrage(_p, globalRows: 3), (rows: 3, area: null, hidden: false));
    });

    test('upperQuarter bounds the band without touching the row count', () {
      expect(portraitBarrage(AppPreferences(portraitDanmakuMode: 'upperQuarter'), globalRows: 3), (
        rows: 3,
        area: 0.25,
        hidden: false,
      ));
    });

    test('reduced halves the rows; hidden takes the overlay off', () {
      expect(portraitBarrage(AppPreferences(portraitDanmakuMode: 'reduced'), globalRows: 4), (
        rows: 2,
        area: null,
        hidden: false,
      ));
      expect(portraitBarrage(AppPreferences(portraitDanmakuMode: 'hidden'), globalRows: 4).hidden, isTrue);
    });
  });

  test('fullscreenOverrideOf names only the immersive entries', () {
    expect(fullscreenOverrideOf(RoomPresentation.portraitFullscreen), 'portrait');
    expect(fullscreenOverrideOf(RoomPresentation.fullscreen), 'landscape');
    expect(fullscreenOverrideOf(RoomPresentation.normal), isNull);
    expect(portraitRoomKey(siteId: 'douyin', roomId: '42'), 'douyin/42');
  });
}
