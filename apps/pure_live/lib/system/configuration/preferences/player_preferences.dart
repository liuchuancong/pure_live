import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show immutable;

/// How rooms play: volumes, the preferred quality and codec, fit, fullscreen, the pip window, the mpv tuning (output, decoder, interpolation, scaler, deinterlace, cache) and the player's own proxy — the reference's `player` section.
// ignore_for_file: unnecessary_type_name_in_constructor
@immutable
final class PlayerPreferences extends Equatable {
  /// The shipping defaults.
  const new({
    this.volumeMuted = false,
    this.backgroundPlay = false,
    this.screenKeepOn = true,
    this.defaultMobileVolume = 0.5,
    this.defaultDesktopVolume = 1,
    this.preferResolution = '原画',
    this.preferResolutionCellular = '原画',
    this.preferH264 = true,
    this.videoFitIndex = 0,
    this.openRoomFullscreen = false,
    this.pipAlwaysOnTop = false,
    this.miniRememberPosition = true,
    this.miniWindowRect = '',
    this.pauseOnPipClose = false,
    this.playerProxyEnabled = false,
    this.playerProxyHost = '127.0.0.1',
    this.playerProxyPort = 7890,
    this.audioOutputDriver = 'auto',
    this.hardwareDecoder = 'auto',
    this.frameInterpolation = false,
    this.scaler = 'auto',
    this.deinterlace = 'auto',
    this.streamCacheSeconds = 0,
    this.customPlayerOutput = false,
  });

  /// Reads the domain's keys from the flat document; unknown shapes decode
  /// to the defaults.
  factory PlayerPreferences.fromJson(Map<String, Object?> json) {
    // The one volume field a pre-split document stored seeds both answers.
    final legacyVolume = (json['defaultVolume'] as num?)?.toDouble();
    return PlayerPreferences(
      volumeMuted: json['volumeMuted'] as bool? ?? false,
      backgroundPlay: json['backgroundPlay'] as bool? ?? false,
      screenKeepOn: json['screenKeepOn'] as bool? ?? true,
      defaultMobileVolume: (json['defaultMobileVolume'] as num?)?.toDouble() ?? legacyVolume ?? 0.5,
      defaultDesktopVolume: (json['defaultDesktopVolume'] as num?)?.toDouble() ?? legacyVolume ?? 1,
      preferResolution: json['preferResolution'] as String? ?? '原画',
      preferResolutionCellular: json['preferResolutionCellular'] as String? ?? '原画',
      preferH264: json['preferH264'] as bool? ?? true,
      videoFitIndex: (json['videoFitIndex'] as num?)?.toInt() ?? 0,
      openRoomFullscreen: json['openRoomFullscreen'] as bool? ?? false,
      pipAlwaysOnTop: json['pipAlwaysOnTop'] as bool? ?? false,
      miniRememberPosition: json['miniRememberPosition'] as bool? ?? true,
      miniWindowRect: json['miniWindowRect'] as String? ?? '',
      pauseOnPipClose: json['pauseOnPipClose'] as bool? ?? false,
      playerProxyEnabled: json['playerProxyEnabled'] as bool? ?? false,
      playerProxyHost: json['playerProxyHost'] as String? ?? '127.0.0.1',
      playerProxyPort: (json['playerProxyPort'] as num?)?.toInt() ?? 7890,
      audioOutputDriver: json['audioOutputDriver'] as String? ?? 'auto',
      hardwareDecoder: json['hardwareDecoder'] as String? ?? 'auto',
      frameInterpolation: json['frameInterpolation'] as bool? ?? false,
      scaler: json['scaler'] as String? ?? 'auto',
      deinterlace: json['deinterlace'] as String? ?? 'auto',
      streamCacheSeconds: (json['streamCacheSeconds'] as num?)?.toInt() ?? 0,
      customPlayerOutput: json['customPlayerOutput'] as bool? ?? false,
    );
  }

  /// Whether every room opens silenced, the reference's `vol.globalVolumeMute`.
  /// The level itself survives the mute; un-muting returns to it.
  final bool volumeMuted;

  /// Whether playback carries on while the app is in the background. Off
  /// pauses the room on the way out and resumes it on the way back.
  final bool backgroundPlay;

  /// Whether the screen stays awake while a room plays (the reference's
  /// `enableScreenKeepOn`, on by default).
  final bool screenKeepOn;

  /// The volume a room starts at on a touch phone, 0..1 — the reference's
  /// `vol.defaultMobileVolume`, one of the two answers its volume dialog edits.
  final double defaultMobileVolume;

  /// The volume a room starts at on a desktop window, 0..1.
  final double defaultDesktopVolume;

  /// The quality name to open a room with on Wi-Fi — one of
  /// `playQualityNames`, matched against the platform's own quality labels
  /// (the reference's preferResolution).
  final String preferResolution;

  /// The same answer for a cellular connection; the reference keeps a
  /// separate one so a metered network can start lower.
  final String preferResolutionCellular;

  /// Whether an HEVC-labelled quality is passed over while the room offers
  /// anything else (the reference's "优先 H.264 编码"); HEVC stays one menu tap
  /// away either way.
  final bool preferH264;

  /// Index into the six viewport fits (default, crop, fill, height, width,
  /// scale-down) a room opens with; anything out of range reads 0.
  final int videoFitIndex;

  /// Whether the room walks itself into fullscreen once the stream starts
  /// playing (the reference's "自动全屏").
  final bool openRoomFullscreen;

  /// Whether the desktop picture-in-picture tile stays above the other
  /// windows (the reference's 小窗始终置顶).
  final bool pipAlwaysOnTop;

  /// Whether the free-floating mini window re-opens where it was last left
  /// (the reference's rememberPipPosition). Off, every entry starts at the
  /// corner the driver chooses.
  final bool miniRememberPosition;

  /// The last mini-window geometry as `x,y,w,h`; '' is never-left. Written
  /// only while [miniRememberPosition] is on.
  final String miniWindowRect;

  /// Whether closing the window while it is a PiP/mini tile pauses playback
  /// (the reference's pauseOnPipClose) instead of letting the stream run
  /// behind a hidden window.
  final bool pauseOnPipClose;

  /// The player's own proxy (the reference's 播放器代理): mpv pulls the live
  /// stream through `http://host:port`, separate from the app's own HTTP
  /// proxy because the two often want different doors.
  final bool playerProxyEnabled;

  /// The player proxy's host.
  final String playerProxyHost;

  /// The player proxy's port (1..65535 as the field page validates it).
  final int playerProxyPort;

  /// mpv `ao` — the audio output driver.
  final String audioOutputDriver;

  /// mpv `hwdec` — the hardware decoder, `auto` letting mpv choose.
  final String hardwareDecoder;

  /// mpv `interpolation` — frame blending; desktop only, the reference's
  /// own gate on the cost.
  final bool frameInterpolation;

  /// mpv `scale` — the upscaling filter; `auto` keeps mpv's default.
  final String scaler;

  /// mpv `deinterlace`.
  final String deinterlace;

  /// mpv `cache`/`cache-secs` — the streaming read-ahead in seconds; 0 leaves
  /// the adapter's own cache settings untouched.
  final int streamCacheSeconds;

  /// There is no video-output answer any more: media_kit renders through mpv's
  /// `libmpv` output, and writing any other value leaves the embedded surface
  /// with no frames at all.
  final bool customPlayerOutput;

  /// The domain's keys as stored, flat.
  Map<String, Object?> toJson() => {
    'volumeMuted': volumeMuted,
    'backgroundPlay': backgroundPlay,
    'screenKeepOn': screenKeepOn,
    'defaultMobileVolume': defaultMobileVolume,
    'defaultDesktopVolume': defaultDesktopVolume,
    'preferResolution': preferResolution,
    'preferResolutionCellular': preferResolutionCellular,
    'preferH264': preferH264,
    'videoFitIndex': videoFitIndex,
    'openRoomFullscreen': openRoomFullscreen,
    'pipAlwaysOnTop': pipAlwaysOnTop,
    'miniRememberPosition': miniRememberPosition,
    'miniWindowRect': miniWindowRect,
    'pauseOnPipClose': pauseOnPipClose,
    'playerProxyEnabled': playerProxyEnabled,
    'playerProxyHost': playerProxyHost,
    'playerProxyPort': playerProxyPort,
    'audioOutputDriver': audioOutputDriver,
    'hardwareDecoder': hardwareDecoder,
    'frameInterpolation': frameInterpolation,
    'scaler': scaler,
    'deinterlace': deinterlace,
    'streamCacheSeconds': streamCacheSeconds,
    'customPlayerOutput': customPlayerOutput,
  };

  /// Returns a copy with the given fields replaced.
  PlayerPreferences copyWith({
    bool? volumeMuted,
    bool? backgroundPlay,
    bool? screenKeepOn,
    double? defaultMobileVolume,
    double? defaultDesktopVolume,
    String? preferResolution,
    String? preferResolutionCellular,
    bool? preferH264,
    int? videoFitIndex,
    bool? openRoomFullscreen,
    bool? pipAlwaysOnTop,
    bool? miniRememberPosition,
    String? miniWindowRect,
    bool? pauseOnPipClose,
    bool? playerProxyEnabled,
    String? playerProxyHost,
    int? playerProxyPort,
    String? audioOutputDriver,
    String? hardwareDecoder,
    bool? frameInterpolation,
    String? scaler,
    String? deinterlace,
    int? streamCacheSeconds,
    bool? customPlayerOutput,
  }) => PlayerPreferences(
    volumeMuted: volumeMuted ?? this.volumeMuted,
    defaultMobileVolume: defaultMobileVolume ?? this.defaultMobileVolume,
    defaultDesktopVolume: defaultDesktopVolume ?? this.defaultDesktopVolume,
    preferResolution: preferResolution ?? this.preferResolution,
    preferResolutionCellular: preferResolutionCellular ?? this.preferResolutionCellular,
    preferH264: preferH264 ?? this.preferH264,
    videoFitIndex: videoFitIndex ?? this.videoFitIndex,
    openRoomFullscreen: openRoomFullscreen ?? this.openRoomFullscreen,
    pipAlwaysOnTop: pipAlwaysOnTop ?? this.pipAlwaysOnTop,
    miniRememberPosition: miniRememberPosition ?? this.miniRememberPosition,
    miniWindowRect: miniWindowRect ?? this.miniWindowRect,
    pauseOnPipClose: pauseOnPipClose ?? this.pauseOnPipClose,
    playerProxyEnabled: playerProxyEnabled ?? this.playerProxyEnabled,
    playerProxyHost: playerProxyHost ?? this.playerProxyHost,
    playerProxyPort: playerProxyPort ?? this.playerProxyPort,
    audioOutputDriver: audioOutputDriver ?? this.audioOutputDriver,
    hardwareDecoder: hardwareDecoder ?? this.hardwareDecoder,
    frameInterpolation: frameInterpolation ?? this.frameInterpolation,
    scaler: scaler ?? this.scaler,
    deinterlace: deinterlace ?? this.deinterlace,
    streamCacheSeconds: streamCacheSeconds ?? this.streamCacheSeconds,
    customPlayerOutput: customPlayerOutput ?? this.customPlayerOutput,
  );

  @override
  List<Object?> get props => [
    volumeMuted,
    backgroundPlay,
    screenKeepOn,
    defaultMobileVolume,
    defaultDesktopVolume,
    preferResolution,
    preferResolutionCellular,
    preferH264,
    videoFitIndex,
    openRoomFullscreen,
    pipAlwaysOnTop,
    miniRememberPosition,
    miniWindowRect,
    pauseOnPipClose,
    playerProxyEnabled,
    playerProxyHost,
    playerProxyPort,
    audioOutputDriver,
    hardwareDecoder,
    frameInterpolation,
    scaler,
    deinterlace,
    streamCacheSeconds,
    customPlayerOutput,
  ];
}
