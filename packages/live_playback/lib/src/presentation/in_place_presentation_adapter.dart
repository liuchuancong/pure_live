import 'package:media_core/media_core.dart';

/// The presentation adapter a host uses when it has no platform drivers yet.
///
/// It answers the modes a *host* serves by laying widgets out itself —
/// fullscreen and window-fullscreen, which need nothing from the platform — and
/// reports PiP and the floating window as unsupported, because those need real
/// OS windows that this adapter does not open.
///
/// That honesty is the point: with it attached, `PlaybackPresentation` refuses
/// PiP and floating requests instead of flipping a state to `pip` while no
/// window appears. A host that has `media_core_pip` / `media_core_floating`
/// wired passes its own adapter and gets both.
final class InPlacePresentationAdapter extends PresentationAdapterBase {
  /// Creates the adapter.
  ///
  /// [initialCapabilities] is for a host whose platform support differs from
  /// the default; the streams and lifecycle come from
  /// [PresentationAdapterBase].
  new({super.initialCapabilities = const PresentationCapabilities()});

  @override
  Future<void> apply(PresentationRequest request) async {
    // Deliberately empty: the host's own widget tree is what "becomes
    // fullscreen" here. Returning normally is what tells the service the
    // transition settled, so the state does not sit at `transitioning` forever.
  }

  @override
  Future<void> refreshCapabilities() async {
    // Nothing to ask the platform: these capabilities are constants.
  }
}
