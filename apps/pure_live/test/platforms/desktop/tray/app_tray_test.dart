// The named `_Page`-style constructors cannot use the `new` shorthand while const.
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/platforms/desktop/tray/app_tray.dart';

/// The tray's row grammar is a pure function of (recording count, window
/// visibility) — the reference's A16.1 T4 table — so it is worth pinning
/// apart from the native objects, which a test host cannot create.
void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh'));

  test('idle shows the window row and quit only', () {
    expect(trayMenuRows(recording: 0), [TrayRow.window, TrayRow.separator, TrayRow.quit]);
  });

  test('recording leads with the greyed count row', () {
    expect(trayMenuRows(recording: 2), [
      TrayRow.recording,
      TrayRow.separator,
      TrayRow.window,
      TrayRow.separator,
      TrayRow.quit,
    ]);
    expect(trayRowLabels(TrayRow.recording, visible: true, recording: 2).first, '正在录制 2 个直播间');
  });

  test('the window row says the opposite of the window', () {
    expect(trayRowLabels(TrayRow.window, visible: true, recording: 0).first, t.tray.hide);
    expect(trayRowLabels(TrayRow.window, visible: false, recording: 0).first, t.tray.show);
  });

  test('the hint counts the rooms', () {
    expect(trayTooltip(recording: 0), 'Pure Live');
    expect(trayTooltip(recording: 3), 'Pure Live · 正在录制 3 个直播间');
  });
}
