import 'package:flutter_test/flutter_test.dart';
import 'package:media_core/media_core.dart' show PlayerKernel;
import 'package:media_core_floating/media_core_floating.dart';
import 'package:pure_live/core/player/presentation/kernel_floating_window_presenter.dart';

/// Guards the small-window wiring at the seam the kernel relies on, without a
/// native player or an overlay. Before this presenter was installed the shared
/// FloatingDriver kept the default NullFloatingWindowPresenter, whose
/// `isSupported == false` made `kernel.enterFloating` a silent no-op.
void main() {
  test('the installed host presenter reports it can show a window', () {
    final presenter = KernelFloatingWindowPresenter(
      kernel: PlayerKernel(),
      driver: FloatingDriver(),
    );

    expect(
      presenter.isSupported,
      isTrue,
      reason: 'a null presenter would leave enterFloating silently dropping the request',
    );
  });

  test('hiding when nothing is shown is a safe no-op', () async {
    final presenter = KernelFloatingWindowPresenter(
      kernel: PlayerKernel(),
      driver: FloatingDriver(),
    );

    await expectLater(presenter.hide(), completes);
  });
}
