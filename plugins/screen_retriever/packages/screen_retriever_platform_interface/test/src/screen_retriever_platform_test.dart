import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:screen_retriever_platform_interface/src/display.dart';
import 'package:screen_retriever_platform_interface/src/screen_retriever_method_channel.dart';
import 'package:screen_retriever_platform_interface/src/screen_retriever_platform.dart';

class MockScreenRetrieverPlatform
    with MockPlatformInterfaceMixin
    implements ScreenRetrieverPlatform {
  @override
  Stream<Map<Object?, Object?>> get onScreenEventReceiver =>
      throw UnimplementedError();

  @override
  Future<Offset> getCursorScreenPoint() {
    return Future(() => Offset.zero);
  }

  @override
  Future<Display> getPrimaryDisplay() {
    throw UnimplementedError();
  }

  @override
  Future<List<Display>> getAllDisplays() {
    throw UnimplementedError();
  }
}

void main() {
  final ScreenRetrieverPlatform initialPlatform =
      ScreenRetrieverPlatform.instance;

  test('$MethodChannelScreenRetriever is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelScreenRetriever>());
  });

  test('getCursorScreenPoint', () async {
    MockScreenRetrieverPlatform fakePlatform = MockScreenRetrieverPlatform();
    ScreenRetrieverPlatform.instance = fakePlatform;

    expect(
      await ScreenRetrieverPlatform.instance.getCursorScreenPoint(),
      Offset.zero,
    );
  });
}
