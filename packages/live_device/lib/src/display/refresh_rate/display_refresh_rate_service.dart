import 'package:live_device/src/display/refresh_rate/display_refresh_rate.dart';
import 'package:live_device/src/display/refresh_rate/display_refresh_rate_capabilities.dart';
import 'package:live_device/src/display/refresh_rate/display_refresh_rate_exception.dart';
import 'package:live_device/src/display/refresh_rate/display_refresh_rate_preference.dart';

/// Reads, observes and steers the display refresh rate.
///
/// Depend on this contract in playback or application services so the concrete
/// plugin can be replaced without changing those callers. Rates are hertz values
/// reported by the operating system; they do not measure the cadence this app
/// actually presents.
abstract interface class DisplayRefreshRateService {
  /// Fetches a fresh snapshot from the platform and returns it.
  ///
  /// The thermal state and low-power flag are read synchronously from the
  /// backend's cached state while this snapshot is assembled, so they can lag
  /// the returned rates by a short moment.
  Future<DisplayRefreshRate> read();

  /// Emits a snapshot whenever the backend reports a display change.
  ///
  /// The stream carries no initial value and is shared between subscribers;
  /// cancel the subscription when the consumer no longer needs updates. Failures
  /// are surfaced as [DisplayRefreshRateException] stream errors.
  Stream<DisplayRefreshRate> watch();

  /// Returns the operations the active display backend supports.
  ///
  /// Support is reported by the backend at runtime, so it reflects the attached
  /// display rather than only the operating system name.
  Future<DisplayRefreshRateCapabilities> getCapabilities();

  /// Asks the platform to run the display at its highest available rate.
  ///
  /// Returns the submission outcome instead of throwing when the platform has no
  /// such request path; see [DisplayRefreshRatePreference].
  Future<DisplayRefreshRatePreference> preferMaximum();

  /// Releases this app's preference so the platform decides the rate again.
  ///
  /// Independent requests owned by other callers are preserved.
  Future<DisplayRefreshRatePreference> preferDefault();

  /// Asks the platform to match the cadence of the content being shown.
  ///
  /// The request uses seamless transition semantics only, so the platform never
  /// interrupts the current presentation to reach [hz]. [hz] must be a positive
  /// finite value; anything else throws [DisplayRefreshRateException] with the
  /// `invalid_refresh_rate` code before the request reaches the backend.
  /// Matching is exact, so a rate the panel cannot reach is reported as
  /// [DisplayRefreshRatePreference.unavailable] or
  /// [DisplayRefreshRatePreference.unsupported].
  Future<DisplayRefreshRatePreference> matchContent({required double hz});
}
