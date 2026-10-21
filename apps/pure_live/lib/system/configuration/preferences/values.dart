/// The value types the preference documents share: the launch branch, the
/// loading style, the room-card cover shape and the trusted-audience
/// defaults. One file so every domain document imports a single sibling.
library;

/// The branch the router starts on, when the last visited one is not asked
/// for (`restoreLastTab` off).
enum AppLaunchBranch {
  /// The followed streamers' grid — the shipping default, the reference's
  /// first tab.
  follow,

  /// The popular / super-deal grid.
  popular,

  /// The areas catalogue.
  areas,

  /// The recording centre.
  record;

  /// Resolves a stored identifier. A document written before the shell took
  /// the reference's tab set (which named a `home` launcher and a `history`
  /// branch) lands on the favorites branch rather than losing the choice.
  static AppLaunchBranch fromId(String? id) => switch (id) {
    'popular' => AppLaunchBranch.popular,
    'areas' => AppLaunchBranch.areas,
    'record' => AppLaunchBranch.record,
    _ => AppLaunchBranch.follow,
  };

  /// The stable identifier persisted in the document.
  String get id => name;
}

/// How a list feed's first-load placeholder is drawn.
enum LoadingStyle {
  /// The bone grid, shimmering (the shipping default).
  shimmer,

  /// A centred spinner.
  spinner,

  /// Nothing — the page stays blank until content arrives.
  none;

  /// Resolves a stored identifier; an unknown one falls back to [shimmer].
  static LoadingStyle fromId(String? id) => switch (id) {
    'spinner' => LoadingStyle.spinner,
    'none' => LoadingStyle.none,
    _ => LoadingStyle.shimmer,
  };

  /// The stable identifier persisted in the document.
  String get id => name;
}

/// The room-card cover's shape.
enum RoomCardCoverAspect {
  /// 16:9 — the shipping default, one video frame tall.
  sixteenByNine(16 / 9),

  /// 4:3 — a taller, closer cover.
  fourByThree(4 / 3),

  /// 1:1 — the square cover.
  square(1);

  new(this.ratio);

  /// The aspect as width / height, what `AspectRatio` and the grid metrics
  /// consume.
  final double ratio;

  /// The [RoomCardCoverAspect] whose ratio is closest to [ratio] — how a
  /// stored double round-trips through the chooser.
  static RoomCardCoverAspect of(double ratio) =>
      values.reduce((best, aspect) => (aspect.ratio - ratio).abs() < (best.ratio - ratio).abs() ? aspect : best);

  /// Resolves a stored identifier; an unknown one falls back to
  /// [sixteenByNine].
  static RoomCardCoverAspect fromId(String? id) => switch (id) {
    'fourByThree' => RoomCardCoverAspect.fourByThree,
    'square' => RoomCardCoverAspect.square,
    _ => RoomCardCoverAspect.sixteenByNine,
  };

  /// The stable identifier persisted in the document.
  String get id => name;
}

/// The platforms whose concurrent-online figure is trusted, as the reference
/// `Settings.realOnlinePlatforms` ships them (3.x's audience audit); the
/// audience settings row starts here and every check-box rewrites it.
const List<String> defaultRealOnlinePlatforms = [
  'douyin',
  'kuaishou',
  'cc',
  'twitch',
  'soop',
  'acfun',
  'picarto',
  'twitcasting',
];
