import 'dart:convert';
import 'dart:typed_data';

/// Current YY H5 service protocol version published by the YY web client.
const yyH5ServiceProtocolVersion = '3.2.10';

/// Current single-channel endpoint used by YY's H5 service SDK.
const yyH5ServiceWebSocketBaseUrl = 'wss://h5-sinchl.yy.com/websocket';

/// Builds the same endpoint shape as YY's current browser client.
String buildYyH5ServiceWebSocketUrl(String uuid) => Uri.parse(yyH5ServiceWebSocketBaseUrl)
    .replace(
      queryParameters: <String, String>{'appid': 'yymwebh5', 'version': yyH5ServiceProtocolVersion, 'uuid': uuid},
    )
    .toString();

enum YyProtocolPhase { idle, waitingUdb, waitingAp, waitingJoin, joined, failed }

class YyChatMessage {
  const YyChatMessage({required this.userName, required this.message, required this.topSid, required this.subSid});

  final String userName;
  final String message;
  final int topSid;
  final int subSid;
}

class YyProtocolBatch {
  YyProtocolBatch({
    List<Uint8List>? outbound,
    List<YyChatMessage>? chats,
    this.becameReady = false,
    this.failure,
    List<String>? warnings,
  }) : outbound = outbound ?? <Uint8List>[],
       chats = chats ?? <YyChatMessage>[],
       warnings = warnings ?? <String>[];

  final List<Uint8List> outbound;
  final List<YyChatMessage> chats;
  bool becameReady;
  String? failure;
  final List<String> warnings;
}

/// Bounded little-endian decoder for YY's H5 binary protocol.
class YyProtocolReader {
  YyProtocolReader(Uint8List bytes, {this.hasHeader = false}) : _bytes = bytes, _data = ByteData.sublistView(bytes) {
    if (hasHeader) {
      packetLength = readUint32();
      uri = readUint32();
      responseCode = readUint16();
      if (packetLength! < 10 || packetLength! > bytes.length) {
        throw FormatException('YY packet length $packetLength exceeds ${bytes.length} bytes');
      }
    }
  }

  final Uint8List _bytes;
  final ByteData _data;
  final bool hasHeader;

  int offset = 0;
  int? packetLength;
  int? uri;
  int? responseCode;

  int get bytesAvailable => _bytes.length - offset;

  void _require(int length) {
    if (length < 0 || offset + length > _bytes.length) {
      throw FormatException('YY packet is truncated at $offset: need $length, available $bytesAvailable');
    }
  }

  int readUint8() {
    _require(1);
    return _data.getUint8(offset++);
  }

  int readUint16() {
    _require(2);
    final value = _data.getUint16(offset, Endian.little);
    offset += 2;
    return value;
  }

  int readUint32() {
    _require(4);
    final value = _data.getUint32(offset, Endian.little);
    offset += 4;
    return value;
  }

  BigInt readUint64() {
    final low = BigInt.from(readUint32());
    final high = BigInt.from(readUint32());
    return low | (high << 32);
  }

  Uint8List readBytes(int length) {
    _require(length);
    final value = Uint8List.sublistView(_bytes, offset, offset + length);
    offset += length;
    return value;
  }

  Uint8List readByteArray() => readBytes(readUint16());

  Uint8List readByteArray32() => readBytes(readUint32());

  String readString() => String.fromCharCodes(readByteArray());

  String readUtf8String() => utf8.decode(readByteArray(), allowMalformed: true);

  String readUcs2String32() {
    final bytes = readByteArray32();
    final data = ByteData.sublistView(bytes);
    final units = <int>[];
    for (var index = 0; index + 1 < bytes.length; index += 2) {
      units.add(data.getUint16(index, Endian.little));
    }
    return String.fromCharCodes(units);
  }
}

/// Binary encoder matching the current YY web client's PMarshall class.
class YyProtocolWriter {
  YyProtocolWriter({int? uri}) : _uri = uri {
    if (uri != null) {
      writeUint32(10);
      writeUint32(uri);
      writeUint16(200);
    }
  }

  final BytesBuilder _builder = BytesBuilder(copy: false);
  final int? _uri;

  void writeUint8(int value) => _builder.add(<int>[value & 0xff]);

  void writeBool(bool value) => writeUint8(value ? 1 : 0);

  void writeUint16(int value) {
    final bytes = Uint8List(2);
    ByteData.sublistView(bytes).setUint16(0, value & 0xffff, Endian.little);
    _builder.add(bytes);
  }

  void writeUint32(int value) {
    final bytes = Uint8List(4);
    ByteData.sublistView(bytes).setUint32(0, value & 0xffffffff, Endian.little);
    _builder.add(bytes);
  }

  void writeUint64(BigInt value) {
    writeUint32((value & BigInt.from(0xffffffff)).toInt());
    writeUint32(((value >> 32) & BigInt.from(0xffffffff)).toInt());
  }

  void writeBytes(Uint8List bytes) => _builder.add(bytes);

  void writeByteArray(Uint8List bytes) {
    writeUint16(bytes.length);
    writeBytes(bytes);
  }

  void writeByteArray32(Uint8List bytes) {
    writeUint32(bytes.length);
    writeBytes(bytes);
  }

  void writeString(String value) {
    final bytes = Uint8List.fromList(value.codeUnits.map((unit) => unit & 0xff).toList());
    writeByteArray(bytes);
  }

  void writeUtf8String(String value) => writeByteArray(Uint8List.fromList(utf8.encode(value)));

  void writeUcs2String32(String value) {
    final bytes = Uint8List(value.codeUnits.length * 2);
    final data = ByteData.sublistView(bytes);
    for (var index = 0; index < value.codeUnits.length; index++) {
      data.setUint16(index * 2, value.codeUnits[index], Endian.little);
    }
    writeByteArray32(bytes);
  }

  Uint8List takeBytes() {
    final bytes = _builder.takeBytes();
    if (_uri != null) {
      ByteData.sublistView(bytes).setUint32(0, bytes.length, Endian.little);
    }
    return bytes;
  }
}

/// Minimal anonymous YY H5 client state machine.
///
/// It follows the official sequence: anonymous UDB login, AP login, channel
/// authorization, app-id subscription, then channel/service broadcast group
/// subscriptions. Keeping the sequence in one deterministic state machine
/// prevents reconnects from mixing credentials or subscriptions from an old
/// room with the new room.
class YyProtocolSession {
  YyProtocolSession({required this.topSid, required this.subSid, required this.uuid});

  static const _applicationId = 259;
  static const _anonymousLoginRequestUri = 778244;
  static const _anonymousLoginResponseUri = 778500;
  static const _apLoginRequestUri = 775684;
  static const _apLoginResponseUri = 775940;
  static const _apPingRequestUri = 794116;
  static const _apPongResponseUri = 794372;
  static const _apRouterResponseUri = 512011;
  static const _channelRouterRequestUri = 513035;
  static const _joinChannelRequestUri = 2048258;
  static const _joinChannelResponseUri = 2048514;
  static const _joinUserGroupUri = 537944;
  static const _userGroupMessageUri = 533080;
  static const _bySidMessageUri = 28760;
  static const _textChatUri = 3104600;
  static const _subscribeAppIdsUri = 538456;

  final int topSid;
  final int subSid;
  final String uuid;

  YyProtocolPhase phase = YyProtocolPhase.idle;
  BigInt _uid = BigInt.zero;
  String _username = '';
  String _password = '';
  Uint8List _cookie = Uint8List(0);
  int _traceSequence = 0;

  Uint8List beginHandshake() {
    phase = YyProtocolPhase.waitingUdb;
    _uid = BigInt.zero;
    _username = '';
    _password = '';
    _cookie = Uint8List(0);
    _traceSequence = 0;
    return _buildAnonymousLogin();
  }

  Uint8List? buildHeartbeat() {
    if (phase.index < YyProtocolPhase.waitingAp.index || phase == YyProtocolPhase.failed) {
      return null;
    }
    final writer = YyProtocolWriter(uri: _apPingRequestUri)..writeUint32(0);
    return writer.takeBytes();
  }

  YyProtocolBatch consume(Uint8List websocketMessage) {
    final batch = YyProtocolBatch();
    var offset = 0;
    while (offset < websocketMessage.length) {
      if (websocketMessage.length - offset < 10) {
        batch.warnings.add('YY WebSocket 尾部数据不足 10 字节');
        break;
      }
      final header = ByteData.sublistView(websocketMessage, offset);
      final packetLength = header.getUint32(0, Endian.little);
      if (packetLength < 10 || offset + packetLength > websocketMessage.length) {
        batch.warnings.add('YY WebSocket 帧长度异常：$packetLength/${websocketMessage.length - offset}');
        break;
      }
      final packet = Uint8List.sublistView(websocketMessage, offset, offset + packetLength);
      _consumePacket(packet, batch);
      offset += packetLength;
    }
    return batch;
  }

  void _consumePacket(Uint8List packet, YyProtocolBatch batch) {
    try {
      final reader = YyProtocolReader(packet, hasHeader: true);
      switch (reader.uri) {
        case _anonymousLoginResponseUri:
          _consumeAnonymousLogin(reader, batch);
          break;
        case _apLoginResponseUri:
          _consumeApLogin(reader, batch);
          break;
        case _apRouterResponseUri:
          _consumeRouter(reader, batch);
          break;
        case _userGroupMessageUri:
          _consumeUserGroup(reader, batch);
          break;
        case _bySidMessageUri:
          _consumeBySid(reader, batch);
          break;
        case _apPongResponseUri:
          break;
        default:
          break;
      }
    } on FormatException catch (error) {
      if (phase == YyProtocolPhase.waitingUdb ||
          phase == YyProtocolPhase.waitingAp ||
          phase == YyProtocolPhase.waitingJoin) {
        _fail(batch, 'YY 弹幕协议握手数据异常：$error');
      } else {
        batch.warnings.add('YY 弹幕消息格式异常：$error');
      }
    } catch (error) {
      batch.warnings.add('YY 弹幕消息解析异常：$error');
    }
  }

  void _consumeAnonymousLogin(YyProtocolReader reader, YyProtocolBatch batch) {
    if (phase != YyProtocolPhase.waitingUdb) return;
    reader.readString();
    final envelopeCode = reader.readUint32();
    final realUri = reader.readUint32();
    final payload = reader.readByteArray32();
    if (realUri != 20078) {
      _fail(batch, 'YY 匿名登录返回了未知协议：$realUri');
      return;
    }

    final payloadReader = YyProtocolReader(payload);
    payloadReader.readString();
    final resultCode = payloadReader.readUint32();
    final uid32 = payloadReader.readUint32();
    payloadReader.readUint32(); // yyid
    _username = payloadReader.readString();
    _password = payloadReader.readString();
    _cookie = Uint8List.fromList(payloadReader.readByteArray());
    payloadReader.readByteArray(); // ticket, AP anonymous login uses cookie/password
    payloadReader.readString();
    payloadReader.readString();
    _uid = payloadReader.bytesAvailable >= 8 ? payloadReader.readUint64() : BigInt.from(uid32);

    if (!_isSuccess(envelopeCode) || !_isSuccess(resultCode) || _uid == BigInt.zero) {
      _fail(batch, 'YY 匿名登录失败：$envelopeCode/$resultCode');
      return;
    }
    phase = YyProtocolPhase.waitingAp;
    batch.outbound.add(_buildApLogin());
  }

  void _consumeApLogin(YyProtocolReader reader, YyProtocolBatch batch) {
    if (phase != YyProtocolPhase.waitingAp) return;
    reader.readUint32(); // appid
    final resultCode = reader.readUint32();
    reader.readString(); // context: appid:userType
    if (resultCode != 200) {
      _fail(batch, 'YY AP 登录失败：$resultCode');
      return;
    }
    phase = YyProtocolPhase.waitingJoin;
    batch.outbound
      ..add(_buildJoinChannel())
      ..add(_buildAppIdSubscription());
  }

  void _consumeRouter(YyProtocolReader reader, YyProtocolBatch batch) {
    reader.readString();
    final realUri = reader.readUint32();
    final responseCode = reader.readUint16();
    final payload = reader.readByteArray32();
    if (responseCode != 0 && responseCode != 200) {
      if (realUri == _joinChannelResponseUri) {
        _fail(batch, 'YY 加入频道路由失败：$responseCode');
      }
      return;
    }
    if (realUri == _joinChannelResponseUri) {
      _consumeJoinResponse(YyProtocolReader(payload), batch);
    } else if (realUri == _userGroupMessageUri) {
      _consumeUserGroup(YyProtocolReader(payload), batch);
    }
  }

  void _consumeJoinResponse(YyProtocolReader reader, YyProtocolBatch batch) {
    if (phase != YyProtocolPhase.waitingJoin) return;
    final joinedTopSid = reader.readUint32();
    reader.readUint32(); // uid32
    final joinedSubSid = reader.readUint32();
    reader.readUint32(); // asid
    reader.readUint32(); // login timestamp
    final loginStatus = reader.readUint8();
    final errorInfo = reader.readUtf8String();
    if (loginStatus != 4 || joinedTopSid != topSid || joinedSubSid != subSid) {
      _fail(
        batch,
        'YY 加入频道失败：$loginStatus'
        '${errorInfo.isEmpty ? '' : '，$errorInfo'}',
      );
      return;
    }

    phase = YyProtocolPhase.joined;
    batch.outbound
      ..add(_buildUserGroupSubscription(includeChannelGroups: true))
      ..add(_buildUserGroupSubscription(includeChannelGroups: false));
    batch.becameReady = true;
  }

  void _consumeUserGroup(YyProtocolReader reader, YyProtocolBatch batch) {
    reader.readUint64(); // group type
    reader.readUint64(); // group id
    final appId = reader.readUint32();
    final message = reader.readByteArray32();
    _consumeServiceMessage(appId, message, batch);
  }

  void _consumeBySid(YyProtocolReader reader, YyProtocolBatch batch) {
    final appId = reader.readUint16();
    reader.readUint32(); // topSid envelope field
    final message = reader.readByteArray();
    _consumeServiceMessage(appId, message, batch);
  }

  void _consumeServiceMessage(int appId, Uint8List message, YyProtocolBatch batch) {
    if (phase != YyProtocolPhase.joined || appId != 31) return;
    try {
      final reader = YyProtocolReader(message, hasHeader: true);
      if (reader.uri != _textChatUri) return;
      final chat = _readChat(reader);
      if (chat != null) batch.chats.add(chat);
    } on FormatException catch (error) {
      batch.warnings.add('YY 聊天消息格式异常：$error');
    }
  }

  YyChatMessage? _readChat(YyProtocolReader reader) {
    reader.readUint32(); // sender uid32
    final messageTopSid = reader.readUint32();
    final messageSubSid = reader.readUint32();
    if (messageTopSid != topSid || messageSubSid != subSid) return null;

    final chatLength = reader.readUint16();
    final chatEnd = reader.offset + chatLength;
    reader.readUint32(); // font effects
    reader.readUcs2String32(); // font name
    reader.readUint32(); // color
    reader.readUint32(); // font height
    final message = reader.readUcs2String32().trim();
    reader.readUint32(); // screen mode
    if (reader.offset > chatEnd) {
      throw const FormatException('YY 聊天正文长度越界');
    }
    reader.offset = chatEnd;

    reader.readString();
    reader.readString();
    var userName = '';
    if (reader.bytesAvailable > 0) {
      userName = reader.readUtf8String().trim();
      final extraCount = reader.readUint32();
      for (var index = 0; index < extraCount; index++) {
        reader.readUint16();
        reader.readUtf8String();
      }
    }
    if (message.isEmpty) return null;
    return YyChatMessage(
      userName: userName.isEmpty ? 'YY用户' : userName,
      message: message,
      topSid: messageTopSid,
      subSid: messageSubSid,
    );
  }

  Uint8List _buildAnonymousLogin() {
    final payload = YyProtocolWriter()
      ..writeString('')
      ..writeUint32(0)
      ..writeString('B8-97-5A-17-AD-4D')
      ..writeString('B8-97-5A-17-AD-4D')
      ..writeUint32(0)
      ..writeString('yymwebh5');
    final writer = YyProtocolWriter(uri: _anonymousLoginRequestUri)
      ..writeString('')
      ..writeUint32(19822)
      ..writeByteArray32(payload.takeBytes());
    return writer.takeBytes();
  }

  Uint8List _buildApLogin() {
    final auth = YyProtocolWriter()
      ..writeString(_username)
      ..writeString(_password)
      ..writeUint32(2)
      ..writeUint32(0)
      ..writeUint32(0)
      ..writeString('yytianlaitv')
      ..writeString('B8-97-5A-17-AD-4D')
      ..writeString('yymwebn_yymwebh5')
      ..writeUint32(0)
      ..writeUint32(0)
      ..writeUint32(0)
      ..writeUint32(0)
      ..writeString(uuid);
    final writer = YyProtocolWriter(uri: _apLoginRequestUri)
      ..writeByteArray32(auth.takeBytes())
      ..writeUint32(_applicationId)
      ..writeUint64(_uid)
      ..writeBool(false)
      ..writeByteArray(Uint8List(0))
      ..writeByteArray(_cookie)
      ..writeString('259:0')
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
      ..writeString('V2');
    return writer.takeBytes();
  }

  Uint8List _buildAppIdSubscription() {
    const appIds = <int>[31, 101, 102, 103, 17];
    final writer = YyProtocolWriter(uri: _subscribeAppIdsUri)
      ..writeUint64(_uid)
      ..writeUint32(appIds.length);
    for (final appId in appIds) {
      writer.writeUint32(appId);
    }
    return writer.takeBytes();
  }

  Uint8List _buildJoinChannel() {
    final payload = YyProtocolWriter()
      ..writeUint32((_uid & BigInt.from(0xffffffff)).toInt())
      ..writeUint32(topSid)
      ..writeUint32(subSid)
      // YY 3.2.10 sends these two anonymous channel properties before uid64.
      // Omitting them leaves the socket open but the router silently drops the
      // join request, so the client never reaches the danmaku groups.
      ..writeUint32(2)
      ..writeUint32(2)
      ..writeString('0')
      ..writeUint32(3)
      ..writeString('1')
      ..writeUint64(_uid);
    return _buildChannelRouter(
      realUri: _joinChannelRequestUri,
      serviceName: 'channelAuther',
      payload: payload.takeBytes(),
    );
  }

  Uint8List _buildChannelRouter({required int realUri, required String serviceName, required Uint8List payload}) {
    final topSidBytes = YyProtocolWriter()..writeUint32(topSid);
    final traceId = 'F${_uid}_yymwebh5_${uuid.hashCode.abs() % 100000}_${_traceSequence++}';
    final extensions = <MapEntry<int, Object>>[
      MapEntry<int, Object>(1, topSidBytes.takeBytes()),
      MapEntry<int, Object>(103, traceId),
    ];
    final headers = _buildRouterHeaders(realUri, serviceName, extensions);
    final writer = YyProtocolWriter(uri: _channelRouterRequestUri)
      ..writeString('')
      ..writeUint32(realUri)
      ..writeUint16(0)
      ..writeByteArray32(payload)
      ..writeByteArray32(headers);
    return writer.takeBytes();
  }

  Uint8List _buildRouterHeaders(int realUri, String serviceName, List<MapEntry<int, Object>> extensions) {
    final writer = YyProtocolWriter()
      ..writeUint32(0x01000008)
      ..writeUint32(realUri)
      ..writeUint32(0x02000010)
      ..writeUint32(_applicationId)
      ..writeUint64(_uid)
      ..writeUint32(0x0400000c)
      ..writeUint32(0)
      ..writeUint32(0)
      ..writeUint32(0x05000008)
      ..writeUint32(0);

    // YY section lengths include the four-byte section tag. The remaining
    // fixed fields and two string-length prefixes account for 22 bytes.
    final routeSectionLength = 22 + serviceName.length;
    writer
      ..writeUint32(0x06000000 | routeSectionLength)
      ..writeUint32(0)
      ..writeUint16(0)
      ..writeUint32(0)
      ..writeString(serviceName)
      ..writeUint32(0)
      ..writeString('');

    var extensionSectionLength = 8;
    for (final extension in extensions) {
      final valueLength = extension.value is Uint8List
          ? (extension.value as Uint8List).length
          : (extension.value as String).length;
      extensionSectionLength += 4 + 2 + valueLength;
    }
    writer
      ..writeUint32(0x07000000 | extensionSectionLength)
      ..writeUint32(extensions.length);
    for (final extension in extensions) {
      writer.writeUint32(extension.key);
      final value = extension.value;
      if (value is Uint8List) {
        writer.writeByteArray(value);
      } else {
        writer.writeString(value as String);
      }
    }
    writer
      ..writeUint32(0x08000006)
      ..writeString('')
      ..writeUint32(0xff787878);
    return writer.takeBytes();
  }

  Uint8List _buildUserGroupSubscription({required bool includeChannelGroups}) {
    final groups = includeChannelGroups
        ? <List<int>>[
            <int>[1, 0, topSid, 0],
            <int>[2, 0, subSid, 0],
            <int>[1024, 259, subSid, topSid],
            <int>[768, 259, 0, topSid],
            <int>[256, 259, 0, topSid],
            <int>[256, 259, subSid, topSid],
          ]
        : <List<int>>[
            <int>[1, 0, topSid, 0],
            <int>[2, 0, subSid, 0],
          ];
    final writer = YyProtocolWriter(uri: _joinUserGroupUri)
      ..writeUint64(_uid)
      ..writeUint32(groups.length);
    for (final group in groups) {
      for (final value in group) {
        writer.writeUint32(value);
      }
    }
    writer.writeString('');
    return writer.takeBytes();
  }

  void _fail(YyProtocolBatch batch, String message) {
    phase = YyProtocolPhase.failed;
    batch.failure ??= message;
  }

  bool _isSuccess(int code) => code == 0 || code == 200;
}
