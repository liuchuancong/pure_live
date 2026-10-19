import 'dart:async';
import 'dart:io';

import 'package:live_sites/live_sites.dart';
import 'package:path/path.dart' as p;

// The private constructor cannot use the `new` shorthand.
// ignore_for_file: unnecessary_type_name_in_constructor

/// How the reference names a saved recording chat: the bilibili-style XML,
/// `<d>` per chat, `<gift>`/`<sc>` alongside them when the settings include
/// gifts (H01.8), one per line, appended as the messages arrive.
///
/// The file survives a crash mid-write because the closing tag is the only
/// thing an abrupt end loses; the entries that landed are already complete
/// lines.
final class RecordChatWriter {
  RecordChatWriter._(this._sink);

  /// Starts saving the chat of room [roomId] of [site] beside the capture
  /// that lands in [sessionDirectory]. Null when the site has no danmaku
  /// capability or the connection refuses — a recording is never lost
  /// because its chat could not be attached.
  static Future<RecordChatWriter?> attach({
    required LiveSite site,
    required String roomId,
    required String sessionDirectory,
    required String taskId,
    required bool includeGifts,
  }) async {
    final capability = site.capability<LiveDanmakuProvider>();
    if (capability == null) {
      return null;
    }
    final file = File(p.join(sessionDirectory, '$taskId.chat.xml'));
    final RecordChatWriter writer;
    try {
      await file.parent.create(recursive: true);
      writer = RecordChatWriter._(file.openWrite());
      writer._sink.writeln('<root>');
      await writer._sink.flush();
    } on Object {
      return null;
    }
    LiveDanmakuSession? session;
    try {
      session = await capability
          .createSession(roomId: roomId)
          .then((value) => value.fold((_) => null, (connected) => connected))
          .catchError((_) => null);
    } on Object {
      session = null;
    }
    if (session == null) {
      await writer.close();
      return null;
    }
    writer._session = session;
    // Cancelled by [close], which the capture's end runs — not by the
    // function that created it.
    // ignore: cancel_subscriptions
    final sub = session.events.listen((message) => writer._write(message, includeGifts: includeGifts));
    writer._sub = sub;
    await session.connect().catchError((Object _) {});
    return writer;
  }

  final IOSink _sink;
  LiveDanmakuSession? _session;
  StreamSubscription<LiveMessage>? _sub;

  void _write(LiveMessage message, {required bool includeGifts}) {
    final at = (message.sentAt ?? message.createdAt ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
    final user = _escape(message.effectiveSender.userName);
    final text = _escape(message.text);
    if (message.type == LiveMessageType.chat) {
      _sink.writeln('  <d p="$at,25,16777215" user="$user">$text</d>');
      return;
    }
    if (!includeGifts) {
      // "录制弹幕时包含礼物" off: the file stays the plain chat it was.
      return;
    }
    if (message.type == LiveMessageType.gift) {
      _sink.writeln('  ${_gift(at, user, text, message.payload)}');
    } else if (message.type == LiveMessageType.superChat) {
      _sink.writeln('  <sc ts="$at" user="$user" price="0">$text</sc>');
    }
    // Enters, leaves, notices and the rest are not part of the chat file.
  }

  String _gift(int at, String user, String text, Object? payload) {
    final gift = payload is LiveGift ? payload : null;
    final name = _escape(gift?.name ?? text);
    final count = gift?.count ?? 1;
    final price = gift?.value.unitPrice ?? 0;
    return '<gift ts="$at" user="$user" name="$name" num="$count" price="$price">$text</gift>';
  }

  /// Finishes the document and releases the session. Idempotent: the capture
  /// teardown and an attach failure may both reach it.
  Future<void> close() async {
    final sub = _sub;
    _sub = null;
    await sub?.cancel();
    final session = _session;
    _session = null;
    try {
      _sink.writeln('</root>');
      await _sink.flush();
    } on Object {
      // A chat file that cannot close still holds every line that landed.
    }
    await _sink.close();
    if (session != null) {
      await session.disconnect().catchError((Object _) {});
      await session.dispose().catchError((Object _) {});
    }
  }
}

/// XML 1.0 escaping plus the control characters a platform stream can carry.
String _escape(String text) {
  final stripped = text.replaceAll(RegExp('[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');
  return stripped
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
