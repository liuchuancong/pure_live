import 'package:pure_uikit/pure_uikit.dart' show PureIconKey;

/// The app's icon vocabulary: what an icon MEANS, never which font draws it.
///
/// Pages and components name a key; the adapters under `adapters/` answer
/// it per design language through `AppIcons`. Add a key here and give every
/// adapter that should specialise it a glyph — the global mapping backstops
/// the rest.
enum AppIconKey implements PureIconKey {
  /// Re-load the current content.
  refresh,

  /// Return to the previous page.
  back,

  /// A right-pointing disclosure caret.
  chevronRight,

  /// An overflow menu of hidden actions.
  more,

  /// The grid-of-squares affordance for areas and app pickers.
  apps,

  /// Open settings.
  settings,

  /// Search.
  search,

  /// Dismiss what is on screen.
  close,

  /// Hand off to an outside target (browser, other app).
  openExternal,

  /// A link or short code.
  link,

  /// Language or locale choice.
  language,

  /// A broadcast on air.
  live,

  /// A room that is not broadcasting.
  offline,

  /// A room the viewer does not follow yet.
  follow,

  /// A room the viewer follows.
  followed,

  /// A saved item.
  bookmark,

  /// The watch history.
  history,

  /// A countdown or scheduled start.
  timer,

  /// Neutral information.
  info,

  /// Something failed.
  error,

  /// Blocked or shielded content.
  blocked,

  /// A confirmed choice.
  check,

  /// A completed state with weight.
  checkCircle,

  /// Content shown.
  visibility,

  /// Content hidden (or the eye-off toggle).
  hidden,

  /// Start playback.
  play,

  /// Suspend playback.
  pause,

  /// The previous track or item.
  previous,

  /// The next track or item.
  next,

  /// Subtitles or captions.
  subtitles,

  /// A camera or video affordance.
  video,

  /// Audio content.
  music,

  /// Sound on.
  volumeHigh,

  /// Sound off.
  volumeMute,

  /// Tuning controls (quality, danmaku settings).
  sliders,

  /// High quality.
  quality,

  /// The bullet-comment (danmaku) layer.
  danmaku,

  /// A directory.
  folder,

  /// A directory opened for browsing.
  folderOpen,

  /// On-device storage.
  storage,

  /// Cloud content.
  cloud,

  /// The cloud is unreachable.
  cloudOff,

  /// A cloud-sourced download.
  cloudDownload,

  /// A download.
  download,

  /// A server, node or line.
  network,

  /// Wi-Fi is off.
  wifiOff,

  /// Create something.
  add,

  /// Create with weight.
  addCircle,

  /// Change something.
  edit,

  /// Remove one thing.
  delete,

  /// Remove a whole list.
  deleteAll,

  /// Take a previous state back.
  restore,

  /// A chat message.
  comment,

  /// A grouping of things.
  category,

  /// A price or classification tag.
  tag,

  /// Appearance and colour choices.
  palette,

  /// The system share panel.
  share,

  /// A rating or starred item.
  star,

  /// The recommend feed branch.
  popular,

  /// The IPTV library branch.
  iptv,

  /// The multi-view branch.
  multiview,

  /// The toolbox branch.
  toolbox,

  /// The recording centre branch.
  record;

  @override
  String get id => name;
}
