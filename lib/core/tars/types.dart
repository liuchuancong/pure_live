import 'package:pure_live/pkg/tars/codec/tars_struct.dart';
import 'package:pure_live/pkg/tars/codec/tars_displayer.dart';
import 'package:pure_live/pkg/tars/codec/tars_input_stream.dart';
import 'package:pure_live/pkg/tars/codec/tars_output_stream.dart';

class HuyaUserId extends TarsStruct {
  int lUid = 0;
  String sGuid = '';
  String sToken = '';
  String sHuYaUA = '';
  String sCookie = '';
  int iTokenType = 0;
  String sDeviceInfo = '';
  String sQIMEI = '';

  @override
  void readFrom(TarsInputStream tarsInputStream) {
    lUid = tarsInputStream.read(lUid, 0, false);
    sGuid = tarsInputStream.read(sGuid, 1, false);
    sToken = tarsInputStream.read(sToken, 2, false);
    sHuYaUA = tarsInputStream.read(sHuYaUA, 3, false);
    sCookie = tarsInputStream.read(sCookie, 4, false);
    iTokenType = tarsInputStream.read(iTokenType, 5, false);
    sDeviceInfo = tarsInputStream.read(sDeviceInfo, 6, false);
    sQIMEI = tarsInputStream.read(sQIMEI, 7, false);
  }

  @override
  void writeTo(TarsOutputStream tarsOutputStream) {
    tarsOutputStream.write(lUid, 0);
    tarsOutputStream.write(sGuid, 1);
    tarsOutputStream.write(sToken, 2);
    tarsOutputStream.write(sHuYaUA, 3);
    tarsOutputStream.write(sCookie, 4);
    tarsOutputStream.write(iTokenType, 5);
    tarsOutputStream.write(sDeviceInfo, 6);
    tarsOutputStream.write(sQIMEI, 7);
  }

  @override
  Object deepCopy() {
    return HuyaUserId()
      ..lUid = lUid
      ..sGuid = sGuid
      ..sToken = sToken
      ..sHuYaUA = sHuYaUA
      ..sCookie = sCookie
      ..iTokenType = iTokenType
      ..sDeviceInfo = sDeviceInfo
      ..sQIMEI = sQIMEI;
  }

  @override
  void displayAsString(StringBuffer sb, int level) {
    TarsDisplayer tarsDisplayer = TarsDisplayer(sb, level: level);
    tarsDisplayer.DisplayInt(lUid, 'lUid');
    tarsDisplayer.DisplayString(sGuid, 'sGuid');
    tarsDisplayer.DisplayString(sToken, 'sToken');
    tarsDisplayer.DisplayString(sHuYaUA, 'sHuYaUA');
    tarsDisplayer.DisplayString(sCookie, 'sCookie');
    tarsDisplayer.DisplayInt(iTokenType, 'iTokenType');
    tarsDisplayer.DisplayString(sDeviceInfo, 'sDeviceInfo');
    tarsDisplayer.DisplayString(sQIMEI, 'sQIMEI');
  }
}

class GetLivingInfoReq extends TarsStruct {
  HuyaUserId tId = HuyaUserId();
  int lTopSid = 0;
  int lSubSid = 0;
  int lPresenterUid = 0;
  int lRoomId = 0;
  String sTraceSource = '';
  String sPassword = '';
  int iRoomId = 0;
  int iFreeFlowFlag = 0;
  int iIpStack = 0;

  @override
  void readFrom(TarsInputStream tarsInputStream) {
    tId = tarsInputStream.read(tId, 0, false);
    lTopSid = tarsInputStream.read(lTopSid, 1, false);
    lSubSid = tarsInputStream.read(lSubSid, 2, false);
    lPresenterUid = tarsInputStream.read(lPresenterUid, 3, false);
    lRoomId = tarsInputStream.read(lRoomId, 4, false);
    sTraceSource = tarsInputStream.read(sTraceSource, 5, false);
    sPassword = tarsInputStream.read(sPassword, 6, false);
    iRoomId = tarsInputStream.read(iRoomId, 7, false);
    iFreeFlowFlag = tarsInputStream.read(iFreeFlowFlag, 8, false);
    iIpStack = tarsInputStream.read(iIpStack, 9, false);
  }

  @override
  void writeTo(TarsOutputStream tarsOutputStream) {
    tarsOutputStream.write(tId, 0);
    tarsOutputStream.write(lTopSid, 1);
    tarsOutputStream.write(lSubSid, 2);
    tarsOutputStream.write(lPresenterUid, 3);
    tarsOutputStream.write(lRoomId, 4);
    tarsOutputStream.write(sTraceSource, 5);
    tarsOutputStream.write(sPassword, 6);
    tarsOutputStream.write(iRoomId, 7);
    tarsOutputStream.write(iFreeFlowFlag, 8);
    tarsOutputStream.write(iIpStack, 9);
  }

  @override
  Object deepCopy() {
    return GetLivingInfoReq()
      ..tId = tId.deepCopy() as HuyaUserId
      ..lTopSid = lTopSid
      ..lSubSid = lSubSid
      ..lPresenterUid = lPresenterUid
      ..lRoomId = lRoomId
      ..sTraceSource = sTraceSource
      ..sPassword = sPassword
      ..iRoomId = iRoomId
      ..iFreeFlowFlag = iFreeFlowFlag
      ..iIpStack = iIpStack;
  }

  @override
  void displayAsString(StringBuffer sb, int level) {
    TarsDisplayer tarsDisplayer = TarsDisplayer(sb, level: level);
    tarsDisplayer.DisplayTarsStruct(tId, 'tId');
    tarsDisplayer.DisplayInt(lTopSid, 'lTopSid');
    tarsDisplayer.DisplayInt(lSubSid, 'lSubSid');
    tarsDisplayer.DisplayInt(lPresenterUid, 'lPresenterUid');
    tarsDisplayer.DisplayInt(lRoomId, 'lRoomId');
    tarsDisplayer.DisplayString(sTraceSource, 'sTraceSource');
    tarsDisplayer.DisplayString(sPassword, 'sPassword');
    tarsDisplayer.DisplayInt(iRoomId, 'iRoomId');
    tarsDisplayer.DisplayInt(iFreeFlowFlag, 'iFreeFlowFlag');
    tarsDisplayer.DisplayInt(iIpStack, 'iIpStack');
  }
}

class MessageUser extends TarsStruct {
  String sNick = '';
  String sAvatar = '';

  @override
  void readFrom(TarsInputStream tarsInputStream) {
    sNick = tarsInputStream.read(sNick, 1, false);
    sAvatar = tarsInputStream.read(sAvatar, 2, false);
  }

  @override
  void writeTo(TarsOutputStream tarsOutputStream) {
    tarsOutputStream.write(sNick, 1);
    tarsOutputStream.write(sAvatar, 2);
  }

  @override
  Object deepCopy() {
    return MessageUser()
      ..sNick = sNick
      ..sAvatar = sAvatar;
  }

  @override
  void displayAsString(StringBuffer sb, int level) {
    final ds = TarsDisplayer(sb, level: level);
    ds.DisplayString(sNick, 'sNick');
    ds.DisplayString(sAvatar, 'sAvatar');
  }
}
