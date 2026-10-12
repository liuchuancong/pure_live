import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:live_sites/src/common/protobuf/protobuf.dart';

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
}
