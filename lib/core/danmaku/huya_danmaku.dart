import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/tars/types.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/core/tars/huya_danmaku.dart';
import 'package:pure_live/core/site/huya/huya_utils.dart';
import 'package:pure_live/pkg/tars/tup/tars_message.dart';
import 'package:pure_live/core/common/web_socket_util.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';
import 'package:pure_live/pkg/tars/tup/request_packet.dart';
import 'package:pure_live/pkg/tars/codec/tars_input_stream.dart';
import 'package:pure_live/pkg/tars/codec/tars_output_stream.dart';
import 'package:pure_live/core/danmaku/models/huya_damaku_model.dart';

class HuyaDanmakuArgs {
  final int ayyuid;
  final int topSid;
  final int subSid;

  HuyaDanmakuArgs({required this.ayyuid, required this.topSid, required this.subSid});

  @override
  String toString() {
    return json.encode({'ayyuid': ayyuid, 'topSid': topSid, 'subSid': subSid});
  }
}

class HuyaDanmaku implements LiveDanmaku {
  @override
  int heartbeatTime = 60 * 1000;

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
  Function(LiveMessage msg)? onMessage;

  @override
  Function(String msg)? onClose;

  @override
  Function()? onReady;

  String serverUrl = 'wss://cdnws.api.huya.com:443';

  String defaultCookie =
      "__yamid_new=CB839821F9D0000153B312C11F40C3A0; "
      "game_did=c2NmeJsovdYnQ--7ekVF9JDx9YgQBaX9Xb4; "
      "SoundValue=0.50; "
      "guid=0a7d4b0826af6c69380199dc9adc6b50; "
      "__yamid_tt1=0.6713380860053619; "
      "alphaValue=0.80; "
      "_qimei_fingerprint=f573835586d8fec5ce3c6cc8a9ae286e; "
      "guid=0a7d4b0826af6c69380199dc9adc6b50; "
      "udb_guiddata=1a85f8398bc4400eb85f02564f4f321f; "
      "udb_appid=5002; "
      "udb_deviceid=w_1143239981674745856; "
      "isInLiveRoom=true; "
      "__yasmid=0.6713380860053619; "
      "_yasids=__rootsid%3DCBC935D812800001D2591C504BA0A320; "
      "udb_passdata=3; "
      "rep_cnt=38; "
      "_rep_cnt=3; "
      "sdid=csid_beac615f0cf34135b6ea6e1530a0853f; "
      "huya_flash_rep_cnt=60; "
      "huya_web_rep_cnt=214; "
      "huya_ua=webh5&0.1.0&websocket";

  String get cookie => SettingsService.to.cookieManager.huyaCookie.value.isNotEmpty
      ? SettingsService.to.cookieManager.huyaCookie.value
      : defaultCookie;

  String device = "chrome";

  WebScoketUtils? webScoketUtils;

  late HuyaDanmakuArgs danmakuArgs;

  int _generation = 0;

  String get dHuyaUa {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final now = DateTime.now();
    return "webh5&${(now.year % 100).toString().padLeft(2, '0')}${twoDigits(now.month)}${twoDigits(now.day)}${twoDigits(now.hour)}${twoDigits(now.minute)}&websocket";
  }

  List<int> get heartbeatData {
    final cmd = WebSocketCommand()
      ..cmdType = EWebSocketCommandType.EWSCmdC2S_HeartBeatReq.value
      ..data = TarsOutputStream().toUint8List();

    return cmd.toByteArray();
  }

  @override
  void heartbeat() {
    final socket = webScoketUtils;

    if (socket == null) {
      return;
    }

    if (!_connected) {
      return;
    }

    try {
      socket.sendMessage(heartbeatData);
    } catch (e) {
      CoreLog.error('huya_heartbeat_error: $e');
    }
  }

  @override
  Future<void> start(dynamic args) async {
    final generation = ++_generation;

    CoreLog.i('huya_danmaku_start generation=$generation');

    markDisconnected();

    final oldSocket = webScoketUtils;

    webScoketUtils = null;

    if (oldSocket != null) {
      try {
        await oldSocket.close();
      } catch (e) {
        CoreLog.error('huya_close_old_socket_error: $e');
      }
    }

    if (generation != _generation) {
      return;
    }

    danmakuArgs = args as HuyaDanmakuArgs;

    late final WebScoketUtils socket;

    socket = WebScoketUtils(
      url: serverUrl,
      heartBeatTime: heartbeatTime,
      onMessage: (data) {
        if (generation != _generation) {
          return;
        }

        unawaited(decodeMessage(data, generation: generation));
      },
      onReady: () {
        if (generation != _generation) {
          return;
        }

        markConnected();

        try {
          onReady?.call();

          if (generation != _generation) {
            return;
          }

          joinRoom(socket: socket, generation: generation);

          CoreLog.i(
            'huya handshake completed '
            'generation=$generation '
            'pid=${danmakuArgs.topSid}',
          );
        } catch (e, stackTrace) {
          if (generation != _generation) {
            return;
          }

          markDisconnected();

          CoreLog.error('huya_handshake_error: $e\n$stackTrace');

          onClose?.call('虎牙弹幕握手失败$e');
        }
      },
      onHeartBeat: () {
        if (generation != _generation) {
          return;
        }

        heartbeat();
      },
      onReconnect: () {
        if (generation != _generation) {
          return;
        }

        markDisconnected();

        CoreLog.i('huya reconnecting generation=$generation');

        onClose?.call('与服务器断开连接，正在尝试重连');
      },
      onClose: (e) {
        if (generation != _generation) {
          return;
        }

        markDisconnected();

        CoreLog.i(
          'huya socket closed '
          'generation=$generation '
          'error=$e',
        );

        onClose?.call('服务器连接失败$e');
      },
    );

    if (generation != _generation) {
      return;
    }

    webScoketUtils = socket;

    try {
      await socket.connect();
    } catch (e) {
      if (generation != _generation) {
        return;
      }

      markDisconnected();

      CoreLog.error('huya_connect_error: $e');

      onClose?.call('服务器连接失败$e');
    }
  }

  @override
  Future<void> stop() async {
    ++_generation;

    markDisconnected();

    final socket = webScoketUtils;

    webScoketUtils = null;

    CoreLog.i('huya_danmaku_stop generation=$_generation');

    try {
      await socket?.close();
    } catch (e) {
      CoreLog.error('huya_stop_close_error: $e');
    }
  }

  void joinRoom({required WebScoketUtils socket, required int generation}) {
    if (generation != _generation) {
      return;
    }

    if (!identical(socket, webScoketUtils)) {
      return;
    }

    try {
      final pid = danmakuArgs.topSid;

      final data = buildJoinGroupData(pid: pid);

      if (generation != _generation) {
        return;
      }

      socket.sendMessage(data);

      CoreLog.i(
        'huya register group sent '
        'generation=$generation '
        'pid=$pid',
      );
    } catch (e) {
      CoreLog.error('join_data_error: $e');
    }
  }

  List<int> buildJoinGroupData({required int pid}) {
    final wsReq = WsRegisterGroupReq()
      ..groupId = ['live:$pid', 'chat:$pid']
      ..token = '';

    final wsReqByte = wsReq.toByteArray();

    final socketCmd = WebSocketCommand()
      ..cmdType = 16
      ..data = wsReqByte;

    return socketCmd.toByteArray();
  }

  List<int> buildLiveInfoData({required int pid, required String ua, required String device}) {
    final userId = HuyaUserId()
      ..lUid = 0
      ..sGuid = '0a7d4b0826af6c69380199dc9adc6b50'
      ..sToken = ''
      ..sCookie = cookie
      ..sHuYaUA = ua
      ..sDeviceInfo = device;

    final req = GetLivingInfoReq()
      ..lPresenterUid = pid
      ..tId = userId;

    final bodyMap = {'tReq': req.toByteArray()};

    final message = TarsMessage()
      ..header = RequestPacket(
        iVersion: 3,
        iRequestId: 0,
        sServantName: 'huyaliveui',
        sFuncName: 'getLivingInfo',
        sBuffer: RequestPacket.cache_sBuffer,
        context: RequestPacket.cache_context,
        status: RequestPacket.cache_status,
      )
      ..body = bodyMap;

    final messageByte = message.toByteArray();

    final socketCmd = WebSocketCommand()
      ..cmdType = 3
      ..data = messageByte;

    return socketCmd.toByteArray();
  }

  List<int> buildDoLaunchData({required String ua, required String device}) {
    final userId = HuyaUserId()
      ..lUid = 0
      ..sGuid = '0a7d4b0826af6c69380199dc9adc6b50'
      ..sToken = ''
      ..sCookie = cookie
      ..sHuYaUA = ua
      ..sDeviceInfo = device;

    final userBase = LiveUserBase()
      ..eSource = 3
      ..eType = 0
      ..uaEx = LiveAppUAEx();

    final liveLaunchReq = LiveLaunchReq()
      ..id = userId
      ..liveUb = userBase
      ..supportDomain = true;

    final bodyBytes = liveLaunchReq.toByteArray();

    final bodyMap = {'tReq': bodyBytes};

    final message = TarsMessage()
      ..header = RequestPacket(
        iVersion: 3,
        cPacketType: 0,
        iMessageType: 0,
        iRequestId: 0,
        sServantName: 'liveui',
        sFuncName: 'doLaunch',
        sBuffer: RequestPacket.cache_sBuffer,
        context: RequestPacket.cache_context,
        status: RequestPacket.cache_status,
      )
      ..body = bodyMap;

    final messageByte = message.toByteArray();

    final socketCmd = WebSocketCommand()
      ..cmdType = 3
      ..data = messageByte;

    return socketCmd.toByteArray();
  }

  Future<void> decodeMessage(List<int> data, {required int generation}) async {
    if (generation != _generation) {
      return;
    }

    try {
      var stream = TarsInputStream(Uint8List.fromList(data));

      final type = stream.read(0, 0, false);

      if (type == 7) {
        stream = TarsInputStream(stream.readBytes(1, false));

        final wsPushMessage = HYPushMessage();

        wsPushMessage.readFrom(stream);

        if (generation != _generation) {
          return;
        }

        if (wsPushMessage.uri == 1400) {
          final messageNotice = HYMessage();

          messageNotice.readFrom(TarsInputStream(Uint8List.fromList(wsPushMessage.msg)));

          if (generation != _generation) {
            return;
          }

          final uname = messageNotice.userInfo.sNickName;
          final content = messageNotice.content;
          final color = messageNotice.bulletFormat.fontColor;

          onMessage?.call(
            LiveMessage(
              type: LiveMessageType.chat,
              color: color <= 0 ? LiveMessageColor.white : LiveMessageColor.numberToColor(color),
              message: content,
              userName: uname,
            ),
          );
        } else if (wsPushMessage.uri == 8006) {
          final s = TarsInputStream(Uint8List.fromList(wsPushMessage.msg));

          final online = s.read(0, 0, false);

          if (generation != _generation) {
            return;
          }

          onMessage?.call(
            LiveMessage(
              type: LiveMessageType.online,
              data: online,
              color: LiveMessageColor.white,
              message: '',
              userName: '',
            ),
          );
        }

        return;
      }

      if (type == 22) {
        final wsPushMessageV2 = WSPushMessageV2();

        stream = TarsInputStream(stream.readBytes(1, false));

        wsPushMessageV2.readFrom(stream);

        for (final item in wsPushMessageV2.vMsgItem) {
          if (generation != _generation) {
            return;
          }

          if (item.iUri == 2001314) {
            final sc = await getHuyaSuperChatMessageList(lPid: danmakuArgs.topSid);

            if (generation != _generation) {
              return;
            }

            if (sc.isNotEmpty) {
              onMessage?.call(
                LiveMessage(
                  type: LiveMessageType.superChat,
                  userName: 'SUPER_CHAT_MESSAGE',
                  message: 'SUPER_CHAT_MESSAGE',
                  color: LiveMessageColor.white,
                  data: sc.first,
                ),
              );
            }
          }
        }

        return;
      }
    } catch (e, stackTrace) {
      CoreLog.error('huya_decode_error: $e\n$stackTrace');
    }
  }
}
