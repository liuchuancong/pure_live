import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/shared/shared.dart' show kAllPlatforms;

/// The platform the recorder centre's lists are cut to: the subscriptions and
/// the recorded files both read this one choice, and the picker offers the
/// union of the sites the two hold, so a site either page holds is pickable
/// from either page. 'all' is every site. Only the centre answers to it — a
/// module's own recordings page (IPTV) reads it nowhere.
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
