import 'package:pure_live/pkg/tars/codec/tars_struct.dart';
import 'package:pure_live/pkg/tars/codec/tars_displayer.dart';
import 'package:pure_live/pkg/tars/codec/tars_input_stream.dart';
import 'package:pure_live/pkg/tars/codec/tars_output_stream.dart';
// ignore_for_file: no_leading_underscores_for_local_identifiers

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
