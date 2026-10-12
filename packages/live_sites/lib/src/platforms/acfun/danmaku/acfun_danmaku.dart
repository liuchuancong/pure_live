import 'dart:convert';
import 'dart:io' show gzip;
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:live_sites/src/common/protobuf/protobuf.dart';
import 'package:live_sites/src/models/live_gift/live_gift.dart';
import 'package:live_sites/src/models/live_message/live_message.dart';

/// AcFun's link protocol frame codec and `acSecurity` seal, without the
/// session. The command builders that `seal`/`open` and the `push` decode land
/// with the socket session (which awaits them).
///
/// A frame is `0xABCD`, version 1, the header's and the payload's lengths
/// (big-endian `u16 u16 u32 u32`), then the protobuf `PacketHeader` (`appId 1,
/// uid 2, instanceId 3, decodedPayloadLen 7, encryptionMode 8, tokenInfo 9,
/// seqId 10, kpn 12`) and the payload: a 16-byte IV and the AES-128-CBC
/// ciphertext of an `UpstreamPayload` (`command 1, seqId 2, retryCount 3,
/// payloadData 4, subBiz 9`) or a `DownstreamPayload` (`command 1, seqId 2,
/// errorCode 3, payloadData 4, errorMsg 5`). Mode 1 is keyed by `acSecurity`
/// (the register exchange), mode 2 by the session key the register answer
/// brings.
abstract final class AcfunDanmakuProtocol {
  /// The link server.
  static final Uri endpoint = Uri.parse('wss://link.xiatou.com/');

  /// Frame magic.
  static const int magic = 0xABCD;

  /// Frame version.
  static const int version = 1;

  /// `PacketHeader.appId` of AcFun.
  static const int appId = 13;

  /// Product name (`kpn`).
  static const String kpn = 'ACFUN_APP';

  /// Product flavour (`kpf`).
  static const String kpf = 'PC_WEB';

  /// Business line (`subBiz`).
  static const String subBiz = 'mainApp';

  /// `clientLiveSdkVersion` of the enter-room command.
  static const String sdkVersion = 'kwai-acfun-live-link';

  /// Register command.
  static const String registerCommand = 'Basic.Register';

  /// Keep-alive command.
  static const String keepAliveCommand = 'Basic.KeepAlive';

  /// Room commands (enter room, heartbeat) and their answers.
  static const String roomCommand = 'Global.ZtLiveInteractive.CsCmd';

  /// Room messages.
  static const String messageCommand = 'Push.ZtLiveInteractive.Message';

  /// Prefix of the commands the server pushes (each one is acknowledged).
  static const String pushPrefix = 'Push.';

  /// The enter-room answer's type.
  static const String enterRoomAck = 'ZtLiveCsEnterRoomAck';

  /// Room-command error codes of a dead ticket (the web client's `handleAck`:
  /// it enters again with the next ticket). 1 is an ended broadcast, 8 a new
  /// one.
  static const Set<int> ticketErrors = {2, 3, 4, 7};

  /// `ZtLiveScStatusChanged.type`s that need new arguments: 1 the broadcast
  /// closed, 2 a new broadcast opened, 4 it was banned. 3 (new stream URLs)
  /// does not concern the chat.
  static const Set<int> refreshingStatuses = {1, 2, 4};

  static const int _aesBlock = 16;

  static final AesCbc _aes = AesCbc.with128bits(macAlgorithm: MacAlgorithm.empty);

  /// `acSecurity` decoded: the 16-byte key of the register exchange, or null
  /// when it is missing or not a Base64 AES-128 key.
  static Uint8List? securityKey(String? security) {
    if (security == null || security.isEmpty) return null;
    try {
      final key = base64.decode(security);
      return key.length == _aesBlock ? Uint8List.fromList(key) : null;
    } on FormatException {
      return null;
    }
  }

  /// Wraps an encoded [header] and [payload] in a frame.
  static Uint8List frame(List<int> header, List<int> payload) {
    final out = Uint8List(12 + header.length + payload.length);
    ByteData.sublistView(out)
      ..setUint16(0, magic)
      ..setUint16(2, version)
      ..setUint32(4, header.length)
      ..setUint32(8, payload.length);
    out
      ..setAll(12, header)
      ..setAll(12 + header.length, payload);
    return out;
  }

  /// Splits a [frame] into its header and (still sealed) payload; throws
  /// [FormatException] without the magic or when the lengths do not add up.
  static ({ProtoMessage header, Uint8List payload}) unframe(List<int> frame) {
    final data = frame is Uint8List ? frame : Uint8List.fromList(frame);
    if (data.length < 12) throw const FormatException('AcFun frame shorter than its prefix');
    final view = ByteData.sublistView(data);
    if (view.getUint16(0) != magic) throw const FormatException('AcFun frame without its magic');
    final headerLength = view.getUint32(4);
    final payloadLength = view.getUint32(8);
    if (12 + headerLength + payloadLength != data.length) throw const FormatException('AcFun frame size mismatch');
    return (
      header: ProtoMessage.decode(Uint8List.sublistView(data, 12, 12 + headerLength)),
      payload: Uint8List.sublistView(data, 12 + headerLength),
    );
  }

  /// [plain] sealed under [key] with [iv]: the IV, then the AES-128-CBC
  /// ciphertext (PKCS#7).
  static Future<Uint8List> seal(List<int> plain, List<int> key, List<int> iv) async {
    final box = await _aes.encrypt(plain, secretKey: SecretKey(key), nonce: iv);
    return Uint8List.fromList([...iv, ...box.cipherText]);
  }

  /// Opens a [seal]ed payload (its first 16 bytes are the IV); throws
  /// [FormatException] when it is too short or does not decrypt (a wrong key).
  static Future<Uint8List> open(List<int> sealed, List<int> key) async {
    if (sealed.length <= _aesBlock) throw const FormatException('AcFun sealed payload too short');
    final iv = sealed.sublist(0, _aesBlock);
    final cipher = Uint8List.fromList(sealed.sublist(_aesBlock));
    try {
      final plain = await _aes.decrypt(
        SecretBox(cipher, nonce: iv, mac: Mac.empty),
        secretKey: SecretKey(key),
      );
      return Uint8List.fromList(plain);
    } on Object {
      throw const FormatException('AcFun payload did not decrypt');
    }
  }

  /// `ZtLiveCsCmdAck`: the answer's type, its error code and payload.
  static ({String type, int code, Uint8List payload}) ack(List<int> payload) {
    final message = ProtoMessage.decode(payload);
    return (type: message.string(1) ?? '', code: message.integer(2) ?? 0, payload: message.bytes(4) ?? Uint8List(0));
  }

  /// `ZtLiveCsEnterRoomAck.heartbeatIntervalMs`, or null when it is missing or
  /// not positive.
  static Duration? heartbeatInterval(List<int> enterRoomAck) {
    final millis = ProtoMessage.decode(enterRoomAck).integer(1) ?? 0;
    return millis > 0 ? Duration(milliseconds: millis) : null;
  }

  static const int _maxEpochMilliseconds = 8640000000000000;

  /// The id of the banana in the (unfetched) gift table.
  static const String bananaId = '1';

  /// The banana's name without the gift table: the platform's own word for it.
  static const String bananaName = '香蕉';

  /// One `ZtLiveScMessage` (`messageType 1, compressionType 2 (gzip), payload
  /// 3, ...`): a `ZtLiveScActionSignal` reads each `CommonActionSignalComment`
  /// as chat, each `CommonActionSignalGift` and `AcfunActionSignalThrowBanana`
  /// as a gift ([push]); a `ZtLiveScStateSignal` reads each
  /// `CommonStateSignalDisplayInfo` as the concurrent audience; and
  /// `ZtLiveScTicketInvalid` / `ZtLiveScStatusChanged` are flagged. This build
  /// does not fetch the room's gift table, so a gift carries only its name
  /// (`香蕉` for the banana, else `礼物 {id}`), count and combo id.
  static AcfunDanmakuPush push(List<int> payload) {
    const none = (messages: <LiveMessage>[], ticketInvalid: false, statusChanged: null);
    final messages = <LiveMessage>[];
    try {
      final message = ProtoMessage.decode(payload);
      var body = message.bytes(3) ?? Uint8List(0);
      if (message.integer(2) == 2) body = Uint8List.fromList(gzip.decode(body));
      switch (message.string(1)) {
        case 'ZtLiveScActionSignal':
          for (final item in _signals(body)) {
            final read = switch (item.string(1)) {
              'CommonActionSignalComment' => _comment,
              'CommonActionSignalGift' => _giftSignal,
              'AcfunActionSignalThrowBanana' => _bananaSignal,
              _ => null,
            };
            if (read == null) continue;
            for (final field in item.fields) {
              if (field.number != 2 || field.wireType != ProtoMessage.lengthDelimitedType) continue;
              if (read(field.value as Uint8List) case final decoded?) messages.add(decoded);
            }
          }
        case 'ZtLiveScStateSignal':
          for (final item in _signals(body)) {
            if (item.string(1) != 'CommonStateSignalDisplayInfo') continue;
            if (_displayInfo(item.bytes(2)) case final audience?) messages.add(audience);
          }
        case 'ZtLiveScTicketInvalid':
          return (messages: messages, ticketInvalid: true, statusChanged: null);
        case 'ZtLiveScStatusChanged':
          return (messages: messages, ticketInvalid: false, statusChanged: ProtoMessage.decode(body).integer(1) ?? 0);
      }
    } on FormatException {
      return none;
    }
    return (messages: messages, ticketInvalid: false, statusChanged: null);
  }

  /// The signals of an action or state signal list (`{1: [signal]}`), each
  /// read on its own; one that does not decode is left out.
  static List<ProtoMessage> _signals(Uint8List body) {
    final signals = <ProtoMessage>[];
    for (final field in ProtoMessage.decode(body).fields) {
      if (field.number != 1 || field.wireType != ProtoMessage.lengthDelimitedType) continue;
      try {
        signals.add(ProtoMessage.decode(field.value as Uint8List));
      } on FormatException {
        continue;
      }
    }
    return signals;
  }

  /// `CommonActionSignalComment` (`content 1, sendTimeMs 2, userInfo 3
  /// {userId 1, nickname 2}`); none without text or sender.
  static LiveMessage? _comment(Uint8List payload) {
    try {
      final signal = ProtoMessage.decode(payload);
      final text = signal.string(1) ?? '';
      final user = signal.message(3);
      if (text.isEmpty || user == null) return null;
      final id = user.integer(1);
      return LiveMessage(
        type: LiveMessageType.chat,
        userName: user.string(2) ?? '',
        userId: id == null || id <= 0 ? '' : '$id',
        message: text,
        color: 0xFFFFFF,
        sentAt: _time(signal.integer(2)),
      );
    } on FormatException {
      return null;
    }
  }

  /// `CommonActionSignalGift` (`user 1, sendTimeMs 2, giftId 3, count 4,
  /// combo 5, value 6, comboId 7`). Without the gift table the name is
  /// `香蕉`/`礼物 {id}` and there is no price. The combo key is `comboId`.
  static LiveMessage? _giftSignal(Uint8List payload) {
    try {
      final signal = ProtoMessage.decode(payload);
      final user = signal.message(1);
      final id = signal.integer(3);
      if (user == null || id == null || id <= 0) return null;
      final count = _positive(signal.integer(4)) ?? 1;
      final comboId = (signal.string(7) ?? '').trim();
      final name = id == 1 ? bananaName : '礼物 $id';
      final sender = user.integer(1) ?? 0;
      return LiveMessage(
        type: LiveMessageType.gift,
        userName: user.string(2) ?? '',
        userId: sender <= 0 ? '' : '$sender',
        message: '$name ×$count',
        color: 0xFFFFFF,
        id: comboId.isEmpty ? null : '$sender:$comboId:${_positive(signal.integer(5)) ?? 0}',
        sentAt: _time(signal.integer(2)),
        data: LiveGift(name: name, count: count, combo: comboId.isEmpty ? null : comboId),
      );
    } on FormatException {
      return null;
    }
  }

  /// `AcfunActionSignalThrowBanana` (`visitor 1 {userId 1, nickname 2},
  /// count 2, sendTimeMs 3`): bananas, free. Null without a sender.
  static LiveMessage? _bananaSignal(Uint8List payload) {
    try {
      final signal = ProtoMessage.decode(payload);
      final user = signal.message(1);
      if (user == null) return null;
      final count = _positive(signal.integer(2)) ?? 1;
      final sender = user.integer(1) ?? 0;
      return LiveMessage(
        type: LiveMessageType.gift,
        userName: user.string(2) ?? '',
        userId: sender <= 0 ? '' : '$sender',
        message: '$bananaName ×$count',
        color: 0xFFFFFF,
        sentAt: _time(signal.integer(3)),
        data: LiveGift(name: bananaName, count: count),
      );
    } on FormatException {
      return null;
    }
  }

  /// `CommonStateSignalDisplayInfo.watchingCount` (`1`), a count like `76` or
  /// `1.2万`; the concurrent audience as one update. Null when it will not
  /// parse.
  static LiveMessage? _displayInfo(Uint8List? payload) {
    if (payload == null) return null;
    try {
      final watching = _chineseCount(ProtoMessage.decode(payload).string(1));
      if (watching == null) return null;
      return LiveMessage(
        type: LiveMessageType.audienceUpdate,
        userName: '',
        message: '',
        data: LiveAudienceUpdate(onlineViewers: watching),
      );
    } on FormatException {
      return null;
    }
  }

  static int? _chineseCount(String? text) {
    final match = RegExp(r'^([\d.]+)\s*([千万亿])?$').firstMatch((text ?? '').trim());
    if (match == null) return null;
    final value = double.tryParse(match.group(1) ?? '');
    if (value == null) return null;
    final multiplier = switch (match.group(2)) {
      '万' => 10000,
      '千' => 1000,
      '亿' => 100000000,
      _ => 1,
    };
    return (value * multiplier).round();
  }

  static DateTime? _time(int? millis) => millis == null || millis <= 0 || millis > _maxEpochMilliseconds
      ? null
      : DateTime.fromMillisecondsSinceEpoch(millis);

  static int? _positive(int? value) => value != null && value > 0 ? value : null;
}

/// What one `Push.ZtLiveInteractive.Message` carried: the messages to report,
/// whether the ticket died (`ZtLiveScTicketInvalid`) and the broadcast's new
/// status (`ZtLiveScStatusChanged.type`, or null).
typedef AcfunDanmakuPush = ({List<LiveMessage> messages, bool ticketInvalid, int? statusChanged});
