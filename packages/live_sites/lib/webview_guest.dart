/// The WebView-backed host capabilities: libraries that import a Flutter
/// plugin and therefore stay out of the pure-Dart export surface
/// (`live_sites.dart` and the site barrels remain readable by plain-Dart
/// tools and tests). The app shell imports this entry directly and injects
/// the objects through the factory's seams.
library;

export 'src/host/webview_xiaohongshu_guest.dart';
