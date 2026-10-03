import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';
import 'package:pure_live/core/logging/core_log.dart';
import 'package:pure_live/core/models/live_message.dart';
import 'package:pure_live/core/network/http_client.dart';
import 'package:pure_live/core/network/web_socket_util.dart';
import 'package:pure_live/shared/platforms/jdlive/jd_live_api.dart';
import 'package:pure_live/shared/platforms/live_danmaku.dart';

/// JD Live 的弹幕参数（上游 M5.24）：`liveId` 就是直播间号（也是聊天的 `groupId`）。
class JdLiveDanmakuArgs {
  const JdLiveDanmakuArgs({required this.liveId});

  final String liveId;
}

/// JD Live 的聊天（上游 M5.24）：**每次握手**都先 POST 一次游客 `liveauth`（不签名，
/// 表单里的 `body.content` 是页面脚本里写死的密钥与 IV 做的 **AES-128-CBC** 加密）换一个
/// **一次性** token，再连 `<liveUrl>?token=<token>`。socket 上**什么都不发**，打开就算加入。
///
/// 只报观众与主播的聊天（`viewer_send_message` / `anchor_send_message`）与
/// `get_statistics_result` 的当前/累计观众；`stop_live_broadcast` 结束连接。
class JdLiveDanmaku extends LiveDanmaku {
  JdLiveDanmaku();

  static const String _authUrl = '${JdLiveApi.apiOrigin}/api';
  static const String _appId = 'jd.mall';
  static const String _secretKey = 'RYm2dMPMWD9AxYFk';
  static const String _iv = '0102030405060708';
  static const String _loginType = '2';
  static const int _origin = -100;
  static const String _anchorName = '主播';

  JdLiveDanmakuArgs? _args;
  WebScoketUtils? _socket;
  var _generation = 0;
  var _running = false;
  Timer? _silenceWatch;

  @override
  Future start(dynamic args) async {
    if (args is! JdLiveDanmakuArgs || args.liveId.trim().isEmpty) {
      onClose?.call('JD Live：没有可用的房间');
      return;
    }
    _args = args;
    _generation++;
    final generation = _generation;
    _running = true;
    unawaited(_loop(generation));
  }

  @override
  Future stop() async {
    _running = false;
    _generation++;
    _silenceWatch?.cancel();
    final socket = _socket;
    _socket = null;
    markDisconnected();
    await socket?.close();
  }

  Future<void> _loop(int generation) async {
    var attempt = 0;
    while (_running && generation == _generation) {
      try {
        final auth = await _auth(generation);
        if (!_running || generation != _generation) return;
        if (auth == null) {
          onClose?.call('JD Live：拿不到聊天令牌');
          return;
        }
        await _runSocket(auth, generation);
        attempt = 0;
      } catch (error) {
        if (generation != _generation) return;
        CoreLog.error('JD Live chat failed: $error');
        onReconnect?.call('JD Live 弹幕连接失败，正在重试');
        attempt++;
      }
      if (!_running || generation != _generation) return;
      await Future<void>.delayed(Duration(seconds: attempt.clamp(1, 8)));
    }
  }

  /// 游客 `liveauth`：表单 `loginType`/`appid`/`functionId`/`body`/`t`，`body` 里的
  /// `content` 是 AES-128-CBC + Base64 的 JSON。
  Future<({Uri socket, String? maskKey})?> _auth(int generation) async {
    final now = DateTime.now();
    final nonce = List<int>.generate(6, (_) => Random.secure().nextInt(10)).join();
    final content = json.encode(<String, Object?>{
      'appId': _appId,
      'secretKey': _secretKey,
      'groupId': _args?.liveId ?? '',
      'clientType': 'm',
      'timestamp': now.millisecondsSinceEpoch,
      'origin': _origin,
      'encryptPin': true,
      'random': nonce,
    });
    final encrypted = base64.encode(
      _aesCbc(
        utf8.encode(content),
        Uint8List.fromList(utf8.encode(_secretKey)),
        Uint8List.fromList(utf8.encode(_iv)),
        encrypt: true,
      ),
    );
    final response = await HttpClient.instance.postJson(
      _authUrl,
      data: <String, String>{
        'loginType': _loginType,
        'appid': 'h5-live',
        'functionId': 'liveauth',
        'body': json.encode(<String, String>{'appId': _appId, 'content': encrypted}),
        't': '${now.millisecondsSinceEpoch}',
      },
      formUrlEncoded: true,
      header: <String, String>{
        'User-Agent': JdLiveApi.userAgent,
        'Origin': JdLiveApi.webOrigin,
        'Referer': '${JdLiveApi.webOrigin}/',
      },
    );
    if (generation != _generation) return null;
    if (response is! Map || response['code'] != 0) {
      final message = response is Map ? response['msg'] : null;
      final data = response is Map ? response['data'] : null;
      final error = data is Map ? data['error'] : null;
      CoreLog.error('JD Live liveauth refused: ${response is Map ? response['code'] : response} $message $error');
      return null;
    }
    final data = response['data'];
    if (data is! Map) return null;
    final token = data['token'];
    final raw = data['liveUrl'];
    final base = raw is String ? Uri.tryParse(raw.trim()) : null;
    if (token is! String || token.trim().isEmpty || base == null) return null;
    if (base.scheme != 'wss' || base.userInfo.isNotEmpty || base.hasQuery || base.hasFragment) return null;
    final host = base.host.toLowerCase();
    if (host != 'jd.com' && !host.endsWith('.jd.com')) return null;
    final maskKey = data['msgMaskKey'];
    return (
      socket: base.replace(queryParameters: <String, String>{'token': token.trim()}),
      maskKey: maskKey is String && maskKey.isNotEmpty ? maskKey : null,
    );
  }

  Future<void> _runSocket(({Uri socket, String? maskKey}) auth, int generation) async {
    final ended = Completer<void>();
    final socket = WebScoketUtils(
      url: auth.socket.toString(),
      heartBeatTime: 0,
      headers: const <String, String>{'origin': JdLiveApi.webOrigin, 'user-agent': JdLiveApi.userAgent},
      onReady: () {
        if (generation != _generation) return;
        // socket 上什么都不发：打开就算加入。
        markConnected();
        onReady?.call();
      },
      onMessage: (event) {
        if (generation != _generation) return;
        _armSilenceWatch(generation, ended);
        _handleFrame(event, auth.maskKey, ended);
      },
      onReconnect: () {
        if (generation != _generation) return;
        markDisconnected();
        onReconnect?.call('与服务器断开连接，正在尝试重连');
      },
      onClose: (error) {
        if (generation != _generation) return;
        markDisconnected();
        if (!ended.isCompleted) ended.complete();
      },
    );
    _socket = socket;
    await socket.connect();
    await ended.future;
    _silenceWatch?.cancel();
  }

  /// 服务端 180 秒没有帧就会断开；这里用更长的 200 秒做静默看门狗。
  void _armSilenceWatch(int generation, Completer<void> ended) {
    _silenceWatch?.cancel();
    _silenceWatch = Timer(const Duration(seconds: 200), () {
      if (generation != _generation || ended.isCompleted) return;
      ended.complete();
    });
  }

  void _handleFrame(Object? data, String? maskKey, Completer<void> ended) {
    final text = switch (data) {
      final String value => value,
      final List<int> bytes => _unmask(bytes, maskKey),
      _ => null,
    };
    if (text == null || text.trim().isEmpty) return;
    final Object? root;
    try {
      root = json.decode(text);
    } catch (_) {
      return;
    }
    if (root is! Map) return;
    final body = root['body'];
    if (body is! Map) return;
    final group = body['groupid'];
    if (group != null && '$group'.trim() != (_args?.liveId ?? '')) return;
    switch (root['type']) {
      case 'get_statistics_result':
        for (final message in _audience(body)) {
          onMessage?.call(message);
        }
        break;
      case 'chat_group_message':
        if (body['type'] == 'stop_live_broadcast') {
          if (!ended.isCompleted) ended.complete();
          return;
        }
        final chat = _chat(root);
        if (chat != null) onMessage?.call(chat);
        break;
      default:
        break;
    }
  }

  /// 观众与主播的聊天；其它种类（进场、点赞、下单、商品、回复、房间状态）不报。
  LiveMessage? _chat(Map<dynamic, dynamic> event) {
    final body = event['body'];
    if (body is! Map) return null;
    final String name;
    switch (body['type']) {
      case 'viewer_send_message':
        final nick = body['nickName'];
        name = nick is String ? nick.trim() : '';
        break;
      case 'anchor_send_message':
        name = _anchorName;
        break;
      default:
        return null;
    }
    final text = body['content'];
    if (text is! String || text.trim().isEmpty) return null;
    final from = event['from'];
    final user = from is Map ? from['pinmd5'] : null;
    final id = event['id'];
    final millis = int.tryParse(event['datetime']?.toString() ?? '');
    return LiveMessage(
      type: LiveMessageType.chat,
      userName: name,
      userId: user is String ? user.trim() : '',
      message: text.trim(),
      messageId: id is String ? id.trim() : '',
      color: LiveMessageColor.white,
      sentAt: millis == null || millis <= 0 || millis > 8640000000000000
          ? null
          : DateTime.fromMillisecondsSinceEpoch(millis),
    );
  }

  /// `get_statistics_result`：`current_viewer` 是当前观众、`total_viwer`（原文如此）
  /// 是累计观看；`pv`、`max_viewer`、`message_num` 等不读。
  List<LiveMessage> _audience(Map<dynamic, dynamic> body) {
    final messages = <LiveMessage>[];
    for (final (key, kind) in const <(String, LiveAudienceMetricKind)>[
      ('current_viewer', LiveAudienceMetricKind.onlineViewers),
      ('total_viwer', LiveAudienceMetricKind.totalViewers),
    ]) {
      final raw = body[key];
      final value = raw is int ? raw : (raw is String ? int.tryParse(raw.trim()) : null);
      if (value == null || value < 0) continue;
      messages.add(
        LiveMessage(
          type: LiveMessageType.online,
          userName: '',
          message: '',
          color: LiveMessageColor.white,
          data: LiveAudienceUpdate(kind: kind, value: value),
        ),
      );
    }
    return messages;
  }

  /// 二进制帧用 `liveauth` 给的 `msgMaskKey` 解掩码（按密钥字节循环异或）；没有密钥
  /// 或解出来不是 UTF-8 就丢掉这一帧。
  static String? _unmask(List<int> bytes, String? maskKey) {
    if (maskKey == null || maskKey.isEmpty) return null;
    final key = utf8.encode(maskKey);
    if (key.isEmpty) return null;
    final plain = Uint8List(bytes.length);
    for (var i = 0; i < bytes.length; i++) {
      plain[i] = bytes[i] ^ key[i % key.length];
    }
    try {
      return utf8.decode(plain);
    } catch (_) {
      return null;
    }
  }

  static Uint8List _aesCbc(List<int> plain, Uint8List key, Uint8List iv, {required bool encrypt}) {
    final cipher = PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()))
      ..init(
        encrypt,
        PaddedBlockCipherParameters<CipherParameters, CipherParameters>(
          ParametersWithIV<KeyParameter>(KeyParameter(key), iv),
          null,
        ),
      );
    return cipher.process(Uint8List.fromList(plain));
  }
}
