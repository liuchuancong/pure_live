import 'dart:async';
import 'dart:developer';

import 'package:path/path.dart' as p;
import 'package:share_handler/share_handler.dart';

enum SharedMediaIntakeKind { roomCommand, liveLink, files, unsupported, failed }

class SharedMediaIntakeResult {
  const SharedMediaIntakeResult({required this.kind, this.attemptedCount = 0, this.acceptedCount = 0});

  final SharedMediaIntakeKind kind;
  final int attemptedCount;
  final int acceptedCount;

  bool get handled =>
      kind == SharedMediaIntakeKind.roomCommand || kind == SharedMediaIntakeKind.liveLink || attemptedCount > 0;
}

typedef SharedRoomCommandPredicate = bool Function(String text);
typedef SharedRoomCommandConsumer = Future<bool> Function(String text);
typedef SharedFileImporter = Future<bool> Function(String path);
typedef SharedAttachmentReleaser = Future<void> Function(String path);
typedef SharedMediaFeedback = void Function(String localizationKey);
typedef SharedMediaErrorReporter = void Function(Object error, StackTrace stackTrace);

class SharedMediaIntake {
  SharedMediaIntake({
    required this.isRoomCommand,
    required this.consumeRoomCommand,
    required this.importPlaylist,
    required this.importEpg,
    required this.releaseAttachment,
    required this.notifyUnsupported,
    SharedRoomCommandPredicate? isLiveLink,
    SharedRoomCommandConsumer? openLiveLink,
    SharedMediaErrorReporter? reportError,
  }) : isLiveLink = isLiveLink ?? _noLiveLink,
       openLiveLink = openLiveLink ?? _ignoreLiveLink,
       _reportError = reportError ?? _logError;

  static bool _noLiveLink(String _) => false;
  static Future<bool> _ignoreLiveLink(String _) async => false;

  static const Set<String> playlistExtensions = {'.m3u', '.m3u8', '.txt'};
  static const Set<String> epgExtensions = {'.xml', '.gz', '.json'};

  final SharedRoomCommandPredicate isRoomCommand;
  final SharedRoomCommandConsumer consumeRoomCommand;
  final SharedFileImporter importPlaylist;
  final SharedFileImporter importEpg;
  final SharedAttachmentReleaser releaseAttachment;
  final SharedMediaFeedback notifyUnsupported;

  /// Text shared from a platform app ("快来看直播 https://live.bilibili.com/6 …").
  final SharedRoomCommandPredicate isLiveLink;
  final SharedRoomCommandConsumer openLiveLink;
  final SharedMediaErrorReporter _reportError;
  Future<void> _queue = Future<void>.value();

  static void _logError(Object error, StackTrace stackTrace) {
    log('Shared media intake failed', name: 'SharedMediaIntake', error: error, stackTrace: stackTrace);
  }

  Future<SharedMediaIntakeResult> ingest(SharedMedia media) {
    final operation = _queue.then((_) => _ingest(media));
    _queue = operation.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return operation;
  }

  Future<SharedMediaIntakeResult> _ingest(SharedMedia media) async {
    final attachmentPaths = <String>{};
    for (final attachment in media.attachments ?? const <SharedAttachment?>[]) {
      final path = attachment?.path.trim() ?? '';
      if (path.isNotEmpty) attachmentPaths.add(path);
    }

    try {
      final text = media.content?.trim() ?? '';
      if (text.isNotEmpty && isRoomCommand(text)) {
        final accepted = await consumeRoomCommand(text);
        return SharedMediaIntakeResult(
          kind: SharedMediaIntakeKind.roomCommand,
          attemptedCount: 1,
          acceptedCount: accepted ? 1 : 0,
        );
      }

      final paths = <String>{...attachmentPaths};
      if (text.isNotEmpty && _supportedExtension(text) != null) {
        paths.add(text);
      }

      var attempted = 0;
      var accepted = 0;
      for (final path in paths) {
        final extension = _supportedExtension(path);
        if (extension == null) continue;
        attempted++;
        final imported = playlistExtensions.contains(extension) ? await importPlaylist(path) : await importEpg(path);
        if (imported) accepted++;
      }

      if (attempted > 0) {
        return SharedMediaIntakeResult(
          kind: SharedMediaIntakeKind.files,
          attemptedCount: attempted,
          acceptedCount: accepted,
        );
      }

      if (text.isNotEmpty && isLiveLink(text)) {
        final accepted = await openLiveLink(text);
        return SharedMediaIntakeResult(
          kind: SharedMediaIntakeKind.liveLink,
          attemptedCount: 1,
          acceptedCount: accepted ? 1 : 0,
        );
      }

      _notifyUnsupportedSafely();
      return const SharedMediaIntakeResult(kind: SharedMediaIntakeKind.unsupported);
    } catch (error, stackTrace) {
      _reportErrorSafely(error, stackTrace);
      return const SharedMediaIntakeResult(kind: SharedMediaIntakeKind.failed);
    } finally {
      for (final path in attachmentPaths) {
        try {
          await releaseAttachment(path);
        } catch (error, stackTrace) {
          _reportErrorSafely(error, stackTrace);
        }
      }
    }
  }

  static String? _supportedExtension(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final uri = Uri.tryParse(trimmed);
    final path = uri != null && uri.scheme.toLowerCase() == 'file' ? uri.toFilePath() : uri?.path ?? trimmed;
    final extension = p.extension(path).toLowerCase();
    return playlistExtensions.contains(extension) || epgExtensions.contains(extension) ? extension : null;
  }

  void _notifyUnsupportedSafely() {
    try {
      notifyUnsupported('unsupported_file_format');
    } catch (error, stackTrace) {
      _reportErrorSafely(error, stackTrace);
    }
  }

  void _reportErrorSafely(Object error, StackTrace stackTrace) {
    try {
      _reportError(error, stackTrace);
    } catch (_) {}
  }
}

typedef InitialSharedMediaReader = Future<SharedMedia?> Function();
typedef InitialSharedMediaResetter = Future<void> Function();

class SharedMediaReceiver {
  SharedMediaReceiver({
    required this.readInitialMedia,
    required this.resetInitialMedia,
    required this.mediaStream,
    required this.intake,
    SharedMediaErrorReporter? reportError,
  }) : _reportError = reportError ?? SharedMediaIntake._logError;

  final InitialSharedMediaReader readInitialMedia;
  final InitialSharedMediaResetter resetInitialMedia;
  final Stream<SharedMedia> mediaStream;
  final SharedMediaIntake intake;
  final SharedMediaErrorReporter _reportError;
  StreamSubscription<SharedMedia>? _subscription;
  Future<void>? _startTask;
  bool _disposed = false;

  Future<void> start() {
    return _startTask ??= _start();
  }

  Future<void> _start() async {
    if (_disposed) return;
    try {
      _subscription = mediaStream.listen((media) {
        if (!_disposed) unawaited(intake.ingest(media));
      }, onError: (Object error, StackTrace stackTrace) => _reportErrorSafely(error, stackTrace));
    } catch (error, stackTrace) {
      _reportErrorSafely(error, stackTrace);
      return;
    }

    SharedMedia? initialMedia;
    try {
      initialMedia = await readInitialMedia();
    } catch (error, stackTrace) {
      _reportErrorSafely(error, stackTrace);
      return;
    }
    if (_disposed || initialMedia == null) return;

    try {
      await intake.ingest(initialMedia);
    } finally {
      try {
        await resetInitialMedia();
      } catch (error, stackTrace) {
        _reportErrorSafely(error, stackTrace);
      }
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final subscription = _subscription;
    _subscription = null;
    if (subscription != null) await subscription.cancel();
  }

  void _reportErrorSafely(Object error, StackTrace stackTrace) {
    try {
      _reportError(error, stackTrace);
    } catch (_) {}
  }
}
