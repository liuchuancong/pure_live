import 'dart:typed_data';

import 'package:pure_live/core/tars/types.dart';
import 'package:pure_live/pkg/tars/codec/tars_struct.dart';
import 'package:pure_live/pkg/tars/codec/tars_displayer.dart';
import 'package:pure_live/pkg/tars/codec/tars_input_stream.dart';
import 'package:pure_live/pkg/tars/codec/tars_output_stream.dart';

// ignore_for_file: no_leading_underscores_for_local_identifiers

class HYPushMessage extends TarsStruct {
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

  @override
  Object deepCopy() {
    return HYPushMessage()
      ..pushType = pushType
      ..uri = uri
      ..msg = List<int>.from(msg)
      ..protocolType = protocolType;
  }

  @override
  void displayAsString(StringBuffer sb, int level) {}
}

// senderInfo type == 7 -> uri 1400
class HYSender extends TarsStruct {
  int lUid = 0; //tag 0
  int lImid = 0; //tag 1
  String sNickName = ''; //tag 2
  int iGender = 0; //tag 3
  String sAvatarUrl = ''; //tag 4
  int iNobleLevel = 0; //tag 5
  String sGuid = ''; //tag  7
  String sHuyaUa = ''; //tag 8
  int iUserType = 0; //tag 9

  @override
  void readFrom(TarsInputStream _is) {
    lUid = _is.read(lUid, 0, false);
    lImid = _is.read(lImid, 1, false);
    sNickName = _is.read(sNickName, 2, false);
    iGender = _is.read(iGender, 3, false);
    sAvatarUrl = _is.read(sAvatarUrl, 4, false);
    iNobleLevel = _is.read(iNobleLevel, 5, false);
    sGuid = _is.read(sGuid, 7, false);
    sHuyaUa = _is.read(sHuyaUa, 8, false);
    iUserType = _is.read(iUserType, 9, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(lUid, 0);
    _os.write(lImid, 1);
    _os.write(sNickName, 2);
    _os.write(iGender, 3);
    _os.write(sAvatarUrl, 4);
    _os.write(iNobleLevel, 5);
    _os.write(sGuid, 7);
    _os.write(sHuyaUa, 8);
    _os.write(iUserType, 9);
  }

  @override
  TarsStruct deepCopy() {
    return HYSender()
      ..lUid = lUid
      ..lImid = lImid
      ..sNickName = sNickName
      ..iGender = iGender
      ..sAvatarUrl = sAvatarUrl
      ..iNobleLevel = iNobleLevel
      ..sGuid = sGuid
      ..sHuyaUa = sHuyaUa
      ..iUserType = iUserType;
  }

  @override
  void displayAsString(StringBuffer sb, int level) {
    TarsDisplayer _ds = TarsDisplayer(sb, level: level);
    _ds.DisplayInt(lUid, 'lUid');
    _ds.DisplayInt(lImid, 'lImid');
    _ds.DisplayString(sNickName, 'sNickName');
    _ds.DisplayInt(iGender, 'iGender');
    _ds.DisplayString(sAvatarUrl, 'sAvatarUrl');
    _ds.DisplayInt(iNobleLevel, 'iNobleLevel');
    _ds.DisplayString(sGuid, 'sGuid');
    _ds.DisplayString(sHuyaUa, 'sHuyaUa');
    _ds.DisplayInt(iUserType, 'iUserType');
  }
}

class HYMessage extends TarsStruct {
  HYSender userInfo = HYSender();
  String content = '';
  HYBulletFormat bulletFormat = HYBulletFormat();

  @override
  void readFrom(TarsInputStream _is) {
    userInfo = _is.readTarsStruct(userInfo, 0, false) as HYSender;
    content = _is.read(content, 3, false);
    bulletFormat = _is.readTarsStruct(bulletFormat, 6, false) as HYBulletFormat;
  }

  @override
  void writeTo(TarsOutputStream _os) {}

  @override
  Object deepCopy() {
    return HYMessage()
      ..userInfo = userInfo.deepCopy() as HYSender
      ..content = content
      ..bulletFormat = bulletFormat.deepCopy() as HYBulletFormat;
  }

  @override
  void displayAsString(StringBuffer sb, int level) {}
}

class HYBulletFormat extends TarsStruct {
  int fontColor = 0;
  int fontSize = 4;
  int textSpeed = 0;
  int transitionType = 1;

  @override
  void readFrom(TarsInputStream _is) {
    fontColor = _is.read(fontColor, 0, false);
    fontSize = _is.read(fontSize, 1, false);
    textSpeed = _is.read(textSpeed, 2, false);
    transitionType = _is.read(transitionType, 3, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {}

  @override
  Object deepCopy() {
    return HYBulletFormat()
      ..fontColor = fontColor
      ..fontSize = fontSize
      ..textSpeed = textSpeed
      ..transitionType = transitionType;
  }

  @override
  void displayAsString(StringBuffer sb, int level) {}
}

// x.WSPushMessage_V2
class WSPushMessageV2 extends TarsStruct {
  String sGroupId = ''; //tag 0
  List<WSMsgItem> vMsgItem = <WSMsgItem>[]; //tag 1

  @override
  void readFrom(TarsInputStream _is) {
    sGroupId = _is.read(sGroupId, 0, false);
    vMsgItem = _is.readList<WSMsgItem>(<WSMsgItem>[WSMsgItem()], 1, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(sGroupId, 0);
    _os.write(vMsgItem, 1);
  }

  @override
  TarsStruct deepCopy() {
    return WSPushMessageV2()
      ..sGroupId = sGroupId
      ..vMsgItem = vMsgItem;
  }

  @override
  void displayAsString(StringBuffer sb, int level) {
    TarsDisplayer _ds = TarsDisplayer(sb, level: level);
    _ds.DisplayString(sGroupId, 'sGroupId');
    _ds.DisplayList(vMsgItem, 'vMsgItem');
  }
}

// x.WSMsgItem
class WSMsgItem extends TarsStruct {
  int iUri = 0;
  List<int> sMsg = <int>[];
  int lMsgId = 0;

  @override
  void readFrom(TarsInputStream inputStream) {
    iUri = inputStream.read(iUri, 0, false);
    sMsg = inputStream.readBytes(1, false);
    lMsgId = inputStream.read(lMsgId, 2, false);
  }

  @override
  void writeTo(TarsOutputStream outputStream) {
    outputStream.write(iUri, 0);
    outputStream.write(Uint8List.fromList(sMsg), 1);
    outputStream.write(lMsgId, 2);
  }

  @override
  Object deepCopy() => WSMsgItem()
    ..iUri = iUri
    ..sMsg = List<int>.from(sMsg)
    ..lMsgId = lMsgId;

  @override
  void displayAsString(StringBuffer sb, int level) {}
}

class WebSocketCommand extends TarsStruct {
  int cmdType = 0; //tag 0
  List<int> data = []; //tag 1
  int requestId = 0; //tag 2
  String traceId = ''; //tag 3
  int encryptType = 0; //tag 4
  int time = 0; //tag 5
  String md5 = ''; //tag 6
  @override
  void readFrom(TarsInputStream _is) {
    cmdType = _is.read(cmdType, 0, false);
    data = _is.readList<int>(data, 1, false);
    requestId = _is.read(requestId, 2, false);
    traceId = _is.read(traceId, 3, false);
    encryptType = _is.read(encryptType, 4, false);
    time = _is.read(time, 5, false);
    md5 = _is.read(md5, 6, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(cmdType, 0);
    _os.write(data, 1);
    _os.write(requestId, 2);
    _os.write(traceId, 3);
    _os.write(encryptType, 4);
    _os.write(time, 5);
    _os.write(md5, 6);
  }

  @override
  TarsStruct deepCopy() {
    return WebSocketCommand()
      ..cmdType = cmdType
      ..data = data
      ..requestId = requestId
      ..traceId = traceId
      ..encryptType = encryptType
      ..time = time
      ..md5 = md5;
  }

  @override
  void displayAsString(StringBuffer sb, int level) {}
}

class WsRegisterGroupReq extends TarsStruct {
  List<String> groupId = []; //tag 0
  String token = ''; //tag 1
  @override
  void readFrom(TarsInputStream _is) {
    groupId = _is.readList<String>(groupId, 0, false);
    token = _is.read(token, 1, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(groupId, 0);
    _os.write(token, 1);
  }

  @override
  TarsStruct deepCopy() {
    return WsRegisterGroupReq()
      ..groupId = groupId
      ..token = token;
  }

  @override
  void displayAsString(StringBuffer sb, int level) {}
}

class LiveAppUAEx extends TarsStruct {
  String sImei = ''; //tag 1
  String sApn = ''; //tag 2
  String sNetType = ''; //tag 3
  String sDeviceId = ''; //tag 4
  String sMid = ''; //tag 5
  @override
  void readFrom(TarsInputStream _is) {
    sImei = _is.read(sImei, 1, false);
    sApn = _is.read(sApn, 2, false);
    sNetType = _is.read(sNetType, 3, false);
    sDeviceId = _is.read(sDeviceId, 4, false);
    sMid = _is.read(sMid, 5, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(sImei, 1);
    _os.write(sApn, 2);
    _os.write(sNetType, 3);
    _os.write(sDeviceId, 4);
    _os.write(sMid, 5);
  }

  @override
  TarsStruct deepCopy() {
    return LiveAppUAEx()
      ..sImei = sImei
      ..sApn = sApn
      ..sNetType = sNetType
      ..sDeviceId = sDeviceId
      ..sMid = sMid;
  }

  @override
  void displayAsString(StringBuffer sb, int level) {
    TarsDisplayer _ds = TarsDisplayer(sb, level: level);
    _ds.DisplayString(sImei, 'sImei');
    _ds.DisplayString(sApn, 'sApn');
    _ds.DisplayString(sNetType, 'sNetType');
    _ds.DisplayString(sDeviceId, 'sDeviceId');
    _ds.DisplayString(sMid, 'sMid');
  }
}

class LiveUserBase extends TarsStruct {
  int eSource = 0; //tag 0
  int eType = 0; //tag 1
  LiveAppUAEx uaEx = LiveAppUAEx(); //tag 2

  @override
  void readFrom(TarsInputStream _is) {
    eSource = _is.read(eSource, 0, false);
    eType = _is.read(eType, 1, false);
    uaEx = _is.read(uaEx, 2, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(eSource, 0);
    _os.write(eType, 1);
    _os.write(uaEx, 2);
  }

  @override
  TarsStruct deepCopy() {
    return LiveUserBase()
      ..eSource = eSource
      ..eType = eType
      ..uaEx = uaEx;
  }

  @override
  void displayAsString(StringBuffer sb, int level) {
    TarsDisplayer _ds = TarsDisplayer(sb, level: level);
    _ds.DisplayInt(eSource, 'eSource');
    _ds.DisplayInt(eType, 'eType');
    _ds.DisplayTarsStruct(uaEx, 'uaEx');
  }
}

class LiveLaunchReq extends TarsStruct {
  HuyaUserId id = HuyaUserId(); //tag 0
  LiveUserBase liveUb = LiveUserBase(); //tag 1
  bool supportDomain = false; //tag 2
  @override
  void readFrom(TarsInputStream _is) {
    id = _is.read(id, 0, false);
    liveUb = _is.read(liveUb, 1, false);
    supportDomain = _is.read(supportDomain, 2, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(id, 0);
    _os.write(liveUb, 1);
    _os.write(supportDomain, 2);
  }

  @override
  TarsStruct deepCopy() {
    return LiveLaunchReq()
      ..id = id
      ..liveUb = liveUb
      ..supportDomain = supportDomain;
  }

  @override
  void displayAsString(StringBuffer sb, int level) {
    TarsDisplayer _ds = TarsDisplayer(sb, level: level);
    _ds.DisplayTarsStruct(id, 'id');
    _ds.DisplayTarsStruct(liveUb, 'liveUb');
    _ds.DisplayBool(supportDomain, 'supportDomain');
  }
}
