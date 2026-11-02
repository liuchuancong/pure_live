import 'dart:io' show File;

/// One entry in the preview page's list.
///
/// A module hands the page the files it knows how to preview — a finished
/// recording, a completed download, a local clip — and nothing about how they
/// are played: the path is a local file, the rest is what the list shows.
///
/// The stage is a video stage. An audio file would play over a black frame with
/// no cover, no lyrics and no play bar, and the app already owns that surface
/// elsewhere — the music module's player page has the artwork, the lyric run and
/// the transport, and a queue of downloaded songs hands its rows there rather
/// than here. Nothing in this type pretends otherwise.
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

  /// The entry's own picture: a series' poster, a room's cover. The list shows
  /// it once — on the header naming the group its entries came from — while the
  /// stage plays the file's own picture and never draws this one. Empty leaves
  /// the header as plain text.
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
