import 'package:live_shell/live_shell.dart';
import 'package:test/test.dart';

void main() {
  List<TrayEntry> menu({String recording = '开始录制', bool? pauseChecked = false, int? liveCount}) => [
    const TrayHeading(id: 'status', label: '纯粹直播'),
    const TrayDivider(),
    TrayAction(id: 'record', label: recording, badge: liveCount == null ? null : '$liveCount 路'),
    TrayAction(id: 'pause', label: '暂停', checked: pauseChecked),
    const TraySubmenu(
      id: 'sources',
      label: '录制目标',
      children: [
        TrayAction(id: 'src:cctv1', label: 'CCTV-1'),
        TrayAction(id: 'src:cctv5', label: 'CCTV-5'),
      ],
    ),
    const TrayDivider(),
    const TrayAction(id: 'quit', label: '退出'),
  ];

  group('trayMenuNeedsRebuild', () {
    test('an identical menu built from new objects is not a change', () {
      expect(trayMenuNeedsRebuild(menu(), menu()), isFalse, reason: 'rebuilding would close the open menu');
    });

    test('a label change is a change', () {
      expect(trayMenuNeedsRebuild(menu(), menu(recording: '停止录制')), isTrue);
    });

    test('a check state or a badge change is a change', () {
      expect(trayMenuNeedsRebuild(menu(), menu(pauseChecked: true)), isTrue);
      expect(trayMenuNeedsRebuild(menu(), menu(liveCount: 3)), isTrue);
    });

    test('a change nested inside a submenu is still found', () {
      final before = menu();
      final after = [
        ...before.take(5),
        const TraySubmenu(
          id: 'sources',
          label: '录制目标',
          children: [
            TrayAction(id: 'src:cctv1', label: 'CCTV-1 综合'),
            TrayAction(id: 'src:cctv5', label: 'CCTV-5'),
          ],
        ),
        ...before.skip(6),
      ];

      expect(trayMenuNeedsRebuild(before, after), isTrue);
    });

    test('a row becoming unclickable is a change', () {
      final before = menu();
      final after = [
        ...before.take(2),
        const TrayAction(id: 'record', label: '开始录制', enabled: false),
        ...before.skip(3),
      ];

      expect(trayMenuNeedsRebuild(before, after), isTrue);
    });
  });

  group('truncateTrayLabel', () {
    test('short labels are untouched', () {
      expect(truncateTrayLabel('CCTV-1'), 'CCTV-1');
    });

    test('a plain label is cut with an ellipsis', () {
      final cut = truncateTrayLabel('中央广播电视总台综合频道高清信号直播', maxLength: 10);

      expect(cut.length, 10);
      expect(cut.endsWith('…'), isTrue);
    });

    test('the status suffix survives the cut, the name does not', () {
      const suffix = '01:12:45';

      final cut = truncateTrayLabel('中央广播电视总台综合频道高清信号直播正在录制中谢谢观看', maxLength: 24, keepSuffix: suffix);

      expect(cut.endsWith(suffix), isTrue, reason: 'the elapsed time is the only part that was worth reading');
      expect(cut.length, lessThanOrEqualTo(24));
    });

    test('a suffix that fills the line keeps the suffix', () {
      final cut = truncateTrayLabel('CCTV-1 综合频道高清信号', maxLength: 12, keepSuffix: '01:12:45');

      expect(cut, '01:12:45', reason: 'the channel name is dropped rather than the elapsed time');
    });
  });

  group('TrayIconState', () {
    test('only playing and recording count as busy', () {
      expect(TrayIconState.recording.isBusy, isTrue);
      expect(TrayIconState.playing.isBusy, isTrue);
      expect(TrayIconState.idle.isBusy, isFalse);
      expect(TrayIconState.attention.isBusy, isFalse);
    });
  });
}
