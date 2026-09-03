import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/core/site/soop/soop_site.dart';
import 'package:pure_live/core/common/utils/list_util.dart';
import 'package:pure_live/core/common/web_socket_util.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';

class SoopDanmakuArgs {
  String url;
  String chatNo;

  SoopDanmakuArgs({required this.url, required this.chatNo});

  SoopDanmakuArgs.fromJson(Map<String, dynamic> json)
    : url = json['url'] ?? '',
      chatNo = json['chatNo'] ?? '';

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'url': url, 'chatNo': chatNo};
  }
}

class SoopDanmaku implements LiveDanmaku {
  bool _connected = false;

  @override
  bool get isConnected => _connected;

  @override
  void markConnected() {
    _connected = true;
  }

  @override
  void markDisconnected() {
    _connected = false;
  }

  @override
  int heartbeatTime = 20 * 1000;

  @override
  Function(LiveMessage msg)? onMessage;
  @override
  Function(String msg)? onClose;
  @override
  Function()? onReady;

  final String f = '\x0c';
  final String esc = '\x1b\x09';

  WebScoketUtils? webScoketUtils;
  late SoopDanmakuArgs danmakuArgs;

  @override
  Future<void> start(dynamic args) async {
    CoreLog.d('SoopDanmaku start');
    if (args == null) {
      onClose?.call('服务器连接失败');
      return;
    }
    danmakuArgs = args as SoopDanmakuArgs;
    final site = Sites.of(Sites.soopSite);
    final liveSite = site.liveSite as SoopSite;
    final mHeaders = liveSite.getHeaders();
    mHeaders.addAll({
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36',
      'Origin': 'https://play.sooplive.co.kr',
    });

    CoreLog.d('SoopDanmaku args: ${json.encode(danmakuArgs.toJson())}');
    webScoketUtils = WebScoketUtils(
      url: danmakuArgs.url,
      heartBeatTime: heartbeatTime,
      protocols: const ['chat'],
      headers: mHeaders,
      onMessage: (e) {
        try {
          if (e is String) {
            decodeMessageStr(e);
          } else if (e is Uint8List || e is List<int>) {
            decodeMessage(List<int>.from(e));
          }
        } catch (err) {
          CoreLog.w('SoopDanmaku decode error raw: $e');
          CoreLog.error(err);
        }
      },
      onReady: () {
        markConnected();
        onReady?.call();
        joinRoom(danmakuArgs);
      },
      onHeartBeat: () {
        heartbeat();
      },
      onReconnect: () {
        markDisconnected();
        onClose?.call('与服务器断开连接，正在尝试重连');
      },
      onClose: (e) {
        markDisconnected();
        onClose?.call('服务器连接失败 $e');
      },
    );
    webScoketUtils?.connect();
  }

  Future<void> joinRoom(SoopDanmakuArgs joinData) async {
    danmakuArgs = joinData;
    final connectPacket = '${esc}000100000600${f * 3}16$f';
    webScoketUtils?.sendMessage(connectPacket);

    await Future.delayed(const Duration(milliseconds: 200));
    final joinPacket =
        '${esc}0002${_calculateByteSize(danmakuArgs.chatNo).toString().padLeft(6, '0')}00$f${danmakuArgs.chatNo}${f * 5}';
    webScoketUtils?.sendMessage(joinPacket);
  }

  int _calculateByteSize(String string) {
    return utf8.encode(string).length + 6;
  }

  @override
  void heartbeat() {
    final pingPacket = '${esc}000000000100$f';
    webScoketUtils?.sendMessage(pingPacket);
  }

  @override
  Future<void> stop() async {
    markDisconnected();
    onMessage = null;
    onClose = null;
    onReady = null;
    webScoketUtils?.close();
    webScoketUtils = null;
  }

  void decodeMessageStr(String data) {
    CoreLog.w('SoopDanmaku decodeMessageStr: $data');
  }

  void decodeMessage(List<int> data) {
    const separatorByte = 0x0c;
    final parts = ListUtil.splitList(data, separatorByte);
    final messages = parts.map((part) => utf8.decode(part)).toList();

    CoreLog.d('Soop chat messages : \n $messages');

    if (messages.length > 5 && !['-1', '1'].contains(messages[1]) && !messages[1].contains('|')) {
      final comment = messages[1];
      final userName = messages[6];
      onMessage?.call(
        LiveMessage(
          type: LiveMessageType.chat,
          color: LiveMessageColor.white,
          message: comment,
          userName: userName,
        ),
      );
    }
  }
}
