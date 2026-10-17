import 'dart:async';

import 'package:flutter/foundation.dart' show immutable;
import 'package:live_net/live_net.dart' show HttpProxyRoute, ProxyPolicy, ProxyRoute;
import 'package:live_storage/live_storage.dart' show StorageRepository;

/// Where the general-preferences document is persisted.
///
/// One document per preference group in the shared `settings.preferences` box,
/// versioned in its key — the same discipline the appearance and shell
/// documents follow, so a reshaped document resets only its own group.
abstract final class AppPreferenceKeys {
  /// The box every preference group document lives in (`settings.preferences`).
  static const String box = 'settings.preferences';

  /// The general-preferences group key.
  static const String document = 'preferences.app.v1';
}

/// The branch the router starts on, when the last visited one is not asked
/// for (`restoreLastTab` off).
enum AppLaunchBranch {
  /// The home feed — the shipping default.
  home,

  /// The followed streamers' grid.
  follow,

  /// The popular / super-deal grid.
  popular,

  /// The areas catalogue.
  areas,

  /// The watch history.
  history;

  /// Resolves a stored identifier; an unknown one falls back to [home].
  static AppLaunchBranch fromId(String? id) => switch (id) {
    'follow' => AppLaunchBranch.follow,
    'popular' => AppLaunchBranch.popular,
    'areas' => AppLaunchBranch.areas,
    'history' => AppLaunchBranch.history,
    _ => AppLaunchBranch.home,
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
  static RoomCardCoverAspect of(double ratio) => values.reduce(
    (best, aspect) =>
        (aspect.ratio - ratio).abs() < (best.ratio - ratio).abs() ? aspect : best,
  );

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

/// The shell branches, in the order the chromes render them — the visible
/// subset. The home branch is the floor: a shell with no destination cannot
/// be walked, so every writer keeps at least one id.
const List<String> defaultShellBranches = ['home', 'follow', 'popular', 'areas', 'history'];

/// The app's general choices — general, refresh, page, navigation, proxy,
/// loading and room-card preferences — as one persisted document.
///
/// Plain fields, like the shell document: the shape is closed, an unknown
/// stored value decodes to its enum's default, and [copyWith] is written by
/// hand so a rename fails to compile instead of regenerating silently.
///
/// The `new` shorthand is reserved for the constructor name; the fromJson
/// factory and [copyWith] spell the class name, which the lint otherwise
/// asks to shorten.
// ignore_for_file: unnecessary_type_name_in_constructor
@immutable
final class AppPreferences {
  /// The shipping defaults.
  const new({
    this.refreshOnResume = true,
    this.autoCheckUpdate = true,
    this.countdownCloseEnabled = false,
    this.countdownCloseMinutes = 60,
    this.launchBranch = AppLaunchBranch.home,
    this.restoreLastTab = false,
    this.lastBranchId,
    this.windowWidth = 0,
    this.windowHeight = 0,
    this.autoRefreshMinutes = 0,
    this.refreshResumeThresholdMinutes = 10,
    this.proxyEnabled = false,
    this.proxyHost = '127.0.0.1',
    this.proxyPort = 7890,
    this.loadingStyle = LoadingStyle.shimmer,
    this.roomCardCornerRadius = 12,
    this.roomCardShowPlatform = true,
    this.roomCardShowAudience = true,
    this.roomCardShowAnchor = true,
    this.roomCardAspect = RoomCardCoverAspect.sixteenByNine,
    this.shellBranches = defaultShellBranches,
  });

  /// Reads the document; unknown shapes decode to the defaults.
  factory AppPreferences.fromJson(Map<String, Object?> json) {
    final branches = (json['shellBranches'] as List<Object?>?)?.whereType<String>().toList();
    return AppPreferences(
      refreshOnResume: json['refreshOnResume'] as bool? ?? true,
      autoCheckUpdate: json['autoCheckUpdate'] as bool? ?? true,
      countdownCloseEnabled: json['countdownCloseEnabled'] as bool? ?? false,
      countdownCloseMinutes: json['countdownCloseMinutes'] as int? ?? 60,
      launchBranch: AppLaunchBranch.fromId(json['launchBranch'] as String?),
      restoreLastTab: json['restoreLastTab'] as bool? ?? false,
      lastBranchId: json['lastBranchId'] as String?,
      windowWidth: json['windowWidth'] as int? ?? 0,
      windowHeight: json['windowHeight'] as int? ?? 0,
      autoRefreshMinutes: json['autoRefreshMinutes'] as int? ?? 0,
      refreshResumeThresholdMinutes: json['refreshResumeThresholdMinutes'] as int? ?? 10,
      proxyEnabled: json['proxyEnabled'] as bool? ?? false,
      proxyHost: json['proxyHost'] as String? ?? '127.0.0.1',
      proxyPort: json['proxyPort'] as int? ?? 7890,
      loadingStyle: LoadingStyle.fromId(json['loadingStyle'] as String?),
      roomCardCornerRadius: (json['roomCardCornerRadius'] as num?)?.toDouble() ?? 12,
      roomCardShowPlatform: json['roomCardShowPlatform'] as bool? ?? true,
      roomCardShowAudience: json['roomCardShowAudience'] as bool? ?? true,
      roomCardShowAnchor: json['roomCardShowAnchor'] as bool? ?? true,
      roomCardAspect: RoomCardCoverAspect.fromId(json['roomCardAspect'] as String?),
      shellBranches: branches == null || branches.isEmpty ? defaultShellBranches : branches,
    );
  }

  /// Whether a feed refreshes when the app comes back to the foreground.
  final bool refreshOnResume;

  /// Whether the home page checks the release feed at start-up.
  final bool autoCheckUpdate;

  /// Whether a countdown runs that exits the app when it fires.
  final bool countdownCloseEnabled;

  /// How long the countdown runs, in minutes.
  final int countdownCloseMinutes;

  /// The branch the router starts on, unless [restoreLastTab] wins.
  final AppLaunchBranch launchBranch;

  /// Whether the app starts on the branch it was last left on.
  final bool restoreLastTab;

  /// The shell branch id the app was last left on; null before the first
  /// tab switch.
  final String? lastBranchId;

  /// The desktop window's stored width; 0 keeps the launch default.
  final int windowWidth;

  /// The desktop window's stored height; 0 keeps the launch default.
  final int windowHeight;

  /// The foreground feed refresh interval, in minutes; 0 is off.
  final int autoRefreshMinutes;

  /// How long the app must have been away, in minutes, before a resume
  /// counts as worth refreshing for.
  final int refreshResumeThresholdMinutes;

  /// Whether outgoing requests route through the user's proxy.
  final bool proxyEnabled;

  /// The proxy host name or IP.
  final String proxyHost;

  /// The proxy port.
  final int proxyPort;

  /// How a feed's first-load placeholder is drawn.
  final LoadingStyle loadingStyle;

  /// The room card's corner radius, in logical pixels.
  final double roomCardCornerRadius;

  /// Whether the room card draws its platform pill.
  final bool roomCardShowPlatform;

  /// Whether the room card draws its audience and status pills.
  final bool roomCardShowAudience;

  /// Whether the room card draws its anchor line (avatar and name).
  final bool roomCardShowAnchor;

  /// The room card cover's shape.
  final RoomCardCoverAspect roomCardAspect;

  /// The visible shell branches, in display order; the home branch is the
  /// floor, so this is never empty.
  final List<String> shellBranches;

  /// Writes the document.
  Map<String, Object?> toJson() => {
    'refreshOnResume': refreshOnResume,
    'autoCheckUpdate': autoCheckUpdate,
    'countdownCloseEnabled': countdownCloseEnabled,
    'countdownCloseMinutes': countdownCloseMinutes,
    'launchBranch': launchBranch.id,
    'restoreLastTab': restoreLastTab,
    if (lastBranchId != null) 'lastBranchId': lastBranchId,
    'windowWidth': windowWidth,
    'windowHeight': windowHeight,
    'autoRefreshMinutes': autoRefreshMinutes,
    'refreshResumeThresholdMinutes': refreshResumeThresholdMinutes,
    'proxyEnabled': proxyEnabled,
    'proxyHost': proxyHost,
    'proxyPort': proxyPort,
    'loadingStyle': loadingStyle.id,
    'roomCardCornerRadius': roomCardCornerRadius,
    'roomCardShowPlatform': roomCardShowPlatform,
    'roomCardShowAudience': roomCardShowAudience,
    'roomCardShowAnchor': roomCardShowAnchor,
    'roomCardAspect': roomCardAspect.id,
    'shellBranches': shellBranches,
  };

  /// Returns a copy with the given fields replaced. [shellBranches] never
  /// takes an empty list — a shell with no destination cannot be walked.
  AppPreferences copyWith({
    bool? refreshOnResume,
    bool? autoCheckUpdate,
    bool? countdownCloseEnabled,
    int? countdownCloseMinutes,
    AppLaunchBranch? launchBranch,
    bool? restoreLastTab,
    String? lastBranchId,
    bool clearLastBranchId = false,
    int? windowWidth,
    int? windowHeight,
    int? autoRefreshMinutes,
    int? refreshResumeThresholdMinutes,
    bool? proxyEnabled,
    String? proxyHost,
    int? proxyPort,
    LoadingStyle? loadingStyle,
    double? roomCardCornerRadius,
    bool? roomCardShowPlatform,
    bool? roomCardShowAudience,
    bool? roomCardShowAnchor,
    RoomCardCoverAspect? roomCardAspect,
    List<String>? shellBranches,
  }) => AppPreferences(
    refreshOnResume: refreshOnResume ?? this.refreshOnResume,
    autoCheckUpdate: autoCheckUpdate ?? this.autoCheckUpdate,
    countdownCloseEnabled: countdownCloseEnabled ?? this.countdownCloseEnabled,
    countdownCloseMinutes: countdownCloseMinutes ?? this.countdownCloseMinutes,
    launchBranch: launchBranch ?? this.launchBranch,
    restoreLastTab: restoreLastTab ?? this.restoreLastTab,
    lastBranchId: clearLastBranchId ? null : (lastBranchId ?? this.lastBranchId),
    windowWidth: windowWidth ?? this.windowWidth,
    windowHeight: windowHeight ?? this.windowHeight,
    autoRefreshMinutes: autoRefreshMinutes ?? this.autoRefreshMinutes,
    refreshResumeThresholdMinutes: refreshResumeThresholdMinutes ?? this.refreshResumeThresholdMinutes,
    proxyEnabled: proxyEnabled ?? this.proxyEnabled,
    proxyHost: proxyHost ?? this.proxyHost,
    proxyPort: proxyPort ?? this.proxyPort,
    loadingStyle: loadingStyle ?? this.loadingStyle,
    roomCardCornerRadius: roomCardCornerRadius ?? this.roomCardCornerRadius,
    roomCardShowPlatform: roomCardShowPlatform ?? this.roomCardShowPlatform,
    roomCardShowAudience: roomCardShowAudience ?? this.roomCardShowAudience,
    roomCardShowAnchor: roomCardShowAnchor ?? this.roomCardShowAnchor,
    roomCardAspect: roomCardAspect ?? this.roomCardAspect,
    shellBranches:
        (shellBranches == null || shellBranches.isEmpty) ? this.shellBranches : List.unmodifiable(shellBranches),
  );

  @override
  bool operator ==(Object other) =>
      other is AppPreferences &&
      other.refreshOnResume == refreshOnResume &&
      other.autoCheckUpdate == autoCheckUpdate &&
      other.countdownCloseEnabled == countdownCloseEnabled &&
      other.countdownCloseMinutes == countdownCloseMinutes &&
      other.launchBranch == launchBranch &&
      other.restoreLastTab == restoreLastTab &&
      other.lastBranchId == lastBranchId &&
      other.windowWidth == windowWidth &&
      other.windowHeight == windowHeight &&
      other.autoRefreshMinutes == autoRefreshMinutes &&
      other.refreshResumeThresholdMinutes == refreshResumeThresholdMinutes &&
      other.proxyEnabled == proxyEnabled &&
      other.proxyHost == proxyHost &&
      other.proxyPort == proxyPort &&
      other.loadingStyle == loadingStyle &&
      other.roomCardCornerRadius == roomCardCornerRadius &&
      other.roomCardShowPlatform == roomCardShowPlatform &&
      other.roomCardShowAudience == roomCardShowAudience &&
      other.roomCardShowAnchor == roomCardShowAnchor &&
      other.roomCardAspect == roomCardAspect &&
      _listEquals(other.shellBranches, shellBranches);

  @override
  int get hashCode => Object.hash(
    refreshOnResume,
    autoCheckUpdate,
    countdownCloseEnabled,
    countdownCloseMinutes,
    launchBranch,
    restoreLastTab,
    lastBranchId,
    windowWidth,
    windowHeight,
    autoRefreshMinutes,
    refreshResumeThresholdMinutes,
    proxyEnabled,
    proxyHost,
    proxyPort,
    loadingStyle,
    roomCardCornerRadius,
    roomCardShowPlatform,
    roomCardShowAudience,
    roomCardShowAnchor,
    Object.hash(roomCardAspect, Object.hashAll(shellBranches)),
  );

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }
}

/// What a [AppPreferencesStore.load] or write found wrong.
///
/// The same shape as the appearance and shell stores' failures: a broken
/// document keeps its defaults and the fact is reported, never thrown.
enum AppPreferencesFailure {
  /// The box read threw.
  read,

  /// A document was stored but is not a JSON object.
  shape,

  /// A JSON object was stored but did not decode.
  decode,

  /// A document was built but could not be written.
  write,
}

/// The app's general choices: one in-memory [AppPreferences], persisted as
/// one JSON document through a storage repository.
///
/// Reading is synchronous — every reader sees [value] and watches [changes] —
/// so the router, the shells and the proxy policy resolve before the first
/// frame. Writing goes through [update], which applies the change to [value]
/// immediately and returns a future that completes once the change is
/// durable; writes are debounced and serialized, so dragging the room-card
/// radius slider across its range costs one document write, not one per
/// frame.
final class AppPreferencesStore {
  /// A store persisting through [repository].
  new({required this.repository, this.saveDebounce = const Duration(milliseconds: 400), this.onError});

  /// The repository the document is persisted in.
  final StorageRepository<Map<dynamic, dynamic>> repository;

  /// How long a change waits for company before the document is written.
  final Duration saveDebounce;

  /// Reports every failed read or write; null swallows them, and the
  /// composition root installs a logger.
  final void Function(AppPreferencesFailure failure, Object error, StackTrace stack)? onError;
  final StreamController<AppPreferences> _controller = StreamController<AppPreferences>.broadcast();

  AppPreferences _value = const AppPreferences();
  Timer? _debounce;
  Future<void> _writeChain = Future<void>.value();
  Completer<void>? _batch;
  Map<String, Object?>? _pending;
  bool _pendingDelete = false;
  bool _disposed = false;

  /// The current preferences: the shipping defaults until [load] runs.
  AppPreferences get value => _value;

  /// What the last [load] found wrong, empty when it found nothing.
  List<AppPreferencesFailure> get failures => List<AppPreferencesFailure>.unmodifiable(_failures);
  final List<AppPreferencesFailure> _failures = [];

  /// Emits on every applied change, including [load].
  Stream<AppPreferences> get changes => _controller.stream;

  /// Reads the stored document, applying it when it decodes.
  ///
  /// A document that cannot be read or decoded leaves [value] as it is and is
  /// recorded in [failures]; a missing document is not a failure, it is simply
  /// the first run.
  Future<AppPreferences> load() async {
    _checkNotDisposed();
    _failures.clear();
    final Map<dynamic, dynamic>? raw;
    try {
      raw = repository.get(AppPreferenceKeys.document);
    } on Object catch (error, stack) {
      _report(AppPreferencesFailure.read, error, stack);
      return _value;
    }
    if (raw == null) {
      return _value;
    }
    final AppPreferences loaded;
    try {
      loaded = AppPreferences.fromJson(Map<String, Object?>.from(raw));
    } on Object catch (error, stack) {
      _report(AppPreferencesFailure.decode, error, stack);
      return _value;
    }
    if (loaded != _value) {
      _value = loaded;
      _emit();
    }
    return loaded;
  }

  /// Applies [transform] to the preferences and persists the result.
  ///
  /// The returned future completes once the change is durable.
  Future<void> update(AppPreferences Function(AppPreferences preferences) transform) {
    _checkNotDisposed();
    final fresh = transform(_value);
    if (fresh == _value) {
      return Future<void>.value();
    }
    _value = fresh;
    _emit();
    _pending = fresh.toJson();
    _pendingDelete = false;
    return _debounced();
  }

  /// Writes the pending document now instead of waiting for the debounce:
  /// before the app exits.
  Future<void> flush() {
    _debounce?.cancel();
    _debounce = null;
    return _drain();
  }

  /// Flushes any pending write and closes the store; later [load] and
  /// [update] throw, [value] and [changes] stay readable.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await flush();
    await _controller.close();
  }

  /// Arms the debounce and answers with the durability future of the batch
  /// this change belongs to.
  Future<void> _debounced() {
    _debounce?.cancel();
    _debounce = Timer(saveDebounce, () => unawaited(_drain()));
    return (_batch ??= Completer<void>()).future;
  }

  /// Serializes whatever is pending behind any write already in flight.
  Future<void> _drain() {
    if (_pending == null && !_pendingDelete) {
      return Future<void>.value();
    }
    final batch = _batch ??= Completer<void>();
    _writeChain = _writeChain.then((_) async {
      final document = _pending;
      _pending = null;
      try {
        if (document != null) {
          await repository.save(AppPreferenceKeys.document, document);
        }
      } on Object catch (error, stack) {
        _report(AppPreferencesFailure.write, error, stack);
      }
    });
    return _writeChain.whenComplete(() {
      if (!batch.isCompleted) {
        batch.complete();
      }
      _batch = null;
    });
  }

  void _report(AppPreferencesFailure failure, Object error, StackTrace stack) {
    _failures.add(failure);
    onError?.call(failure, error, stack);
  }

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(_value);
    }
  }

  void _checkNotDisposed() {
    if (_disposed) {
      throw StateError('AppPreferencesStore was disposed');
    }
  }
}

/// The proxy route outgoing requests take, as the user configured it.
///
/// The dio factory consults a [ProxyPolicy] per request; this one answers
/// from the preferences store's in-memory value — cheap, side-effect free —
/// so flipping the proxy in settings reroutes new connections without a
/// restart. When the user's proxy is off, the decision falls through to
/// [fallback] (the build-time or system route).
final class PreferenceProxyPolicy implements ProxyPolicy {
  /// A policy reading [store], falling back to [fallback] while disabled.
  const new({required this.store, required this.fallback});

  /// The preferences the enabled flag, host and port come from.
  final AppPreferencesStore store;

  /// The route taken while the user's proxy is disabled.
  final ProxyPolicy fallback;

  @override
  ProxyRoute? routeFor(Uri url, {String? site}) {
    final preferences = store.value;
    if (!preferences.proxyEnabled) {
      return fallback.routeFor(url, site: site);
    }
    return HttpProxyRoute(
      host: preferences.proxyHost.trim().isEmpty ? '127.0.0.1' : preferences.proxyHost.trim(),
      port: preferences.proxyPort <= 0 || preferences.proxyPort > 65535 ? 7890 : preferences.proxyPort,
    );
  }
}
