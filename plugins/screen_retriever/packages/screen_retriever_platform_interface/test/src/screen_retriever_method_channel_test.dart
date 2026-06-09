import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:screen_retriever_platform_interface/src/screen_retriever_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelScreenRetriever platform = MethodChannelScreenRetriever();
  const MethodChannel channel = MethodChannel(
    'dev.leanflutter.plugins/screen_retriever',
  );

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'getCursorScreenPoint':
            return {'dx': 0.0, 'dy': 0.0};
        }
        return '42';
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getCursorScreenPoint', () async {
    expect(await platform.getCursorScreenPoint(), Offset.zero);
  });
}
