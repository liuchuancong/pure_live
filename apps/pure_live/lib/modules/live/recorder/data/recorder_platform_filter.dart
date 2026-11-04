import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/shared/shared.dart' show kAllPlatforms;

/// The platform the recorder centre's lists are cut to: the subscriptions and
/// the recorded files both read this one choice. 'all' is every site.
final class RecorderPlatformFilterController extends Notifier<String> {
  @override
  String build() => kAllPlatforms;

  /// The shown site (or [kAllPlatforms]).
  String get selected => state;

  /// Shows one site's rows.
  set selected(String id) => state = id;
}

/// The recorder centre's platform filter.
final recorderPlatformFilterProvider = NotifierProvider<RecorderPlatformFilterController, String>(
  RecorderPlatformFilterController.new,
);
