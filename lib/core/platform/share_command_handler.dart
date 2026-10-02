import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:developer';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:pure_live/core/index.dart';
import 'package:pure_live/core/platform/platform_utils.dart';
import 'package:pure_live/core/platform/share_command_codec.dart';
import 'package:share_plus/share_plus.dart';

typedef ShareClipboardReader = Future<String?> Function();
typedef ShareClipboardWriter = Future<void> Function(String text);
typedef ShareTextPresenter = Future<void> Function(String text);
typedef ShareCommandFeedback = void Function(String localizationKey);

class ShareCommandHandler {
  static final ShareCommandHandler instance = ShareCommandHandler();

  ShareCommandHandler({
    ShareClipboardReader? readClipboard,
    ShareClipboardWriter? writeClipboard,
    ShareTextPresenter? shareText,
    bool Function()? isDesktop,
    ShareCommandFeedback? notifySuccess,
    ShareCommandFeedback? notifyFailure,
    int retainedHashLimit = 128,
  }) : _readClipboard = readClipboard ?? _readSystemClipboard,
       _writeClipboard = writeClipboard ?? _writeSystemClipboard,
       _shareText = shareText ?? _presentSystemShare,
       _isDesktop = isDesktop ?? _isDesktopPlatform,
       _notifySuccess = notifySuccess ?? _showSuccess,
       _notifyFailure = notifyFailure ?? _showFailure,
       _retainedHashLimit = _validateRetainedHashLimit(retainedHashLimit);

  final ShareClipboardReader _readClipboard;
  final ShareClipboardWriter _writeClipboard;
  final ShareTextPresenter _shareText;
  final bool Function() _isDesktop;
  final ShareCommandFeedback _notifySuccess;
  final ShareCommandFeedback _notifyFailure;
  final int _retainedHashLimit;
  final LinkedHashSet<String> _blacklistHashes = LinkedHashSet<String>();
  String _lastProcessedHashInLifecycle = '';
  Future<void>? _clipboardCheckTask;
  Future<void> _commandQueue = Future<void>.value();

  static int _validateRetainedHashLimit(int value) {
    if (value < 1) {
      throw ArgumentError.value(value, 'retainedHashLimit', 'must be at least 1');
    }
    return value;
  }

  static Future<String?> _readSystemClipboard() async {
    return (await Clipboard.getData(Clipboard.kTextPlain))?.text;
  }

  static Future<void> _writeSystemClipboard(String text) {
    return Clipboard.setData(ClipboardData(text: text));
  }

  static Future<void> _presentSystemShare(String text) async {
    await SharePlus.instance.share(ShareParams(text: text));
  }

  static bool _isDesktopPlatform() => PlatformUtils.isDesktop;

  static void _showSuccess(String localizationKey) {
    SnackBarUtil.success(i18n(localizationKey));
  }

  static void _showFailure(String localizationKey) {
    SnackBarUtil.error(i18n(localizationKey));
  }

  static bool _hasUsableRoomIdentity(Map<String, dynamic> roomMap) {
    final platform = roomMap['platform']?.toString().trim() ?? '';
    final roomId = roomMap['roomId']?.toString().trim() ?? '';
    if (platform.isEmpty || roomId.isEmpty) return false;
    return !const {'0', 'null', 'undefined', 'nan', 'none'}.contains(roomId.toLowerCase());
  }

  static bool isUsableCommand(String text) {
    final roomMap = ShareCommandCodec.decodeShort(text.trim());
    return roomMap != null && _hasUsableRoomIdentity(roomMap);
  }

  String _hashText(String text) {
    return sha256.convert(utf8.encode(text.trim())).toString();
  }

  void resetLifecycleCache() {
    _lastProcessedHashInLifecycle = '';
  }

  Future<void> checkClipboard(FutureOr<void> Function(String roomInfo) onMatchFound) {
    final active = _clipboardCheckTask;
    if (active != null) return active;

    late final Future<void> task;
    task = _checkClipboard(onMatchFound).whenComplete(() {
      if (identical(_clipboardCheckTask, task)) {
        _clipboardCheckTask = null;
      }
    });
    _clipboardCheckTask = task;
    return task;
  }

  Future<void> _checkClipboard(FutureOr<void> Function(String roomInfo) onMatchFound) async {
    late final String currentText;
    try {
      currentText = (await _readClipboard())?.trim() ?? '';
      if (currentText.isEmpty) return;
    } catch (error, stackTrace) {
      log(
        'Clipboard share command could not be read',
        name: 'ShareCommandHandler',
        error: error,
        stackTrace: stackTrace,
      );
      return;
    }

    await acceptCommandText(currentText, onMatchFound);
  }

  Future<bool> acceptCommandText(String text, FutureOr<void> Function(String roomInfo) onMatchFound) {
    late final Future<bool> operation;
    operation = _commandQueue.then((_) => _acceptCommandText(text, onMatchFound));
    _commandQueue = operation.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return operation;
  }

  Future<bool> _acceptCommandText(String text, FutureOr<void> Function(String roomInfo) onMatchFound) async {
    final currentText = text.trim();
    if (currentText.isEmpty) return false;

    final currentHash = _hashText(currentText);
    if (_blacklistHashes.contains(currentHash) || currentHash == _lastProcessedHashInLifecycle) {
      return false;
    }
    if (!isUsableCommand(currentText)) return false;

    try {
      await onMatchFound(currentText);
      _lastProcessedHashInLifecycle = currentHash;
      return true;
    } catch (error, stackTrace) {
      log('Share command was not accepted', name: 'ShareCommandHandler', error: error, stackTrace: stackTrace);
      return false;
    }
  }

  void _rememberText(String text) {
    final hash = _hashText(text);
    _blacklistHashes.remove(hash);
    _blacklistHashes.add(hash);
    while (_blacklistHashes.length > _retainedHashLimit) {
      _blacklistHashes.remove(_blacklistHashes.first);
    }
  }

  void _notifySafely(ShareCommandFeedback callback, String localizationKey) {
    try {
      callback(localizationKey);
    } catch (error, stackTrace) {
      log('Share command feedback failed', name: 'ShareCommandHandler', error: error, stackTrace: stackTrace);
    }
  }

  Future<bool> onShareRoomPressed(LiveRoom liveroom) async {
    final Map<String, dynamic> shareMap = {
      'platform': liveroom.platform,
      'roomId': liveroom.roomId,
      'title': liveroom.title,
      'link': liveroom.link,
      'cover': liveroom.cover,
      'avatar': liveroom.avatar,
      'nick': liveroom.nick,
    };
    if (!_hasUsableRoomIdentity(shareMap)) {
      _notifySafely(_notifyFailure, 'share_failed');
      return false;
    }
    final String secret = ShareCommandCodec.encodeShort(shareMap);
    if (secret.isEmpty) {
      _notifySafely(_notifyFailure, 'share_failed');
      return false;
    }

    try {
      if (_isDesktop()) {
        await _writeClipboard(secret);
        _rememberText(secret);
        _notifySafely(_notifySuccess, 'copied_to_clipboard');
      } else {
        await _shareText(secret);
        _rememberText(secret);
        try {
          final postShareText = await _readClipboard();
          if (postShareText != null && postShareText.trim().isNotEmpty) {
            _rememberText(postShareText);
          }
        } catch (error, stackTrace) {
          log(
            'Post-share clipboard inspection failed',
            name: 'ShareCommandHandler',
            error: error,
            stackTrace: stackTrace,
          );
        }
      }
      return true;
    } catch (error, stackTrace) {
      log('Room share failed', name: 'ShareCommandHandler', error: error, stackTrace: stackTrace);
      _notifySafely(_notifyFailure, 'share_failed');
      return false;
    }
  }
}
