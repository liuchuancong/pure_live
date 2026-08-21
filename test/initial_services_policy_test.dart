import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/global/initial_services.dart';

void main() {
  group('heavy startup service policy', () {
    test('ordinary launches keep the recorder and FFmpeg cold', () {
      expect(
        InitialServices.shouldWarmRecorderOnStartup(autoStartOnBoot: false, serializedTasks: '[{"taskId":"1"}]'),
        isFalse,
      );
      expect(InitialServices.shouldWarmRecorderOnStartup(autoStartOnBoot: true, serializedTasks: null), isFalse);
      expect(InitialServices.shouldWarmRecorderOnStartup(autoStartOnBoot: true, serializedTasks: '[]'), isFalse);
    });

    test('explicit recorder continuation with saved tasks is restored', () {
      expect(
        InitialServices.shouldWarmRecorderOnStartup(autoStartOnBoot: true, serializedTasks: '[{"taskId":"1"}]'),
        isTrue,
      );
    });
  });
}
