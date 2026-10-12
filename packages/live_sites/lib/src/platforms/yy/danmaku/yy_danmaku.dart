import 'dart:math';
import 'dart:typed_data';

import 'package:live_sites/src/models/live_gift/live_gift.dart';
import 'package:live_sites/src/models/live_message/live_message.dart';
import 'package:live_sites/src/platforms/yy/danmaku/yy_packet.dart';

/// YY's danmaku endpoint, timing and text rules (3.x `YyDanmaku` and
/// `yy_protocol.dart`). The binary protocol is [YyDanmakuSession].
abstract final class YyDanmakuProtocol {
  /// Version of the web client's H5 service protocol (3.x
  /// `yyH5ServiceProtocolVersion`).
  static const String version = '3.2.10';

  /// The single-channel edge of the H5 service (3.x
  /// `yyH5ServiceWebSocketBaseUrl`).
  static const String baseUrl = 'wss://h5-sinchl.yy.com/websocket';

  /// Handshake headers (3.x): a desktop Chrome and YY's origin, in this order
  /// and spelling (the edge ignores a lower-cased header, REG-YY-001).
  static const Map<String, String> headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/151.0.0.0 Safari/537.36',
    'Origin': 'https://www.yy.com',
  };

  /// Heartbeat period (3.x `heartbeatTime`, 5 000 ms).
  static const Duration heartbeatInterval = Duration(seconds: 5);

  /// Silence after which the socket is replaced (3.x's `inactivityTimeout`).
  static const Duration inactivityTimeout = Duration(seconds: 45);

  /// Time the handshake has to join the channel after the socket opened (3.x's
  /// handshake timer).
  static const Duration handshakeTimeout = Duration(seconds: 15);

  /// The name of a sender without one (3.x).
  static const String anonymousUserName = 'YY用户';

  /// White, the danmaku default.
  static const int defaultColor = 0xFFFFFF;

  /// The endpoint of connection [uuid] (3.x `buildYyH5ServiceWebSocketUrl`).
  static Uri endpoint(String uuid) =>
      Uri.parse(baseUrl).replace(queryParameters: {'appid': 'yymwebh5', 'version': version, 'uuid': uuid});

  /// A random version 4 UUID, lower case (3.x `Uuid().v4()`).
  static String uuid(Random random) {
    final bytes = [for (var i = 0; i < 16; i++) random.nextInt(256)];
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = [for (final byte in bytes) byte.toRadixString(16).padLeft(2, '0')].join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  static final RegExp _xmlText = RegExp(r'''<txt\b[^>]*?\bdata\s*=\s*(?:"([^"]*)"|'([^']*)')''');
  static final RegExp _xmlEntity = RegExp('&(#[xX][0-9a-fA-F]+|#[0-9]+|amp|lt|gt|quot|apos);');

  /// The chat text of a message body [raw], trimmed. A body wrapped in XML
  /// (`<?xml version="1.0"?><msg><txt data="…" /></msg>`) gives the `data` of
  /// its `txt` elements, joined, with XML entities decoded, and nothing when it
  /// has none; emoticon codes such as `/{tx` stay as they are. 3.x showed the
  /// wrapper as the text.
  static String chatText(String raw) {
    final text = raw.trim();
    if (!text.startsWith('<?xml') && !text.startsWith('<msg')) return text;
    return [for (final match in _xmlText.allMatches(text)) _unescapeXml(match.group(1) ?? match.group(2) ?? '')]
        .join()
        .trim();
  }

  static String _unescapeXml(String value) => value.replaceAllMapped(_xmlEntity, (match) {
    final entity = match.group(1)!;
    final code = switch (entity) {
      'amp' => 0x26,
      'lt' => 0x3C,
      'gt' => 0x3E,
      'quot' => 0x22,
      'apos' => 0x27,
      _ when entity.startsWith('#x') || entity.startsWith('#X') => int.tryParse(entity.substring(2), radix: 16),
      _ => int.tryParse(entity.substring(1)),
    };
    // A reference to no character stays as written.
    if (code == null || code > 0x10FFFF || (code >= 0xD800 && code <= 0xDFFF)) return match.group(0)!;
    return String.fromCharCode(code);
  });

  /// [failure] on one line, at most 120 characters (3.x `_compactFailure`, the
  /// detail of its "disconnected" notice).
  static String compactFailure(String failure) {
    final line = failure.replaceAll(RegExp(r'\s+'), ' ').trim();
    return line.length <= 120 ? line : '${line.substring(0, 117)}...';
  }
}

/// Where the anonymous handshake of a [YyDanmakuSession] stands (3.x
/// `YyProtocolPhase`).
enum YyDanmakuPhase {
  /// [YyDanmakuSession.beginHandshake] not called yet.
  idle,

  /// Anonymous UDB login sent.
  waitingUdb,

  /// AP login sent.
  waitingAp,

  /// Channel join and app subscription sent.
  waitingJoin,

  /// In the channel; chat is read.
  joined,

  /// A step was refused; the socket has to be replaced.
  failed,
}

/// What one frame asked for ([YyDanmakuSession.consume], 3.x
/// `YyProtocolBatch`), in the order the connection acts on it: send
/// [outbound], report the join, report [messages], then reconnect on a
/// [failure].
final class YyDanmakuBatch {
  // A private named constructor cannot use the `new` shorthand, so the
  // traditional form stays by design (as in the kick session).
  // ignore: unnecessary_type_name_in_constructor
  YyDanmakuBatch._();

  /// Packets to send: the next handshake step, the group subscriptions after
  /// the join.
  final List<Uint8List> outbound = [];

  /// Chat, in order.
  final List<LiveMessage> messages = [];

  /// Parts that could not be read (3.x logged them); the rest of the frame is
  /// still read.
  final List<String> warnings = [];

  /// Whether this frame completed the join.
  bool get becameReady => _becameReady;
  bool _becameReady = false;

  /// Why the handshake failed, when it did.
  String? get failure => _failure;
  String? _failure;
}

/// The anonymous client of YY's H5 service for one channel (3.x
/// `YyProtocolSession`), without I/O.
///
/// [beginHandshake] starts over on every socket: anonymous UDB login (`778244`
/// → `778500`), AP login (`775684` → `775940`), then the channel join routed to
/// `channelAuther` (`513035` carrying `2048258`, answered by `512011` carrying
/// `2048514`) together with the app subscription (`538456`), and after the join
/// the two user group subscriptions (`537944`). Chat is app 31's `3104600`
/// inside user group messages (`533080`, also routed) and by-sid messages
/// (`28760`); the channel's heat is app 103's `3139586` in the same messages.
/// Packets are little endian ([YyPacketReader]); one frame can hold several.
///
/// Archived from the reference and mapped onto this tree's models: the
/// channel's heat is an audience update's concurrent viewers, and a chat
/// colour is the int white default (the sender's uid and level are dropped, as
/// the reference reads no id either).
final class YyDanmakuSession {
  /// Creates the session for channel [topSid]/[subSid] of connection [uuid].
  new({required this.topSid, required this.subSid, required this.uuid});

  static const int _applicationId = 259;
  static const int _anonymousLoginRequestUri = 778244;
  static const int _anonymousLoginResponseUri = 778500;
  static const int _anonymousLoginRealUri = 20078;
  static const int _apLoginRequestUri = 775684;
  static const int _apLoginResponseUri = 775940;
  static const int _apPingRequestUri = 794116;
  static const int _apRouterResponseUri = 512011;
  static const int _channelRouterRequestUri = 513035;
  static const int _joinChannelRequestUri = 2048258;
  static const int _joinChannelResponseUri = 2048514;
  static const int _joinUserGroupUri = 537944;
  static const int _userGroupMessageUri = 533080;
  static const int _bySidMessageUri = 28760;
  static const int _textChatUri = 3104600;
  static const int _subscribeAppIdsUri = 538456;
  static const int _chatAppId = 31;
  static const int _audienceAppId = 103;
  static const int _popularityUri = 3139586;
  static const int _joinedStatus = 4;
  static const String _deviceId = 'B8-97-5A-17-AD-4D';

  /// Top channel (`sid`).
  final int topSid;

  /// Sub channel (`ssid`).
  final int subSid;

  /// The connection's UUID (endpoint, AP login, trace id).
  final String uuid;

  /// Where the handshake stands.
  YyDanmakuPhase get phase => _phase;
  YyDanmakuPhase _phase = YyDanmakuPhase.idle;

  int _uid = 0;
  String _username = '';
  String _password = '';
  Uint8List _cookie = Uint8List(0);
  int _traceSequence = 0;

  /// Forgets the previous socket's login and returns the anonymous login to
  /// send first.
  Uint8List beginHandshake() {
    _phase = YyDanmakuPhase.waitingUdb;
    _uid = 0;
    _username = '';
    _password = '';
    _cookie = Uint8List(0);
    _traceSequence = 0;
    return _anonymousLogin();
  }

  /// The AP ping, from the AP login on until a failure; null before (3.x sent
  /// no heartbeat then).
  Uint8List? heartbeat() {
    if (_phase.index < YyDanmakuPhase.waitingAp.index || _phase == YyDanmakuPhase.failed) return null;
    return (YyPacketWriter(uri: _apPingRequestUri)..writeUint32(0)).takeBytes();
  }

  /// Reads one server [frame]: its packets in order, split by their lengths. A
  /// trailer shorter than a header, or a length below 10 or past the end, ends
  /// the frame with a warning. A malformed packet is a failure while joining
  /// and a warning afterwards; unknown packets (pongs, app 103's other counts
  /// and mic queue) are skipped.
  YyDanmakuBatch consume(List<int> frame) {
    final bytes = frame is Uint8List ? frame : Uint8List.fromList(frame);
    final batch = YyDanmakuBatch._();
    var offset = 0;
    while (offset < bytes.length) {
      if (bytes.length - offset < 10) {
        batch.warnings.add('YY WebSocket trailer shorter than 10 bytes');
        break;
      }
      final length = ByteData.sublistView(bytes, offset).getUint32(0, Endian.little);
      if (length < 10 || offset + length > bytes.length) {
        batch.warnings.add('YY WebSocket frame length mismatch: $length/${bytes.length - offset}');
        break;
      }
      _packet(Uint8List.sublistView(bytes, offset, offset + length), batch);
      offset += length;
    }
    return batch;
  }

  void _packet(Uint8List packet, YyDanmakuBatch batch) {
    try {
      final reader = YyPacketReader(packet, hasHeader: true);
      switch (reader.uri) {
        case _anonymousLoginResponseUri:
          _readAnonymousLogin(reader, batch);
        case _apLoginResponseUri:
          _readApLogin(reader, batch);
        case _apRouterResponseUri:
          _readRouter(reader, batch);
        case _userGroupMessageUri:
          _readUserGroup(reader, batch);
        case _bySidMessageUri:
          _readBySid(reader, batch);
      }
    } on FormatException catch (error) {
      if (_phase case YyDanmakuPhase.waitingUdb || YyDanmakuPhase.waitingAp || YyDanmakuPhase.waitingJoin) {
        _fail(batch, 'YY danmaku handshake payload is malformed: $error');
      } else {
        batch.warnings.add('YY danmaku message shape is unexpected: $error');
      }
    } on Object catch (error) {
      batch.warnings.add('YY danmaku message failed to parse: $error');
    }
  }

  void _readAnonymousLogin(YyPacketReader reader, YyDanmakuBatch batch) {
    if (_phase != YyDanmakuPhase.waitingUdb) return;
    reader.readString();
    final envelopeCode = reader.readUint32();
    final realUri = reader.readUint32();
    final payload = reader.readByteArray32();
    if (realUri != _anonymousLoginRealUri) {
      _fail(batch, 'YY anonymous login returned an unknown protocol: $realUri');
      return;
    }
    final fields = YyPacketReader(payload)..readString();
    final resultCode = fields.readUint32();
    final uid32 = fields.readUint32();
    // yyid
    fields.readUint32();
    _username = fields.readString();
    _password = fields.readString();
    _cookie = Uint8List.fromList(fields.readByteArray());
    // The ticket (the AP login uses the cookie and password) and two strings.
    fields
      ..readByteArray()
      ..readString()
      ..readString();
    _uid = fields.bytesAvailable >= 8 ? fields.readUint64() : uid32;
    if (!_isSuccess(envelopeCode) || !_isSuccess(resultCode) || _uid == 0) {
      _fail(batch, 'YY anonymous login failed: $envelopeCode/$resultCode');
      return;
    }
    _phase = YyDanmakuPhase.waitingAp;
    batch.outbound.add(_apLogin());
  }

  void _readApLogin(YyPacketReader reader, YyDanmakuBatch batch) {
    if (_phase != YyDanmakuPhase.waitingAp) return;
    // appid
    reader.readUint32();
    final resultCode = reader.readUint32();
    // context: appid:userType
    reader.readString();
    if (resultCode != 200) {
      _fail(batch, 'YY AP login failed: $resultCode');
      return;
    }
    _phase = YyDanmakuPhase.waitingJoin;
    batch.outbound
      ..add(_joinChannel())
      ..add(_appIdSubscription());
  }

  void _readRouter(YyPacketReader reader, YyDanmakuBatch batch) {
    reader.readString();
    final realUri = reader.readUint32();
    final responseCode = reader.readUint16();
    final payload = reader.readByteArray32();
    if (responseCode != 0 && responseCode != 200) {
      if (realUri == _joinChannelResponseUri) _fail(batch, 'YY channel routing failed: $responseCode');
      return;
    }
    if (realUri == _joinChannelResponseUri) {
      _readJoin(YyPacketReader(payload), batch);
    } else if (realUri == _userGroupMessageUri) {
      _readUserGroup(YyPacketReader(payload), batch);
    }
  }

  void _readJoin(YyPacketReader reader, YyDanmakuBatch batch) {
    if (_phase != YyDanmakuPhase.waitingJoin) return;
    final joinedTopSid = reader.readUint32();
    // uid32
    reader.readUint32();
    final joinedSubSid = reader.readUint32();
    // asid, login time
    reader
      ..readUint32()
      ..readUint32();
    final loginStatus = reader.readUint8();
    final errorInfo = reader.readUtf8String();
    if (loginStatus != _joinedStatus || joinedTopSid != topSid || joinedSubSid != subSid) {
      _fail(batch, 'YY failed to join the channel: $loginStatus${errorInfo.isEmpty ? '' : ', $errorInfo'}');
      return;
    }
    _phase = YyDanmakuPhase.joined;
    batch
      ..outbound.add(_userGroupSubscription(includeChannelGroups: true))
      ..outbound.add(_userGroupSubscription(includeChannelGroups: false))
      .._becameReady = true;
  }

  void _readUserGroup(YyPacketReader reader, YyDanmakuBatch batch) {
    // group type, group id
    reader
      ..readUint64()
      ..readUint64();
    final appId = reader.readUint32();
    _readService(appId, reader.readByteArray32(), batch);
  }

  void _readBySid(YyPacketReader reader, YyDanmakuBatch batch) {
    final appId = reader.readUint16();
    // top channel
    reader.readUint32();
    _readService(appId, reader.readByteArray(), batch);
  }

  void _readService(int appId, Uint8List message, YyDanmakuBatch batch) {
    if (_phase != YyDanmakuPhase.joined || (appId != _chatAppId && appId != _audienceAppId)) return;
    // App 103 also carries another count (3165186) and the mic queue (3140610,
    // 3145730), unread; gifts and entries come in app 15012, not subscribed
    // (M4.D2). A body shorter than a header is nothing to read.
    if (appId == _audienceAppId && message.length < 10) return;
    try {
      final reader = YyPacketReader(message, hasHeader: true);
      final received = switch ((appId, reader.uri)) {
        (_chatAppId, _textChatUri) => _readChat(reader),
        (_audienceAppId, _popularityUri) => _readPopularity(reader),
        _ => null,
      };
      if (received != null) batch.messages.add(received);
    } on FormatException catch (error) {
      batch.warnings.add('YY ${appId == _chatAppId ? 'chat' : 'audience'} message shape is unexpected: $error');
    }
  }

  /// App 103's `3139586`: `u32` the channel's heat (热度), `u32` 1, `u32` top
  /// channel (another channel's is dropped), `u32` a lower figure. Reported as
  /// concurrent viewers (the web room shows this figure).
  LiveMessage? _readPopularity(YyPacketReader reader) {
    final heat = reader.readUint32();
    reader.readUint32();
    if (reader.readUint32() != topSid) return null;
    return LiveMessage(
      type: LiveMessageType.audienceUpdate,
      data: LiveAudienceUpdate(onlineViewers: heat),
      color: YyDanmakuProtocol.defaultColor,
      message: '',
      userName: '',
    );
  }

  /// `u32` sender, `u32` top and sub channel (another channel's chat is
  /// dropped), the chat block (`u32` effects, UCS-2 font, `u32` colour, `u32`
  /// height, UCS-2 text, `u32` screen mode) after its `u16` length, two
  /// strings, then optionally the UTF-8 name and its extra items.
  LiveMessage? _readChat(YyPacketReader reader) {
    // sender uid32
    reader.readUint32();
    final chatTopSid = reader.readUint32();
    final chatSubSid = reader.readUint32();
    if (chatTopSid != topSid || chatSubSid != subSid) return null;
    final chatLength = reader.readUint16();
    final chatEnd = reader.offset + chatLength;
    // effects, font name, colour, font height
    reader
      ..readUint32()
      ..readUcs2String32()
      ..readUint32()
      ..readUint32();
    final text = YyDanmakuProtocol.chatText(reader.readUcs2String32());
    // screen mode
    reader.readUint32();
    if (reader.offset > chatEnd) throw const FormatException('YY chat body length is out of range');
    reader
      ..offset = chatEnd
      ..readString()
      ..readString();
    var userName = '';
    if (reader.bytesAvailable > 0) {
      userName = reader.readUtf8String().trim();
      final extras = reader.readUint32();
      for (var index = 0; index < extras; index++) {
        reader
          ..readUint16()
          ..readUtf8String();
      }
    }
    if (text.isEmpty) return null;
    return LiveMessage(
      type: LiveMessageType.chat,
      userName: userName.isEmpty ? YyDanmakuProtocol.anonymousUserName : userName,
      message: text,
      color: YyDanmakuProtocol.defaultColor,
    );
  }

  Uint8List _anonymousLogin() {
    final payload = YyPacketWriter()
      ..writeString('')
      ..writeUint32(0)
      ..writeString(_deviceId)
      ..writeString(_deviceId)
      ..writeUint32(0)
      ..writeString('yymwebh5');
    return (YyPacketWriter(uri: _anonymousLoginRequestUri)
          ..writeString('')
          ..writeUint32(19822)
          ..writeByteArray32(payload.takeBytes()))
        .takeBytes();
  }

  Uint8List _apLogin() {
    final auth = YyPacketWriter()
      ..writeString(_username)
      ..writeString(_password)
      ..writeUint32(2)
      ..writeUint32(0)
      ..writeUint32(0)
      ..writeString('yytianlaitv')
      ..writeString(_deviceId)
      ..writeString('yymwebn_yymwebh5')
      ..writeUint32(0)
      ..writeUint32(0)
      ..writeUint32(0)
      ..writeUint32(0)
      ..writeString(uuid);
    return (YyPacketWriter(uri: _apLoginRequestUri)
          ..writeByteArray32(auth.takeBytes())
          ..writeUint32(_applicationId)
          ..writeUint64(_uid)
          ..writeUint8(0)
          ..writeByteArray(const [])
          ..writeByteArray(_cookie)
          ..writeString('$_applicationId:0')
          ..writeString('')
          ..writeString('')
          ..writeString('')
          ..writeUint8(0)
          ..writeUint32(0)
          ..writeUint32(0)
          ..writeUint32(0xffffffff)
          ..writeString('')
          ..writeUint32(1)
          ..writeString('BCIFVer')
          ..writeString('V2'))
        .takeBytes();
  }

  Uint8List _appIdSubscription() {
    const appIds = [_chatAppId, 101, 102, 103, 17];
    final writer = YyPacketWriter(uri: _subscribeAppIdsUri)
      ..writeUint64(_uid)
      ..writeUint32(appIds.length);
    appIds.forEach(writer.writeUint32);
    return writer.takeBytes();
  }

  Uint8List _joinChannel() {
    final payload = YyPacketWriter()
      ..writeUint32(_uid & 0xffffffff)
      ..writeUint32(topSid)
      ..writeUint32(subSid)
      // The two anonymous channel properties of the web client (REG-YY-002):
      // without them the router drops the join silently.
      ..writeUint32(2)
      ..writeUint32(2)
      ..writeString('0')
      ..writeUint32(3)
      ..writeString('1')
      ..writeUint64(_uid);
    return _channelRouter(realUri: _joinChannelRequestUri, serviceName: 'channelAuther', payload: payload.takeBytes());
  }

  Uint8List _channelRouter({required int realUri, required String serviceName, required Uint8List payload}) {
    // 3.x's trace id: the uid, the client, a number from the UUID and a
    // sequence.
    final trace = 'F${_uid}_yymwebh5_${uuid.hashCode.abs() % 100000}_${_traceSequence++}';
    final extensions = <(int, List<int>)>[
      (1, (YyPacketWriter()..writeUint32(topSid)).takeBytes()),
      (103, [for (final unit in trace.codeUnits) unit & 0xff]),
    ];
    return (YyPacketWriter(uri: _channelRouterRequestUri)
          ..writeString('')
          ..writeUint32(realUri)
          ..writeUint16(0)
          ..writeByteArray32(payload)
          ..writeByteArray32(_routerHeaders(realUri, serviceName, extensions)))
        .takeBytes();
  }

  /// The router's header sections; a section's length includes its four-byte
  /// tag.
  Uint8List _routerHeaders(int realUri, String serviceName, List<(int, List<int>)> extensions) {
    final writer = YyPacketWriter()
      ..writeUint32(0x01000008)
      ..writeUint32(realUri)
      ..writeUint32(0x02000010)
      ..writeUint32(_applicationId)
      ..writeUint64(_uid)
      ..writeUint32(0x0400000c)
      ..writeUint32(0)
      ..writeUint32(0)
      ..writeUint32(0x05000008)
      ..writeUint32(0)
      // The fixed fields and two string lengths of the route section are 22
      // bytes.
      ..writeUint32(0x06000000 | (22 + serviceName.length))
      ..writeUint32(0)
      ..writeUint16(0)
      ..writeUint32(0)
      ..writeString(serviceName)
      ..writeUint32(0)
      ..writeString('');
    var extensionsLength = 8;
    for (final (_, value) in extensions) {
      extensionsLength += 4 + 2 + value.length;
    }
    writer
      ..writeUint32(0x07000000 | extensionsLength)
      ..writeUint32(extensions.length);
    for (final (key, value) in extensions) {
      writer
        ..writeUint32(key)
        ..writeByteArray(value);
    }
    return (writer
          ..writeUint32(0x08000006)
          ..writeString('')
          ..writeUint32(0xff787878))
        .takeBytes();
  }

  Uint8List _userGroupSubscription({required bool includeChannelGroups}) {
    final groups = [
      [1, 0, topSid, 0],
      [2, 0, subSid, 0],
      if (includeChannelGroups) ...[
        [1024, _applicationId, subSid, topSid],
        [768, _applicationId, 0, topSid],
        [256, _applicationId, 0, topSid],
        [256, _applicationId, subSid, topSid],
      ],
    ];
    final writer = YyPacketWriter(uri: _joinUserGroupUri)
      ..writeUint64(_uid)
      ..writeUint32(groups.length);
    for (final group in groups) {
      group.forEach(writer.writeUint32);
    }
    return (writer..writeString('')).takeBytes();
  }

  void _fail(YyDanmakuBatch batch, String message) {
    _phase = YyDanmakuPhase.failed;
    batch._failure ??= message;
  }

  static bool _isSuccess(int code) => code == 0 || code == 200;
}
