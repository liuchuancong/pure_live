import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show immutable;

/// The app-level choices: launch behaviour, updates, the language, the exit countdown, the backup target, the log threshold and the history cap — the reference's `app` section.
// ignore_for_file: unnecessary_type_name_in_constructor
@immutable
final class GeneralPreferences extends Equatable {
  /// The shipping defaults.
  const new({
    this.refreshOnResume = true,
    this.showSplash = true,
    this.githubOnlyUpdates = false,
    this.detectClipboardRooms = true,
    this.startAtLogin = false,
    this.languageId = '',
    this.autoCheckUpdate = true,
    this.countdownCloseEnabled = false,
    this.countdownCloseMinutes = 60,
    this.backupDirectory = '',
    this.logLevelId = '',
    this.historyLimit = 50,
  });

  /// Reads the domain's keys from the flat document; unknown shapes decode
  /// to the defaults.
  factory GeneralPreferences.fromJson(Map<String, Object?> json) {
    return GeneralPreferences(
      refreshOnResume: json['refreshOnResume'] as bool? ?? true,
      showSplash: json['showSplash'] as bool? ?? true,
      githubOnlyUpdates: json['githubOnlyUpdates'] as bool? ?? false,
      detectClipboardRooms: json['detectClipboardRooms'] as bool? ?? true,
      startAtLogin: json['startAtLogin'] as bool? ?? false,
      languageId: json['languageId'] as String? ?? '',
      autoCheckUpdate: json['autoCheckUpdate'] as bool? ?? true,
      countdownCloseEnabled: json['countdownCloseEnabled'] as bool? ?? false,
      countdownCloseMinutes: json['countdownCloseMinutes'] as int? ?? 60,
      backupDirectory: json['backupDirectory'] as String? ?? '',
      logLevelId: json['logLevelId'] as String? ?? '',
      historyLimit: (json['historyLimit'] as num?)?.toInt() ?? 50,
    );
  }

  /// Whether a feed refreshes when the app comes back to the foreground.
  final bool refreshOnResume;

  /// Whether the start-up splash holds its two seconds of branding before it
  /// hands over (the reference's showSplashPage); off goes straight to the
  /// launch page.
  final bool showSplash;

  /// Whether the update feed asks GitHub only (the reference's
  /// useGitHubOriginForUpdates); off races the release assets through the
  /// mirrors first, GitHub as the last door — the shape for networks where
  /// GitHub is the slow one.
  final bool githubOnlyUpdates;

  /// Whether a room link found on the clipboard at resume is offered as a
  /// jump (the reference's detectClipboardRooms; 3.x always looked).
  final bool detectClipboardRooms;

  /// The stored answer behind the desktop 开机自启 row; the truth is read
  /// from the OS, and the row rewrites the store when the OS refuses.
  final bool startAtLogin;

  /// The interface language: an empty id follows the system, otherwise a slang
  /// locale code (`zh`, `en`). Frozen at boot — the whole tree is translated by
  /// the delegate the app builds before the first frame.
  final String languageId;

  /// Whether the home page checks the release feed at start-up.
  final bool autoCheckUpdate;

  /// Whether a countdown runs that exits the app when it fires.
  final bool countdownCloseEnabled;

  /// How long the countdown runs, in minutes.
  final int countdownCloseMinutes;

  /// Where backups are written and listed: the reference's
  /// `Settings.backupDirectory`; '' takes the data area's own backups
  /// tree (the app's default folder).
  final String backupDirectory;

  /// The persisted log threshold — a `LogLevel.name`, empty for the
  /// build default the `AppLog` already opened with.
  final String logLevelId;

  /// How many watch-history entries are kept; 0 keeps everything (the
  /// reference's `Settings.historyLimit`, default 50).
  final int historyLimit;

  /// The domain's keys as stored, flat.
  Map<String, Object?> toJson() => {
    'refreshOnResume': refreshOnResume,
    'showSplash': showSplash,
    'githubOnlyUpdates': githubOnlyUpdates,
    'detectClipboardRooms': detectClipboardRooms,
    'startAtLogin': startAtLogin,
    'languageId': languageId,
    'autoCheckUpdate': autoCheckUpdate,
    'countdownCloseEnabled': countdownCloseEnabled,
    'countdownCloseMinutes': countdownCloseMinutes,
    'backupDirectory': backupDirectory,
    'logLevelId': logLevelId,
    'historyLimit': historyLimit,
  };

  /// Returns a copy with the given fields replaced.
  GeneralPreferences copyWith({
    bool? refreshOnResume,
    bool? showSplash,
    bool? githubOnlyUpdates,
    bool? detectClipboardRooms,
    bool? startAtLogin,
    String? languageId,
    bool? autoCheckUpdate,
    bool? countdownCloseEnabled,
    int? countdownCloseMinutes,
    String? backupDirectory,
    String? logLevelId,
    int? historyLimit,
  }) => GeneralPreferences(
    refreshOnResume: refreshOnResume ?? this.refreshOnResume,
    showSplash: showSplash ?? this.showSplash,
    githubOnlyUpdates: githubOnlyUpdates ?? this.githubOnlyUpdates,
    detectClipboardRooms: detectClipboardRooms ?? this.detectClipboardRooms,
    startAtLogin: startAtLogin ?? this.startAtLogin,
    languageId: languageId ?? this.languageId,
    autoCheckUpdate: autoCheckUpdate ?? this.autoCheckUpdate,
    countdownCloseEnabled: countdownCloseEnabled ?? this.countdownCloseEnabled,
    countdownCloseMinutes: countdownCloseMinutes ?? this.countdownCloseMinutes,
    backupDirectory: backupDirectory ?? this.backupDirectory,
    logLevelId: logLevelId ?? this.logLevelId,
    historyLimit: historyLimit ?? this.historyLimit,
  );

  @override
  /// Every field, in declaration order.
  List<Object?> get props => [
    refreshOnResume,
    showSplash,
    githubOnlyUpdates,
    detectClipboardRooms,
    startAtLogin,
    languageId,
    autoCheckUpdate,
    countdownCloseEnabled,
    countdownCloseMinutes,
    backupDirectory,
    logLevelId,
    historyLimit,
  ];
}
