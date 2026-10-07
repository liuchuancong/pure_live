import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/domains/recorder/presentation/pages/local_player/recording_resume.dart';

Duration _s(int seconds) => Duration(seconds: seconds);

void main() {
  group('录像续播位置', () {
    test('16 秒的短片看到 14 秒，展开小窗要落回 14 秒', () {
      // 这就是用户报的那条：位置存对了，但旧的"离结尾 10 秒以内算看完"把 6 秒
      // 之后的一切吞掉，于是从头重播。
      expect(recordingResumeTarget(saved: _s(14), duration: _s(16)), _s(14));
    });

    test('只剩一秒才算看完，短片不再被当成看完', () {
      expect(recordingResumeTarget(saved: _s(15), duration: _s(16)), isNull);
      // 长片保持原来的十秒尾巴。
      expect(recordingResumeTarget(saved: _s(7195), duration: _s(7200)), isNull);
      expect(recordingResumeTarget(saved: _s(7180), duration: _s(7200)), _s(7180));
    });

    test('开头几秒不值得续播', () {
      expect(recordingResumeTarget(saved: _s(5), duration: _s(600)), isNull);
      expect(recordingResumeTarget(saved: _s(3), duration: _s(600)), isNull);
    });

    test('时长还没报回来时不猜位置', () {
      expect(recordingResumeTarget(saved: _s(30), duration: Duration.zero), isNull);
      expect(recordingResumeTarget(saved: null, duration: _s(600)), isNull);
    });

    test('中间位置照常续播', () {
      expect(recordingResumeTarget(saved: _s(3600), duration: _s(7200)), _s(3600));
    });
  });
}
