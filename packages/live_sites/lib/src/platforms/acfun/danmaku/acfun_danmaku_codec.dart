import 'dart:convert';
import 'dart:io' show gzip;
import 'dart:math';
import 'dart:typed_data';

import 'package:live_sites/src/common/crypto/aes_cbc.dart';
import 'package:live_sites/src/common/normalization/site_counts.dart';
import 'package:live_sites/src/models/audience/live_audience_update/live_audience_update.dart';
import 'package:live_sites/src/models/enums/live_audience_signal_kind.dart';
import 'package:live_sites/src/models/enums/live_gift_unit.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/gift/live_gift/live_gift.dart';
import 'package:live_sites/src/models/gift/live_gift_combo/live_gift_combo.dart';
import 'package:live_sites/src/models/gift/live_gift_value/live_gift_value.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/models/message/message_sender/message_sender.dart';
import 'package:live_sites/src/platforms/acfun/api/acfun_endpoints.dart';
import 'package:live_sites/src/platforms/acfun/danmaku/acfun_protobuf.dart';
import 'package:live_sites/src/platforms/acfun/parsers/acfun_room_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// What joining one broadcast's chat needs: the visitor session and the
/// broadcast's tickets from room entry, the `enterRoomAttach` the room command
/// echoes, and two callbacks — a new session with a new `startPlay` (tickets
/// expire with their session) and the room's gift table.
final class AcfunDanmakuArgs {
  /// Creates the arguments.
  AcfunDanmakuArgs({
    required this.authorId,
    required this.liveId,
    required this.visitor,
    required List<String> tickets,
    this.enterRoomAttach = '',
    this.refresh,
    this.gifts,
  }) : tickets = List.unmodifiable(tickets);

  /// The room (author id).
  final String authorId;

  /// The broadcast (`liveId`).
  final String liveId;

  /// The visitor session `startPlay` was asked with; its
  /// [AcfunVisitor.security] may be null, which only the danmaku register
  /// exchange needs.
  final AcfunVisitor visitor;

  /// `availableTickets`, tried in order.
  final List<String> tickets;

  /// `enterRoomAttach`, echoed when entering the room.
  final String enterRoomAttach;

  /// The handshake headers of the web client (UA and Origin).
  Map<String, String> get headers => const {'user-agent': AcfunEndpoints.userAgent, 'origin': AcfunEndpoints.origin};

  /// A new visitor session and broadcast; null when the caller cannot give one.
  final Future<AcfunDanmakuArgs> Function()? refresh;

  /// The room's gift table, asked for once in the background when the session
  /// starts; never throws (an empty catalogue when it cannot be had). Null: no
  /// gift names or prices.
  final Future<AcfunGiftCatalog> Function()? gifts;

  /// Diagnostics without the session secrets.
  @override
  String toString() => 'AcfunDanmakuArgs($authorId, $liveId, ${tickets.length} tickets, $visitor)';
}

/// One packet received on the link, opened by [AcfunDanmakuLink.read].
final class AcfunDanmakuPacket {
  /// Creates a packet.
  const AcfunDanmakuPacket({
    required this.command,
    required this.seqId,
    required this.payload,
    this.errorCode = 0,
    this.error = '',
  });

  /// `DownstreamPayload.command`, like `Basic.Register`.
  final String command;

  /// The header's `seqId` (a push's acknowledgement echoes it).
  final int seqId;

  /// `payloadData`.
  final Uint8List payload;

  /// `errorCode`; 0 is success.
  final int errorCode;

  /// `errorMsg`.
  final String error;
}

/// What one `Push.ZtLiveInteractive.Message` carried: the messages to report,
/// whether the ticket died (`ZtLiveScTicketInvalid`) and the broadcast's new
/// status (`ZtLiveScStatusChanged.type`, or null).
typedef AcfunDanmakuPush = ({List<LiveMessage> messages, bool ticketInvalid, int? statusChanged});

/// AcFun's link protocol, without I/O.
///
/// A frame is `0xABCD`, version 1, the header's and the payload's lengths (big
/// endian `u16 u16 u32 u32`), then the protobuf `PacketHeader` (`appId 1, uid
/// 2, instanceId 3, decodedPayloadLen 7, encryptionMode 8, tokenInfo 9, seqId
/// 10, kpn 12`) and the payload: a 16-byte IV and the AES-128-CBC ciphertext of
/// an `UpstreamPayload` (`command 1, seqId 2, retryCount 3, payloadData 4,
/// subBiz 9`) or a `DownstreamPayload` (`command 1, seqId 2, errorCode 3,
/// payloadData 4, errorMsg 5`). Mode 1 is keyed by `acSecurity` (the register
/// exchange only), mode 2 by the session key the register answer brings, and
/// mode 0 is unsealed.
abstract final class AcfunDanmakuProtocol {
  /// The link server (the Kuaishou live middle platform AcFun's web page
  /// talks to).
  static final Uri endpoint = Uri.parse('wss://link.xiatou.com/');

  /// Frame magic.
  static const int magic = 0xABCD;

  /// Frame version.
  static const int version = 1;

  /// `PacketHeader.appId` of AcFun.
  static const int appId = 13;

  /// Product name (`kpn`).
  static const String kpn = AcfunEndpoints.kpn;

  /// Business line (`subBiz`).
  static const String subBiz = AcfunEndpoints.subBiz;

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

  /// The id of the banana in the gift table.
  static const String bananaId = '1';

  /// The banana's name when the gift table has not come: the platform's own
  /// name for the item, not a sentence to translate.
  static const String bananaName = '香蕉';

  /// Room-command error codes of a dead ticket (the web client's `handleAck`:
  /// it enters again with the next ticket). 1 is an ended broadcast, 8 a new
  /// one — those refresh instead.
  static const Set<int> ticketErrors = {2, 3, 4, 7};

  /// `ZtLiveScStatusChanged.type`s that need new arguments: 1 the broadcast
  /// closed, 2 a new broadcast opened, 4 it was banned. 3 (new stream URLs)
  /// does not concern the chat.
  static const Set<int> refreshingStatuses = {1, 2, 4};

  /// The block, IV and key length of AES-128-CBC.
  static const int aesBlock = 16;

  /// The largest epoch millisecond a platform can mean (a corrupted timestamp
  /// reads as unknown rather as a date in the year 270000).
  static const int maxEpochMilliseconds = 8640000000000000;

  /// `acSecurity` decoded: the 16-byte key of the register exchange, or null
  /// when it is missing or is not a Base64 AES-128 key.
  static Uint8List? securityKey(String? security) {
    if (security == null || security.isEmpty) return null;
    try {
      final key = base64.decode(security);
      return key.length == aesBlock ? Uint8List.fromList(key) : null;
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
  static ({AcfunProtoMessage header, Uint8List payload}) unframe(List<int> frame) {
    final data = frame is Uint8List ? frame : Uint8List.fromList(frame);
    if (data.length < 12) throw const FormatException('AcFun frame shorter than its prefix');
    final view = ByteData.sublistView(data);
    if (view.getUint16(0) != magic) throw const FormatException('AcFun frame without its magic');
    final headerLength = view.getUint32(4);
    final payloadLength = view.getUint32(8);
    if (12 + headerLength + payloadLength != data.length) throw const FormatException('AcFun frame size mismatch');
    return (
      header: AcfunProtoMessage.decode(Uint8List.sublistView(data, 12, 12 + headerLength)),
      payload: Uint8List.sublistView(data, 12 + headerLength),
    );
  }

  /// [plain] sealed under [key] with [iv]: the IV, then the ciphertext.
  static Uint8List seal(List<int> plain, List<int> key, List<int> iv) =>
      Uint8List.fromList([...iv, ...AesCbc.encrypt(plain, key: key, iv: iv)]);

  /// Opens a sealed payload; throws [FormatException] when it is too short or
  /// does not decrypt (a wrong key included).
  static Uint8List open(List<int> sealed, List<int> key) {
    if (sealed.length < 2 * aesBlock) throw const FormatException('AcFun payload shorter than two blocks');
    return Aes128Cbc.decrypt(sealed.sublist(aesBlock), key: key, iv: sealed.sublist(0, aesBlock));
  }

  /// `ZtLiveCsCmdAck`: the answer's type, its error code and payload.
  static ({String type, int code, Uint8List payload}) ack(List<int> payload) {
    final message = AcfunProtoMessage.decode(payload);
    return (type: message.string(1) ?? '', code: message.integer(2) ?? 0, payload: message.bytes(4) ?? Uint8List(0));
  }

  /// `ZtLiveCsEnterRoomAck.heartbeatIntervalMs`, or null when it is missing or
  /// not positive.
  static Duration? heartbeatInterval(List<int> enterRoomAck) {
    final millis = AcfunProtoMessage.decode(enterRoomAck).integer(1) ?? 0;
    return millis > 0 ? Duration(milliseconds: millis) : null;
  }

  /// One `ZtLiveScMessage` (`messageType 1, compressionType 2 (2 is gzip),
  /// payload 3, liveId 4, ticket 5, serverTimestampMs 6`):
  ///
  /// - `ZtLiveScActionSignal` (`{1: [{1 signalType, 2: [payload]}]}`): each
  ///   `CommonActionSignalComment` is a chat, each `CommonActionSignalGift`
  ///   and `AcfunActionSignalThrowBanana` a gift ([gift], [banana]) named and
  ///   priced by [gifts];
  /// - `ZtLiveScStateSignal` (`{1: [{1 signalType, 2 payload}]}`): each
  ///   `CommonStateSignalDisplayInfo` is the concurrent audience;
  /// - `ZtLiveScTicketInvalid` and `ZtLiveScStatusChanged` are flagged.
  ///
  /// Everything else (likes, entries, follows, the banana count, the recent
  /// comments of room entry, notify signals) is not shown. A signal, or one of
  /// its payloads, that does not decode is skipped on its own; a message that
  /// does not decode (or gunzip) yields nothing.
  static AcfunDanmakuPush push(List<int> payload, {AcfunGiftCatalog gifts = AcfunGiftCatalog.empty}) {
    const none = (messages: <LiveMessage>[], ticketInvalid: false, statusChanged: null);
    final messages = <LiveMessage>[];
    try {
      final message = AcfunProtoMessage.decode(payload);
      var body = message.bytes(3) ?? Uint8List(0);
      if (message.integer(2) == 2) body = Uint8List.fromList(gzip.decode(body));
      switch (message.string(1)) {
        case 'ZtLiveScActionSignal':
          for (final item in _signals(body)) {
            final read = switch (item.string(1)) {
              'CommonActionSignalComment' => _comment,
              'CommonActionSignalGift' => (Uint8List payload) => gift(payload, gifts: gifts),
              'AcfunActionSignalThrowBanana' => (Uint8List payload) => banana(payload, gifts: gifts),
              _ => null,
            };
            if (read == null) continue;
            for (final field in item.fields) {
              if (field.number != 2 || field.wireType != AcfunProtoMessage.lengthDelimitedType) continue;
              if (read(field.value as Uint8List) case final found?) messages.add(found);
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
          return (
            messages: messages,
            ticketInvalid: false,
            statusChanged: AcfunProtoMessage.decode(body).integer(1) ?? 0,
          );
      }
    } on FormatException {
      return none;
    }
    return (messages: messages, ticketInvalid: false, statusChanged: null);
  }

  /// `CommonActionSignalGift` (`user 1 {userId 1, nickname 2}, sendTimeMs 2,
  /// giftId 3, count 4 (how many this send gave), combo 5 (the sends of the
  /// combo so far), value 6, comboId 7`), named, priced and pictured by
  /// [gifts]' table. Null without a sender or a gift id.
  ///
  /// Each send of a combo is its own message, with an id of
  /// `<sender>:<comboId>:<combo>`: two equal sends of one viewer must not be
  /// taken for one.
  static LiveMessage? gift(Uint8List payload, {AcfunGiftCatalog gifts = AcfunGiftCatalog.empty}) {
    try {
      final signal = AcfunProtoMessage.decode(payload);
      final user = signal.message(1);
      final id = signal.integer(3);
      if (user == null || id == null || id <= 0) return null;
      final count = _positive(signal.integer(4)) ?? 1;
      final combo = _positive(signal.integer(5));
      final comboId = (signal.string(7) ?? '').trim();
      final data = _gift(
        '$id',
        count,
        gifts: gifts,
        comboKey: comboId,
        comboTotal: combo == null ? null : count * combo,
      );
      final sender = user.integer(1) ?? 0;
      return _giftMessage(user, data, signal.integer(2), id: comboId.isEmpty ? '' : '$sender:$comboId:${combo ?? 0}');
    } on FormatException {
      return null;
    }
  }

  /// `AcfunActionSignalThrowBanana` (`visitor 1 {userId 1, nickname 2}, count
  /// 2, sendTimeMs 3`): bananas, the platform's free currency. Null without a
  /// sender.
  static LiveMessage? banana(Uint8List payload, {AcfunGiftCatalog gifts = AcfunGiftCatalog.empty}) {
    try {
      final signal = AcfunProtoMessage.decode(payload);
      final user = signal.message(1);
      if (user == null) return null;
      return _giftMessage(user, _gift(bananaId, _positive(signal.integer(2)) ?? 1, gifts: gifts), signal.integer(3));
    } on FormatException {
      return null;
    }
  }

  // Helpers -------------------------------------------------------------------

  /// The signals of an action or state signal list (`{1: [signal]}`), each read
  /// on its own; one that does not decode is left out.
  static List<AcfunProtoMessage> _signals(Uint8List body) {
    final signals = <AcfunProtoMessage>[];
    for (final field in AcfunProtoMessage.decode(body).fields) {
      if (field.number != 1 || field.wireType != AcfunProtoMessage.lengthDelimitedType) continue;
      try {
        signals.add(AcfunProtoMessage.decode(field.value as Uint8List));
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
      final signal = AcfunProtoMessage.decode(payload);
      final text = signal.string(1) ?? '';
      final user = signal.message(3);
      if (text.isEmpty || user == null) return null;
      return LiveMessage.normalized(
        text: text,
        sender: _sender(user),
        color: LiveMessageColor.white,
        sentAt: _time(signal.integer(2)),
      );
    } on FormatException {
      return null;
    }
  }

  /// `CommonStateSignalDisplayInfo.watchingCount` (text like `76` or `1.2万`,
  /// the same figure `live/info` calls `onlineCount` at that moment).
  static LiveMessage? _displayInfo(Uint8List? payload) {
    if (payload == null) return null;
    try {
      final watching = parseAudienceNumberOrNull(AcfunProtoMessage.decode(payload).string(1));
      if (watching == null) return null;
      return LiveMessage.normalized(
        type: LiveMessageType.audienceUpdate,
        color: LiveMessageColor.white,
        payload: LiveAudienceUpdate(kind: LiveAudienceSignalKind.onlineViewers, value: watching),
      );
    } on FormatException {
      return null;
    }
  }

  /// The gift a signal describes: named, priced and pictured by [gifts] when
  /// that table has the id, and only by the id when it does not. A banana and
  /// a table entry priced at zero are free; a gift the table has no price for
  /// keeps its value unknown.
  static LiveGift _gift(
    String id,
    int count, {
    required AcfunGiftCatalog gifts,
    String comboKey = '',
    int? comboTotal,
  }) {
    final info = gifts[id];
    final banana = info?.banana ?? id == bananaId;
    final price = info?.price;
    // A banana is free, and so is a table entry priced at zero — the platform
    // takes nothing for either.
    final free = banana || price == 0;
    return LiveGift(
      giftId: id,
      name: info?.name ?? (id == bananaId ? bananaName : ''),
      iconUrl: info?.iconUrl,
      count: count,
      value: LiveGiftValue(
        unit: free
            ? LiveGiftUnit.free
            : price == null
            ? LiveGiftUnit.other
            : LiveGiftUnit.acCoin,
        unitPrice: free || price == null ? null : price.toDouble(),
        totalValue: free || price == null ? null : (price * count).toDouble(),
      ),
      combo: LiveGiftCombo(comboKey: comboKey, comboTotal: comboTotal),
    );
  }

  static LiveMessage _giftMessage(AcfunProtoMessage user, LiveGift gift, int? millis, {String id = ''}) =>
      LiveMessage.normalized(
        type: LiveMessageType.gift,
        text: '${gift.name} x${gift.count}',
        sender: _sender(user),
        color: LiveMessageColor.white,
        payload: gift,
        messageId: id,
        sentAt: _time(millis),
      );

  static MessageSender _sender(AcfunProtoMessage user) {
    final id = user.integer(1);
    return MessageSender.normalized(userId: id == null || id <= 0 ? '' : '$id', userName: user.string(2) ?? '');
  }

  static DateTime? _time(int? millis) => millis == null || millis <= 0 || millis > maxEpochMilliseconds
      ? null
      : DateTime.fromMillisecondsSinceEpoch(millis);

  static int? _positive(int? value) => value != null && value > 0 ? value : null;
}

/// The link of one socket: sequence numbers, the instance id and the session
/// key the register answer brings, and the frames of the web client (register,
/// keep-alive, enter room, heartbeat, push acknowledgement).
final class AcfunDanmakuLink {
  /// Starts a link for [args]; [security] is its decoded `acSecurity`
  /// ([AcfunDanmakuProtocol.securityKey]) and [random] draws the IVs.
  AcfunDanmakuLink({required this.args, required List<int> security, Random? random})
    : _security = Uint8List.fromList(security),
      _random = random ?? Random.secure(),
      _uid = int.tryParse(args.visitor.userId) ?? 0;

  /// The arguments of the broadcast this link joins.
  final AcfunDanmakuArgs args;

  final Uint8List _security;
  final Random _random;
  final int _uid;
  int _seq = 1;
  int _instanceId = 0;
  int _heartbeat = 0;
  Uint8List? _sessionKey;

  /// Whether the register answer brought the session key.
  bool get registered => _sessionKey != null;

  /// `Basic.Register`, sealed with `acSecurity` and carrying the service token
  /// in the header: `RegisterRequest {appInfo 1 {sdkVersion "link-sdk",
  /// linkVersion "1.2.1"}, deviceInfo 2 {platformType 6 (H5), deviceModel
  /// "h5", did 5}, presenceStatus 4, appActiveStatus 5, instanceId 8,
  /// ztCommonInfo 11 {kpn, kpf, uid 4, did 5}}`.
  Uint8List register() {
    final request = AcfunProtoWriter()
      ..bytes(
        1,
        (AcfunProtoWriter()
              ..string(1, 'link-sdk')
              ..string(4, '1.2.1'))
            .toBytes(),
      )
      ..bytes(
        2,
        (AcfunProtoWriter()
              ..integer(1, 6)
              ..string(3, 'h5')
              ..string(5, args.visitor.deviceId))
            .toBytes(),
      )
      ..integer(4, 1)
      ..integer(5, 1)
      ..integer(8, 0)
      ..bytes(
        11,
        (AcfunProtoWriter()
              ..string(1, AcfunDanmakuProtocol.kpn)
              ..string(2, AcfunEndpoints.kpf)
              ..integer(4, _uid)
              ..string(5, args.visitor.deviceId))
            .toBytes(),
      );
    return _send(AcfunDanmakuProtocol.registerCommand, request.toBytes(), serviceToken: true);
  }

  /// `Basic.KeepAlive {presenceStatus 1, appActiveStatus 1}`.
  Uint8List keepAlive() => _send(
    AcfunDanmakuProtocol.keepAliveCommand,
    (AcfunProtoWriter()
          ..integer(1, 1)
          ..integer(2, 1))
        .toBytes(),
  );

  /// Enters the room with [ticket]: `ZtLiveCsEnterRoom {isAuthor 1 false,
  /// reconnectCount 2, enterRoomAttach 4, clientLiveSdkVersion 5}`.
  Uint8List enterRoom({required String ticket, int reconnects = 0}) => _command(
    'ZtLiveCsEnterRoom',
    (AcfunProtoWriter()
          ..integer(1, 0)
          ..integer(2, reconnects)
          ..string(4, args.enterRoomAttach)
          ..string(5, AcfunDanmakuProtocol.sdkVersion))
        .toBytes(),
    ticket,
  );

  /// The next room heartbeat: `ZtLiveCsHeartbeat {clientTimestampMs 1, sequence
  /// 2}`, the sequence counting from 0 on this link.
  Uint8List heartbeat({required String ticket, required DateTime now}) => _command(
    'ZtLiveCsHeartbeat',
    (AcfunProtoWriter()
          ..integer(1, now.millisecondsSinceEpoch)
          ..integer(2, _heartbeat++))
        .toBytes(),
    ticket,
  );

  /// The acknowledgement of [push]: its command without payload, the header
  /// carrying the push's sequence id; the link's own sequence does not move.
  Uint8List pushAck(AcfunDanmakuPacket push) => _send(push.command, null, headerSeq: push.seqId, advance: false);

  /// `ZtLiveCsCmd {cmdType 1, payload 2, ticket 3, liveId 4}` inside the room
  /// command.
  Uint8List _command(String type, List<int> payload, String ticket) => _send(
    AcfunDanmakuProtocol.roomCommand,
    (AcfunProtoWriter()
          ..string(1, type)
          ..bytes(2, payload)
          ..string(3, ticket)
          ..string(4, args.liveId))
        .toBytes(),
  );

  Uint8List _send(String command, List<int>? data, {bool serviceToken = false, int? headerSeq, bool advance = true}) {
    final upstream = AcfunProtoWriter()
      ..string(1, command)
      ..integer(2, _seq)
      ..integer(3, 1);
    if (data != null) upstream.bytes(4, data);
    upstream.string(9, AcfunDanmakuProtocol.subBiz);
    final plain = upstream.toBytes();
    final key = serviceToken ? _security : _sessionKey;
    if (key == null) throw StateError('AcFun link: $command before the register answer');
    final header = AcfunProtoWriter()
      ..integer(1, AcfunDanmakuProtocol.appId)
      ..integer(2, _uid)
      ..integer(3, _instanceId)
      ..integer(7, plain.length)
      ..integer(8, serviceToken ? 1 : 2);
    if (serviceToken) {
      header.bytes(
        9,
        (AcfunProtoWriter()
              ..integer(1, 1)
              ..string(2, args.visitor.token))
            .toBytes(),
      );
    }
    header
      ..integer(10, headerSeq ?? _seq)
      ..string(12, AcfunDanmakuProtocol.kpn);
    if (advance) _seq++;
    final iv = Uint8List.fromList(List.generate(AcfunDanmakuProtocol.aesBlock, (_) => _random.nextInt(256)));
    return AcfunDanmakuProtocol.frame(header.toBytes(), AcfunDanmakuProtocol.seal(plain, key, iv));
  }

  /// Opens one received [frame]. The register answer's session key and instance
  /// id are kept for everything after it. Throws [FormatException] for a frame
  /// that does not add up or does not open.
  AcfunDanmakuPacket read(List<int> frame) {
    final (:header, :payload) = AcfunDanmakuProtocol.unframe(frame);
    final plain = switch (header.integer(8) ?? 0) {
      0 => payload,
      1 => AcfunDanmakuProtocol.open(payload, _security),
      2 => AcfunDanmakuProtocol.open(
        payload,
        _sessionKey ?? (throw const FormatException('AcFun frame before the session key')),
      ),
      final mode => throw FormatException('AcFun encryption mode $mode'),
    };
    final down = AcfunProtoMessage.decode(plain);
    final packet = AcfunDanmakuPacket(
      command: down.string(1) ?? '',
      seqId: header.integer(10) ?? 0,
      payload: down.bytes(4) ?? Uint8List(0),
      errorCode: down.integer(3) ?? 0,
      error: down.string(5) ?? '',
    );
    if (packet.command == AcfunDanmakuProtocol.registerCommand && packet.errorCode == 0) {
      final answer = AcfunProtoMessage.decode(packet.payload);
      final key = answer.bytes(2);
      if (key != null && key.length == AcfunDanmakuProtocol.aesBlock) {
        _sessionKey = Uint8List.fromList(key);
        _instanceId = answer.integer(3) ?? 0;
      }
    }
    return packet;
  }
}
