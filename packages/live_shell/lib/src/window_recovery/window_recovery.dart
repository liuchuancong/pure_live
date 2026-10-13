import 'package:meta/meta.dart';

/// Stops rebuilding a window that keeps failing to come up.
///
/// The failure this exists for is the one that looks like nothing: on desktop a
/// window can exist, be alive, and produce no frames — after a GPU reset, a
/// driver fault, or a display that went away mid-draw. The viewer sees the
/// background colour with the caption buttons on it and no interface; a shell
/// that only checks "does the window object exist" concludes everything is fine,
/// and a shell that *does* rebuild on that signal, forever, restarts a window
/// that fails again in a loop that eats the machine.
///
/// So the recovery is bounded and the bound is what makes it survivable: give up
/// after [limit] rebuilds inside [window], and the app then has something honest
/// to say instead of a spinner.
final class ReclaimCircuit {
  /// A circuit that allows [limit] rebuilds per [window].
  new({this.limit = 3, this.window = const Duration(minutes: 1)});

  /// How many rebuilds are tolerated in one [window].
  final int limit;

  /// The period failures are counted over.
  final Duration window;

  final List<DateTime> _failures = [];

  /// Whether a rebuild may be attempted at [now].
  bool allows(DateTime now) => _remaining(now) > 0;

  /// Records one failed rebuild at [now].
  void recordFailure(DateTime now) {
    _failures.add(now);
    _prune(now);
  }

  /// Clears the count, called after a rebuild that actually produced frames —
  /// without this a window that recovered once is permanently one bad launch
  /// away from being refused a repair.
  void noteRecovered() => _failures.clear();

  /// Whether the circuit has opened: no further repair will be attempted.
  bool isTripped(DateTime now) => _remaining(now) == 0;

  /// How many failures are counted right now.
  int get failureCount => _failures.length;

  int _remaining(DateTime now) {
    _prune(now);
    final used = _failures.length;
    return used >= limit ? 0 : limit - used;
  }

  void _prune(DateTime now) {
    _failures.removeWhere((failure) => now.difference(failure) > window);
  }
}

/// The rendering fallbacks the viewer can reach from Settings.
///
/// Both exist because of upstream compositing bugs the app cannot fix, and both
/// are escape hatches rather than preferences: their purpose is to let someone
/// with a broken display get to the screen and export their recordings.
@immutable
final class RenderFallbacks {
  /// The fallbacks as saved.
  const new({this.effects = true, this.hardwareAcceleration = true});

  /// Whether the shell may use the platform's translucent window material.
  ///
  /// Turning this off is the fix for a window that shows black rectangles at its
  /// rounded corners or leaves a stale frame behind when the GPU cache is
  /// invalidated — which is why the app must then paint a **solid** background
  /// colour itself: a transparent window with no material behind it shows
  /// whatever is on the desktop through the surface's own clearing colour.
  final bool effects;

  /// Whether the GPU may draw.
  ///
  /// Off means the software rasteriser, which on Windows is the command-line
  /// switch `--enable-software-rendering`. It has to be decided before the first
  /// frame — the flag is read by the embedder when the window is created, so a
  /// settings change takes effect on the next start, and the settings screen must
  /// say so rather than letting the viewer toggle it and conclude it does nothing.
  final bool hardwareAcceleration;

  /// Whether the window must be created without translucency.
  bool get needsOpaqueSurface => !effects || !hardwareAcceleration;

  /// The extra command-line arguments this implies, if any.
  ///
  /// Empty on macOS and Linux, where no equivalent switch is honoured.
  List<String> get engineArguments => hardwareAcceleration ? const [] : const ['--enable-software-rendering'];

  @override
  bool operator ==(Object other) =>
      other is RenderFallbacks && other.effects == effects && other.hardwareAcceleration == hardwareAcceleration;

  @override
  int get hashCode => Object.hash(effects, hardwareAcceleration);
}
