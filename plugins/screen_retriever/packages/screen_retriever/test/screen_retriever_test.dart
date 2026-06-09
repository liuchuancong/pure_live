import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:screen_retriever/screen_retriever.dart';

final _fakeDisplayJson = <String, dynamic>{
  'id': '0',
  'name': 'fakeDisplay',
  'size': {'width': 1920.0, 'height': 1080.0},
  'visiblePosition': {'dx': 0.0, 'dy': 0.0},
  'visibleSize': {'width': 1280.0, 'height': 720.0},
  'scaleFactor': 1,
};

class MockScreenRetrieverPlatform
    with MockPlatformInterfaceMixin
    implements ScreenRetrieverPlatform {
  @override
  Stream<Map<Object?, Object?>> get onScreenEventReceiver =>
      throw UnimplementedError();

  @override
  Future<Offset> getCursorScreenPoint() {
    return Future(() => const Offset(10.0, 10.0));
  }

  @override
  Future<List<Display>> getAllDisplays() {
    return Future(
      () => [
        Display.fromJson(_fakeDisplayJson),
        Display.fromJson(_fakeDisplayJson),
      ],
    );
  }

  @override
  Future<Display> getPrimaryDisplay() {
    return Future(
      () => Display.fromJson(_fakeDisplayJson),
    );
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final ScreenRetrieverPlatform initialPlatform =
      ScreenRetrieverPlatform.instance;

  test('$MethodChannelScreenRetriever is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelScreenRetriever>());
  });

  test('getCursorScreenPoint', () async {
    ScreenRetriever screenRetriever = ScreenRetriever.instance;
    MockScreenRetrieverPlatform fakePlatform = MockScreenRetrieverPlatform();
    ScreenRetrieverPlatform.instance = fakePlatform;

    expect(
      await screenRetriever.getCursorScreenPoint(),
      const Offset(10.0, 10.0),
    );
  });

  group(ScreenRetriever, () {
    MockScreenRetrieverPlatform fakePlatform = MockScreenRetrieverPlatform();
    ScreenRetrieverPlatform.instance = fakePlatform;
    final screenRetriever = ScreenRetriever.instance;

    test('should correctly parse output when calling getCursorScreenPoint',
        () async {
      Offset resultData = await screenRetriever.getCursorScreenPoint();
      expect(resultData.dx, 10);
      expect(resultData.dy, 10);
    });

    test('should correctly parse output when calling getPrimaryDisplay',
        () async {
      Display primaryDisplay = await screenRetriever.getPrimaryDisplay();

      expect(primaryDisplay.id, '0');
      expect(primaryDisplay.name, 'fakeDisplay');
      expect(primaryDisplay.size.width, 1920.0);
      expect(primaryDisplay.size.height, 1080.0);
      expect(primaryDisplay.visiblePosition!.dx, 0.0);
      expect(primaryDisplay.visiblePosition!.dy, 0.0);
      expect(primaryDisplay.visibleSize!.width, 1280.0);
      expect(primaryDisplay.visibleSize!.height, 720.0);
      expect(primaryDisplay.scaleFactor, 1);
    });

    test('should correctly parse output when calling getAllDisplays', () async {
      List<Display> displayList = await screenRetriever.getAllDisplays();

      expect(displayList.length, 2);
      expect(displayList[0].id, '0');
      expect(displayList[0].name, 'fakeDisplay');
      expect(displayList[0].size.width, 1920.0);
      expect(displayList[0].size.height, 1080.0);
      expect(displayList[0].visiblePosition!.dx, 0.0);
      expect(displayList[0].visiblePosition!.dy, 0.0);
      expect(displayList[0].visibleSize!.width, 1280.0);
      expect(displayList[0].visibleSize!.height, 720.0);
      expect(displayList[0].scaleFactor, 1);
    });
  });
}
