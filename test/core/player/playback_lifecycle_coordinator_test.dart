import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/player/core/playback_lifecycle_coordinator.dart';

/// 生命周期策略的状态机。
///
/// 这套代码在仓库里躺了很久没人构造过，所以这里钉的是它**被装配之后**的行为：
/// 纯音频模式退到后台要真关视频解码，回前台要恢复，而助眠会话不恢复。
void main() {
  late List<String> calls;
  late bool audioOnly;
  late bool sleepSession;
  late bool continueInBackground;
  late PlaybackLifecycleCoordinator coordinator;

  /// 装配形状与 `GlobalPlayerService` 一致：后台暂停那条腿是空端口。
  PlaybackLifecycleCoordinator build({Duration hiddenPauseDelay = Duration.zero}) {
    return PlaybackLifecycleCoordinator(
      pauseForLifecycle: () async {
        calls.add('pause');
        return null;
      },
      resumeFromLifecycle: (token) async {
        calls.add('resume');
        return true;
      },
      shouldContinueInBackground: () => continueInBackground,
      isAudioOnly: () => audioOnly,
      isSleepSessionActive: () => sleepSession,
      commitAudioOnlyPowerSaving: () async => calls.add('commitPowerSaving'),
      prepareAudioOnlyVideoRestore: () async => calls.add('prepareVideoRestore'),
      hiddenPauseDelay: hiddenPauseDelay,
    );
  }

  setUp(() {
    calls = <String>[];
    audioOnly = false;
    sleepSession = false;
    continueInBackground = true;
    coordinator = build();
  });

  tearDown(() async {
    await coordinator.dispose();
  });

  group('纯音频模式的后台省电', () {
    test('退到后台关掉视频解码，且只关一次', () async {
      audioOnly = true;

      await coordinator.handleState(AppLifecycleState.hidden);
      // Android 转屏/进 PiP 会连着发 hidden 与 paused，不能当成两次后台。
      await coordinator.handleState(AppLifecycleState.paused);

      expect(calls, <String>['commitPowerSaving']);
    });

    test('回前台恢复视频解码', () async {
      audioOnly = true;

      await coordinator.handleState(AppLifecycleState.hidden);
      calls.clear();
      await coordinator.handleState(AppLifecycleState.resumed);

      expect(calls, <String>['prepareVideoRestore']);
    });

    test('助眠会话回前台不恢复：它整夜都要省电', () async {
      audioOnly = true;
      sleepSession = true;

      await coordinator.handleState(AppLifecycleState.hidden);
      calls.clear();
      await coordinator.handleState(AppLifecycleState.resumed);

      expect(calls, isNot(contains('prepareVideoRestore')));
    });

    test('普通视频模式退到后台不动解码', () async {
      await coordinator.handleState(AppLifecycleState.hidden);

      expect(calls, isNot(contains('commitPowerSaving')),
          reason: '关不关解码是纯音频模式的决定，普通模式后台照常播画面');
    });
  });

  group('后台暂停那条腿', () {
    test('暂停端口交出空令牌时，回前台不会去恢复一个不存在的会话', () async {
      continueInBackground = false;

      await coordinator.handleState(AppLifecycleState.hidden);
      await coordinator.handleState(AppLifecycleState.resumed);

      expect(calls, contains('pause'));
      expect(calls, isNot(contains('resume')),
          reason: '令牌是 null 就说明什么都没暂停，恢复调用会打到别的会话上');
    });

    test('允许后台播放时连暂停端口都不碰', () async {
      continueInBackground = true;

      await coordinator.handleState(AppLifecycleState.hidden);

      expect(calls, isNot(contains('pause')));
    });
  });
}
