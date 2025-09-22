// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pure_live/common/models/live_message.dart';
import 'package:pure_live/common/utils/color_util.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/core/common/web_socket_util.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';
import 'package:tars_dart/tars/codec/tars_input_stream.dart';
import 'package:tars_dart/tars/codec/tars_output_stream.dart';
import 'package:tars_dart/tars/codec/tars_struct.dart';

class HuyaDanmakuArgs {
  final int ayyuid;
  final int topSid;
  final int subSid;

  HuyaDanmakuArgs({
    required this.ayyuid,
    required this.topSid,
    required this.subSid,
  });

  @override
  String toString() {
    return json.encode({
      "ayyuid": ayyuid,
      "topSid": topSid,
      "subSid": subSid,
    });
  }
}

class HuyaDanmaku implements LiveDanmaku {
  @override
  int heartbeatTime = 60 * 1000;

  @override
  Function(LiveMessage msg)? onMessage;
  @override
  Function(String msg)? onClose;
  @override
  Function()? onReady;
  String serverUrl = "wss://cdnws.api.huya.com";

  WebScoketUtils? webScoketUtils;

  final heartbeatData = base64.decode("ABQdAAwsNgBM");

  late HuyaDanmakuArgs danmakuArgs;

  @override
  Future start(dynamic args) async {
    danmakuArgs = args as HuyaDanmakuArgs;
    webScoketUtils = WebScoketUtils(
      url: serverUrl,
      heartBeatTime: heartbeatTime,
      onMessage: (e) {
        decodeMessage(e);
      },
      onReady: () {
        onReady?.call();
        joinRoom();
      },
      onHeartBeat: () {
        heartbeat();
      },
      onReconnect: () {
        onClose?.call("与服务器断开连接，正在尝试重连");
      },
      onClose: (e) {
        onClose?.call("服务器连接失败$e");
      },
    );
    webScoketUtils?.connect();
  }

  void joinRoom() {
    var joinData = getJoinData(danmakuArgs.ayyuid, danmakuArgs.topSid, danmakuArgs.topSid);
    webScoketUtils?.sendMessage(joinData);
  }

  List<int> getJoinData(int ayyuid, int tid, int sid) {
    try {
      var oos = TarsOutputStream();
      oos.write(ayyuid, 0);
      oos.write(true, 1);
      oos.write("", 2);
      oos.write("", 3);
      oos.write(tid, 4);
      oos.write(sid, 5);
      oos.write(0, 6);
      oos.write(0, 7);

      var wscmd = TarsOutputStream();
      wscmd.write(1, 0);
      wscmd.write(oos.toUint8List(), 1);
      return wscmd.toUint8List();
    } catch (e) {
      CoreLog.error(e);
      return [];
    }
  }

  @override
  void heartbeat() {
    webScoketUtils?.sendMessage(heartbeatData);
  }

  @override
  Future stop() async {
    onMessage = null;
    onClose = null;
    webScoketUtils?.close();
  }

  void decodeMessage(List<int> data) {
    try {
      var stream = TarsInputStream(Uint8List.fromList(data));
      var type = stream.read(0, 0, false);
      if (type == 7) {
        stream = TarsInputStream(stream.readBytes(1, false));
        HYPushMessage wSPushMessage = HYPushMessage();
        wSPushMessage.readFrom(stream);
        if (wSPushMessage.uri == 1400) {
          HYMessage messageNotice = HYMessage();
          messageNotice.readFrom(TarsInputStream(Uint8List.fromList(wSPushMessage.msg)));
          var uname = messageNotice.userInfo.nickName;
          // var nobleLevel = messageNotice.userInfo.iNobleLevel.toString();
          var content = messageNotice.content;

          var color = messageNotice.bulletFormat.fontColor;

          // CoreLog.d("color ${color}");
          // var superFansInfo = messageNotice.badgeInfo.tSuperFansInfo;
          var badgeName = messageNotice.badgeInfo.sBadgeName;
          var badgeLevel = messageNotice.badgeInfo.iBadgeLevel.toString();
          onMessage?.call(
            LiveMessage(
              type: LiveMessageType.chat,
              color: color <= 0 || color == 0xFF ? Colors.white : ColorUtil.numberToColor(color),
              message: content,
              userName: uname,
              // userLevel: nobleLevel,
              fansName: badgeName,
              fansLevel: badgeLevel,
            ),
          );
        } else if (wSPushMessage.uri == 8006) {
          int online = 0;
          var s = TarsInputStream(Uint8List.fromList(wSPushMessage.msg));
          online = s.read(online, 0, false);
          onMessage?.call(
            LiveMessage(
              type: LiveMessageType.online,
              data: online,
              color: Colors.white,
              message: "",
              userName: "",
            ),
          );
        }
      }
    } catch (e) {
      CoreLog.error(e);
    }
  }
}

class HYPushMessage extends TarsStructBase {
  int pushType = 0;
  int uri = 0;
  List<int> msg = <int>[];
  int protocolType = 0;

  @override
  void readFrom(TarsInputStream _is) {
    pushType = _is.read(pushType, 0, false);
    uri = _is.read(uri, 1, false);
    msg = _is.readBytes(2, false);
    protocolType = _is.read(protocolType, 3, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {}
}

class HYSender extends TarsStructBase {
  int uid = 0;
  int lMid = 0;
  String nickName = "";
  int gender = 0;
  String sAvatarUrl = "";
  int iNobleLevel = 0;
  NobleLevelInfo tNobleLevelInfo = NobleLevelInfo();
  String sGuid = "";
  String sHuYaUA = "";

  @override
  void readFrom(TarsInputStream _is) {
    uid = _is.read(uid, 0, false);
    lMid = _is.read(lMid, 1, false);
    nickName = _is.read(nickName, 2, false);
    gender = _is.read(gender, 3, false);
    sAvatarUrl = _is.read(sAvatarUrl, 4, false);
    iNobleLevel = _is.read(iNobleLevel, 5, false);
    tNobleLevelInfo = _is.readTarsStruct(tNobleLevelInfo, 6, false) as NobleLevelInfo;
    sGuid = _is.read(sGuid, 7, false);
    sHuYaUA = _is.read(sHuYaUA, 8, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {}
}

class NobleLevelInfo extends TarsStructBase {
  int iNobleLevel = 0;
  int iAttrType = 0;

  @override
  void readFrom(TarsInputStream _is) {
    iNobleLevel = _is.read(iNobleLevel, 0, false);
    iAttrType = _is.read(iAttrType, 1, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(iNobleLevel, 0);
    _os.write(iAttrType, 1);
  }
}

class HYMessage extends TarsStructBase {
  HYSender userInfo = HYSender();
  int lTid = 0;
  int lSid = 0;
  String content = "";
  int iShowMode = 0;
  ContentFormat tFormat = ContentFormat();
  HYBulletFormat bulletFormat = HYBulletFormat();
  int iTermType = 0;
  List<DecorationInfo> vDecorationPrefix = [DecorationInfo()];
  List<DecorationInfo> vDecorationSuffix = [DecorationInfo()];
  List<UidNickName> vAtSomeone = [UidNickName()];
  int lPid = 0;
  List<DecorationInfo> vBulletPrefix = [DecorationInfo()];
  String sIconUrl = "";
  int iType = 0;
  List<DecorationInfo> vBulletSuffix = [DecorationInfo()];
  List<MessageTagInfo> vTagInfo = [MessageTagInfo()];
  SendMessageFormat tSenceFormat = SendMessageFormat();
  MessageContentExpand tContentExpand = MessageContentExpand();
  int iMessageMode = 0;

  // region 额外属性
  BadgeInfo badgeInfo = BadgeInfo();

  // endregion

  @override
  void readFrom(TarsInputStream _is) {
    // userInfo = _is.readTarsStruct(userInfo, 0, false) as HYSender;
    // content = _is.read(content, 3, false);
    // bulletFormat = _is.readTarsStruct(bulletFormat, 6, false) as HYBulletFormat;

    userInfo = _is.readTarsStruct(userInfo, 0, false) as HYSender;
    lTid = _is.read(lTid, 1, false);
    lSid = _is.read(lSid, 2, false);
    content = _is.readString(3, false);
    iShowMode = _is.read(iShowMode, 4, false);
    tFormat = _is.readTarsStruct(tFormat, 5, false) as ContentFormat;
    bulletFormat = _is.readTarsStruct(bulletFormat, 6, false) as HYBulletFormat;
    iTermType = _is.read(iTermType, 7, false);
    vDecorationPrefix = _is.readList<DecorationInfo>(vDecorationPrefix, 8, false);
    vDecorationSuffix = _is.readList<DecorationInfo>(vDecorationSuffix, 9, false);
    vAtSomeone = _is.readList<UidNickName>(vAtSomeone, 10, false);
    lPid = _is.read(lPid, 11, false);
    vBulletPrefix = _is.readList<DecorationInfo>(vBulletPrefix, 12, false);
    sIconUrl = _is.read(sIconUrl, 13, false);
    iType = _is.read(iType, 14, false);
    vBulletSuffix = _is.readList<DecorationInfo>(vBulletSuffix, 15, false);
    vTagInfo = _is.readList<MessageTagInfo>(vTagInfo, 16, false);
    tSenceFormat = _is.readTarsStruct(tSenceFormat, 17, false) as SendMessageFormat;
    tContentExpand = _is.readTarsStruct(tContentExpand, 18, false) as MessageContentExpand;
    iMessageMode = _is.read(iMessageMode, 19, false);

    // 解析额外属性
    for (DecorationInfo decorationPrefix in vDecorationPrefix) {
      if (decorationPrefix.vData.isEmpty) {
        continue;
      }
      try {
        badgeInfo.readFrom(TarsInputStream(Uint8List.fromList(decorationPrefix.vData)));
        // CoreLog.d("badgeInfo ok");
        break;
      } catch (e) {
        CoreLog.w(e.toString());
      }
    }
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(userInfo, 0);
    _os.write(lTid, 1);
    _os.write(lSid, 2);
    _os.write(content, 3);
    _os.write(iShowMode, 4);
    _os.write(tFormat, 5);
    _os.write(bulletFormat, 6);
    _os.write(iTermType, 7);
    _os.write(vDecorationPrefix, 8);
    _os.write(vDecorationSuffix, 9);
    _os.write(vAtSomeone, 10);
    _os.write(lPid, 11);
    _os.write(vBulletPrefix, 12);
    _os.write(sIconUrl, 13);
    _os.write(iType, 14);
    _os.write(vBulletSuffix, 15);
    _os.write(vTagInfo, 16);
    _os.write(tSenceFormat, 17);
    _os.write(tContentExpand, 18);
    _os.write(iMessageMode, 19);
  }
}

class HYBulletFormat extends TarsStructBase {
  int fontColor = 0;
  int fontSize = 4;
  int textSpeed = 0;
  int transitionType = 1;
  int iPopupStyle = 0;
  BulletBorderGroundFormat tBorderGroundFormat = BulletBorderGroundFormat();
  List<int> vGraduatedColor = [];
  int iAvatarFlag = 0;
  int iAvatarTerminalFlag = -1;

  @override
  void readFrom(TarsInputStream _is) {
    fontColor = _is.read(fontColor, 0, false);
    fontSize = _is.read(fontSize, 1, false);
    textSpeed = _is.read(textSpeed, 2, false);
    transitionType = _is.read(transitionType, 3, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {}
}

class ContentFormat extends TarsStructBase {
  int iFontColor = -1;
  int iFontSize = 4;
  int iPopupStyle = 0;
  int iNickNameFontColor = -1;
  int iDarkFontColor = -1;
  int iDarkNickNameFontColor = -1;

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(iFontColor, 0);
    _os.write(iFontSize, 1);
    _os.write(iPopupStyle, 2);
    _os.write(iNickNameFontColor, 3);
    _os.write(iDarkFontColor, 4);
    _os.write(iDarkNickNameFontColor, 5);
  }

  @override
  void readFrom(TarsInputStream _is) {
    iFontColor = _is.read(iFontColor, 0, false);
    iFontSize = _is.read(iFontSize, 1, false);
    iPopupStyle = _is.read(iPopupStyle, 2, false);
    iNickNameFontColor = _is.read(iNickNameFontColor, 3, false);
    iDarkFontColor = _is.read(iDarkFontColor, 4, false);
    iDarkNickNameFontColor = _is.read(iDarkNickNameFontColor, 5, false);
  }
}

class BulletBorderGroundFormat extends TarsStructBase {
  int iEnableUse = 0;
  int iBorderThickness = 0;
  int iBorderColour = -1;
  int iBorderDiaphaneity = 100;
  int iGroundColour = -1;
  int iGroundColourDiaphaneity = 100;
  String sAvatarDecorationUrl = "";
  int iFontColor = -1;
  int iTerminalFlag = -1;

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(iEnableUse, 0);
    _os.write(iBorderThickness, 1);
    _os.write(iBorderColour, 2);
    _os.write(iBorderDiaphaneity, 3);
    _os.write(iGroundColour, 4);
    _os.write(iGroundColourDiaphaneity, 5);
    _os.write(sAvatarDecorationUrl, 6);
    _os.write(iFontColor, 7);
    _os.write(iTerminalFlag, 8);
  }

  @override
  void readFrom(TarsInputStream _is) {
    iEnableUse = _is.read(iEnableUse, 0, false);
    iBorderThickness = _is.read(iBorderThickness, 1, false);
    iBorderColour = _is.read(iBorderColour, 2, false);
    iBorderDiaphaneity = _is.read(iBorderDiaphaneity, 3, false);
    iGroundColour = _is.read(iGroundColour, 4, false);
    iGroundColourDiaphaneity = _is.read(iGroundColourDiaphaneity, 5, false);
    sAvatarDecorationUrl = _is.read(sAvatarDecorationUrl, 6, false);
    iFontColor = _is.read(iFontColor, 7, false);
    iTerminalFlag = _is.read(iTerminalFlag, 8, false);
  }
}

class DecorationInfo extends TarsStructBase {
  int iAppId = 0;
  int iViewType = 0;
  List<int> vData = [];
  int lSourceId = -1;
  int iType = -1;

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(iAppId, 0);
    _os.write(iViewType, 1);
    _os.write(vData, 2);
    _os.write(lSourceId, 3);
    _os.write(iType, 4);
  }

  @override
  void readFrom(TarsInputStream _is) {
    iAppId = _is.read(iAppId, 0, false);
    iViewType = _is.read(iViewType, 1, false);
    vData = _is.readBytes(2, false);
    lSourceId = _is.read(lSourceId, 3, false);
    iType = _is.read(iType, 4, false);
  }
}

class UidNickName extends TarsStructBase {
  int lUid = 0;
  String sNickName = "";

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(lUid, 0);
    _os.write(sNickName, 1);
  }

  @override
  void readFrom(TarsInputStream _is) {
    lUid = _is.read(lUid, 0, false);
    sNickName = _is.read(sNickName, 1, false);
  }
}

class MessageTagInfo extends TarsStructBase {
  int iAppId = 0;
  String sTag = "";

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(iAppId, 0);
    _os.write(sTag, 1);
  }

  @override
  void readFrom(TarsInputStream _is) {
    iAppId = _is.read(iAppId, 0, false);
    sTag = _is.read(sTag, 1, false);
  }
}

class SendMessageFormat extends TarsStructBase {
  int iSenceType = 0;
  int lFormatId = -1;
  int lSizeTemplateId = -1;

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(iSenceType, 0);
    _os.write(lFormatId, 1);
    _os.write(lSizeTemplateId, 2);
  }

  @override
  void readFrom(TarsInputStream _is) {
    iSenceType = _is.read(iSenceType, 0, false);
    lFormatId = _is.read(lFormatId, 1, false);
    lSizeTemplateId = _is.read(lSizeTemplateId, 2, false);
  }
}

class MessageContentExpand extends TarsStructBase {
  int iAppId = 0;
  String sToast = "";
  List<int> vData = [];

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(iAppId, 0);
    _os.write(sToast, 1);
    _os.write(vData, 2);
  }

  @override
  void readFrom(TarsInputStream _is) {
    iAppId = _is.read(iAppId, 0, false);
    sToast = _is.read(sToast, 1, false);
    vData = _is.readBytes(2, false);
  }
}

class BadgeInfo extends TarsStructBase {
  int lUid = 0;
  int lBadgeId = 0;
  String sPresenterNickName = "";
  String sBadgeName = "";
  int iBadgeLevel = 0;
  int iRank = 0;
  int iScore = 0;
  int iNextScore = 0;
  int iQuotaUsed = 0;
  int iQuota = 0;
  int lQuotaTS = 0;
  int lOpenTS = 0;
  int iVFlag = 0;
  String sVLogo = "";
  PresenterChannelInfo tChannelInfo = PresenterChannelInfo();
  String sPresenterLogo = "";
  int lVExpiredTS = 0;
  int iBadgeType = 0;
  FaithInfo tFaithInfo = FaithInfo();
  SuperFansInfo tSuperFansInfo = SuperFansInfo();
  int iBaseQuota = 0;
  int lVConsumRank = 0;
  int iCustomBadgeFlag = 0;
  int iAgingDays = 0;
  int iDayScore = 0;
  CustomBadgeDynamicExternal tExternal = CustomBadgeDynamicExternal();
  int iExtinguished = 0;
  int iExtinguishDays = 0;
  int iBadgeCate = 0;
  int iLiveFlag = 0;
  int iAutoDeductUpgrade = 0;

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(lUid, 0);
    _os.write(lBadgeId, 1);
    _os.write(sPresenterNickName, 2);
    _os.write(sBadgeName, 3);
    _os.write(iBadgeLevel, 4);
    _os.write(iRank, 5);
    _os.write(iScore, 6);
    _os.write(iNextScore, 7);
    _os.write(iQuotaUsed, 8);
    _os.write(iQuota, 9);
    _os.write(lQuotaTS, 10);
    _os.write(lOpenTS, 11);
    _os.write(iVFlag, 12);
    _os.write(sVLogo, 13);
    _os.write(tChannelInfo, 14);
    _os.write(sPresenterLogo, 15);
    _os.write(lVExpiredTS, 16);
    _os.write(iBadgeType, 17);
    _os.write(tFaithInfo, 18);
    _os.write(tSuperFansInfo, 19);
    _os.write(iBaseQuota, 20);
    _os.write(lVConsumRank, 21);
    _os.write(iCustomBadgeFlag, 22);
    _os.write(iAgingDays, 23);
    _os.write(iDayScore, 24);
    _os.write(tExternal, 25);
    _os.write(iExtinguished, 26);
    _os.write(iExtinguishDays, 27);
    _os.write(iBadgeCate, 28);
    _os.write(iLiveFlag, 29);
    _os.write(iAutoDeductUpgrade, 30);
  }

  @override
  void readFrom(TarsInputStream _is) {
    lUid = _is.read(lUid, 0, false);
    lBadgeId = _is.read(lBadgeId, 1, false);
    sPresenterNickName = _is.read(sPresenterNickName, 2, false);
    sBadgeName = _is.read(sBadgeName, 3, false);
    iBadgeLevel = _is.read(iBadgeLevel, 4, false);
    iRank = _is.read(iRank, 5, false);
    iScore = _is.read(iScore, 6, false);
    iNextScore = _is.read(iNextScore, 7, false);
    iQuotaUsed = _is.read(iQuotaUsed, 8, false);
    iQuota = _is.read(iQuota, 9, false);
    lQuotaTS = _is.read(lQuotaTS, 10, false);
    lOpenTS = _is.read(lOpenTS, 11, false);
    iVFlag = _is.read(iVFlag, 12, false);
    sVLogo = _is.read(sVLogo, 13, false);
    tChannelInfo = _is.readTarsStruct(tChannelInfo, 14, false) as PresenterChannelInfo;
    sPresenterLogo = _is.read(sPresenterLogo, 15, false);
    lVExpiredTS = _is.read(lVExpiredTS, 16, false);
    iBadgeType = _is.read(iBadgeType, 17, false);
    tFaithInfo = _is.readTarsStruct(tFaithInfo, 18, false) as FaithInfo;
    tSuperFansInfo = _is.readTarsStruct(tSuperFansInfo, 19, false) as SuperFansInfo;
    iBaseQuota = _is.read(iBaseQuota, 20, false);
    lVConsumRank = _is.read(lVConsumRank, 21, false);
    iCustomBadgeFlag = _is.read(iCustomBadgeFlag, 22, false);
    iAgingDays = _is.read(iAgingDays, 23, false);
    iDayScore = _is.read(iDayScore, 24, false);
    tExternal = _is.readTarsStruct(tExternal, 25, false) as CustomBadgeDynamicExternal;
    iExtinguished = _is.read(iExtinguished, 26, false);
    iExtinguishDays = _is.read(iExtinguishDays, 27, false);
    iBadgeCate = _is.read(iBadgeCate, 28, false);
    iLiveFlag = _is.read(iLiveFlag, 29, false);
    iLiveFlag = _is.read(iAutoDeductUpgrade, 30, false);
  }
}

class PresenterChannelInfo extends TarsStructBase {
  int lYYId = 0;
  int lTid = 0;
  int lSid = 0;
  int iSourceType = 0;
  int iScreenType = 0;
  int lUid = 0;
  int iGameId = 0;
  int iRoomId = 0;

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(lYYId, 0);
    _os.write(lTid, 1);
    _os.write(lSid, 3);
    _os.write(iSourceType, 4);
    _os.write(iScreenType, 5);
    _os.write(lUid, 6);
    _os.write(iGameId, 7);
    _os.write(iRoomId, 8);
  }

  @override
  void readFrom(TarsInputStream _is) {
    lYYId = _is.read(lYYId, 0, false);
    lTid = _is.read(lTid, 1, false);
    lSid = _is.read(lSid, 3, false);
    iSourceType = _is.read(iSourceType, 4, false);
    iScreenType = _is.read(iScreenType, 5, false);
    lUid = _is.read(lUid, 6, false);
    iGameId = _is.read(iGameId, 7, false);
    iRoomId = _is.read(iRoomId, 8, false);
  }
}

class FaithInfo extends TarsStructBase {
  String sFaithName = "";
  List<FaithPresenter> vPresenter = [FaithPresenter()];

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(sFaithName, 0);
    _os.write(vPresenter, 1);
  }

  @override
  void readFrom(TarsInputStream _is) {
    sFaithName = _is.read(sFaithName, 0, false);
    vPresenter = _is.readList<FaithPresenter>(vPresenter, 1, false);
  }
}

class SuperFansInfo extends TarsStructBase {
  int lSFExpiredTS = 0;
  int iSFFlag = 0;
  int lSFAnnualTS = 0;
  int iSFVariety = 0;
  int lOpenTS = 0;
  int lMemoryDay = 0;

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(lSFExpiredTS, 0);
    _os.write(iSFFlag, 1);
    _os.write(lSFAnnualTS, 2);
    _os.write(iSFVariety, 3);
    _os.write(lOpenTS, 4);
    _os.write(lMemoryDay, 5);
  }

  @override
  void readFrom(TarsInputStream _is) {
    lSFExpiredTS = _is.read(lSFExpiredTS, 0, false);
    iSFFlag = _is.read(iSFFlag, 1, false);
    lSFAnnualTS = _is.read(lSFAnnualTS, 2, false);
    iSFVariety = _is.read(iSFVariety, 3, false);
    lOpenTS = _is.read(lOpenTS, 4, false);
    lMemoryDay = _is.read(lMemoryDay, 5, false);
  }
}

class CustomBadgeDynamicExternal extends TarsStructBase {
  String sFloorExter = "";
  int iFansIdentity = 0;
  int iBadgeSize = 0;

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(sFloorExter, 0);
    _os.write(iFansIdentity, 1);
    _os.write(iFansIdentity, 2);
  }

  @override
  void readFrom(TarsInputStream _is) {
    sFloorExter = _is.read(sFloorExter, 0, false);
    iFansIdentity = _is.read(iFansIdentity, 1, false);
    iBadgeSize = _is.read(iBadgeSize, 2, false);
  }
}

class FaithPresenter extends TarsStructBase {
  int lPid = 0;
  String sLogo = "";

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(lPid, 0);
    _os.write(sLogo, 1);
  }

  @override
  void readFrom(TarsInputStream _is) {
    lPid = _is.read(lPid, 0, false);
    sLogo = _is.read(sLogo, 1, false);
  }
}

abstract class TarsStructBase extends TarsStruct {
  void display(StringBuffer sb, int level) {
    return displayAsString(sb, level);
  }

  @override
  void displayAsString(StringBuffer sb, int level) {}

  @override
  Object deepCopy() {
    // TODO
    return this;
  }
}
