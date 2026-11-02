import 'dart:io' show File;

/// One entry in the preview page's list.
///
/// A module hands the page the files it knows how to preview — a finished
/// recording, a completed download, a local clip — and nothing about how they
/// are played: the path is a local file, the rest is what the list shows.
final class MediaPreviewItem {
  /// Describes one playable entry.
  const MediaPreviewItem({
    required this.id,
    required this.title,
    required this.path,
    this.subtitle = '',
    this.cover = '',
    this.danmakuPath,
    this.groupPath = '',
    this.groupLabel = '',
  });

  /// A stable identity inside the list (a task id, a download id).
  final String id;

  /// The line the list leads with.
  final String title;

  /// The local file to play.
  final String path;

  /// The second line: source, length, size — whatever the module knows.
  final String subtitle;

  /// A cover to show when the file is audio, or when its picture has not
  /// loaded yet.
  final String cover;

  /// The sidecar a preview can read danmaku from, when the module wrote one.
  final String? danmakuPath;

  /// The folder the list groups this entry under, and the name it shows for
  /// it. A recording carries the room that made it — `<root>/day/platform/room`
  /// named as 日期 · 平台 · 直播间 — so the run reads as the tree that filed it
  /// rather than as a numbered queue. Empty keeps the list flat, which is what a
  /// download queue wants.
  final String groupPath;
  final String groupLabel;

  /// Whether the file is still where the list says.
  bool get exists => path.trim().isNotEmpty && _fileExists(path);

  static bool _fileExists(String path) => File(path).existsSync();
}
