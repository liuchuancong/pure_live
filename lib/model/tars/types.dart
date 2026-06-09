import 'package:pure_live/pkg/tars/codec/tars_struct.dart';
import 'package:pure_live/pkg/tars/codec/tars_displayer.dart';
import 'package:pure_live/pkg/tars/codec/tars_input_stream.dart';
import 'package:pure_live/pkg/tars/codec/tars_output_stream.dart';

class HuyaUserId extends TarsStruct {
  int lUid = 0;
  String sGuid = "";
  String sToken = "";
  String sHuYaUA = "";
  String sCookie = "";
  int iTokenType = 0;
  String sDeviceInfo = "";
  String sQIMEI = "";

  @override
  void readFrom(TarsInputStream inputStream) {
    lUid = inputStream.read(lUid, 0, false);
    sGuid = inputStream.read(sGuid, 1, false);
    sToken = inputStream.read(sToken, 2, false);
    sHuYaUA = inputStream.read(sHuYaUA, 3, false);
    sCookie = inputStream.read(sCookie, 4, false);
    iTokenType = inputStream.read(iTokenType, 5, false);
    sDeviceInfo = inputStream.read(sDeviceInfo, 6, false);
    sQIMEI = inputStream.read(sQIMEI, 7, false);
  }

  @override
  void writeTo(TarsOutputStream outputStream) {
    outputStream.write(lUid, 0);
    outputStream.write(sGuid, 1);
    outputStream.write(sToken, 2);
    outputStream.write(sHuYaUA, 3);
    outputStream.write(sCookie, 4);
    outputStream.write(iTokenType, 5);
    outputStream.write(sDeviceInfo, 6);
    outputStream.write(sQIMEI, 7);
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
    TarsDisplayer ds = TarsDisplayer(sb, level: level);
    ds.DisplayInt(lUid, "lUid");
    ds.DisplayString(sGuid, "sGuid");
    ds.DisplayString(sToken, "sToken");
    ds.DisplayString(sHuYaUA, "sHuYaUA");
    ds.DisplayString(sCookie, "sCookie");
    ds.DisplayInt(iTokenType, "iTokenType");
    ds.DisplayString(sDeviceInfo, "sDeviceInfo");
    ds.DisplayString(sQIMEI, "sQIMEI");
  }
}

class GetLivingInfoReq extends TarsStruct {
  HuyaUserId tId = HuyaUserId();
  int lTopSid = 0;
  int lSubSid = 0;
  int lPresenterUid = 0;
  int lRoomId = 0;
  String sTraceSource = "";
  String sPassword = "";
  int iRoomId = 0;
  int iFreeFlowFlag = 0;
  int iIpStack = 0;

  @override
  void readFrom(TarsInputStream inputStream) {
    tId = inputStream.read(tId, 0, false);
    lTopSid = inputStream.read(lTopSid, 1, false);
    lSubSid = inputStream.read(lSubSid, 2, false);
    lPresenterUid = inputStream.read(lPresenterUid, 3, false);
    lRoomId = inputStream.read(lRoomId, 4, false);
    sTraceSource = inputStream.read(sTraceSource, 5, false);
    sPassword = inputStream.read(sPassword, 6, false);
    iRoomId = inputStream.read(iRoomId, 7, false);
    iFreeFlowFlag = inputStream.read(iFreeFlowFlag, 8, false);
    iIpStack = inputStream.read(iIpStack, 9, false);
  }

  @override
  void writeTo(TarsOutputStream outputStream) {
    outputStream.write(tId, 0);
    outputStream.write(lTopSid, 1);
    outputStream.write(lSubSid, 2);
    outputStream.write(lPresenterUid, 3);
    outputStream.write(lRoomId, 4);
    outputStream.write(sTraceSource, 5);
    outputStream.write(sPassword, 6);
    outputStream.write(iRoomId, 7);
    outputStream.write(iFreeFlowFlag, 8);
    outputStream.write(iIpStack, 9);
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
    TarsDisplayer ds = TarsDisplayer(sb, level: level);
    ds.DisplayTarsStruct(tId, "tId");
    ds.DisplayInt(lTopSid, "lTopSid");
    ds.DisplayInt(lSubSid, "lSubSid");
    ds.DisplayInt(lPresenterUid, "lPresenterUid");
    ds.DisplayInt(lRoomId, "lRoomId");
    ds.DisplayString(sTraceSource, "sTraceSource");
    ds.DisplayString(sPassword, "sPassword");
    ds.DisplayInt(iRoomId, "iRoomId");
    ds.DisplayInt(iFreeFlowFlag, "iFreeFlowFlag");
    ds.DisplayInt(iIpStack, "iIpStack");
  }
}
