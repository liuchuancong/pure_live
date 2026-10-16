import 'package:live_device/src/display/refresh_rate/display_refresh_rate_preference.dart';

/// Refresh-rate operations available from the active display backend.
///
/// Request support is reported by the backend at runtime and is separate from
/// the rates the panel can actually reach. On Windows, macOS and Linux the
/// native request paths are unavailable, so querying works while every request
/// comes back as [DisplayRefreshRatePreference.unsupported].
final class DisplayRefreshRateCapabilities {
  /// Creates an immutable refresh-rate capability description.
  const new({
    required this.canQuery,
    required this.canRequestPreferredRates,
    required this.canMatchContent,
    required this.canObserve,
    required this.platformName,
  });

  /// Whether the backend exposes display information at all.
  final bool canQuery;

  /// Whether a preferred-rate request can be submitted to the backend.
  ///
  /// This folds the window-preference and engine-control capabilities together,
  /// because both mean "a requested rate can be carried to the platform".
  final bool canRequestPreferredRates;

  /// Whether exact content-rate matching is supported.
  final bool canMatchContent;

  /// Whether rate changes can be observed through a stream.
  final bool canObserve;

  /// Runtime platform label for diagnostics, not intended for feature branching.
  final String platformName;
}
