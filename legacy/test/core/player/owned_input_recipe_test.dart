import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/player/core/playback_input_lease.dart';
import 'package:pure_live/core/player/core/playback_source.dart';
import 'package:pure_live/core/player/kernel/owned_input_opener.dart';

void main() {
  group('自有输入的元数据契约', () {
    OwnedPlaybackSource fc2Source() => OwnedPlaybackSource(
      identity: 'fc2-1234567',
      createInput: (CancelToken cancel) async => PlaybackInputLease(Uri.parse('owned://fc2-1234567'), () async {}),
    );

    test('放进 kMediaKitCustomInputKey 的东西，opener 必须认', () {
      expect(asOwnedInputRecipe(customInputMetadataOf(fc2Source())), isNotNull);
    });

    test('把 source 本身塞进去就是 FC2 线上那个报错', () {
      // Invalid argument (recipe): Not an owned-input recipe:
      // Instance of 'OwnedPlaybackSource'
      //
      // 元数据是 Map<String, Object?>，放错对象不是编译错误而是运行时拒绝，
      // 所以两端各自钉一条：这条钉"source 不被认"，上一条钉"工厂被认"。
      expect(asOwnedInputRecipe(fc2Source()), isNull);
    });

    test('身份为空的自有源在构造时就被拒，不会拖到打开那一刻', () {
      expect(
        () => OwnedPlaybackSource(identity: '  ', createInput: (CancelToken cancel) async => throw UnimplementedError()),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
