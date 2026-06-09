import 'package:pure_live/pkg/tars/codec/tars_struct.dart';
import 'package:pure_live/pkg/tars/codec/tars_displayer.dart';
import 'package:pure_live/pkg/tars/codec/tars_input_stream.dart';
import 'package:pure_live/pkg/tars/codec/tars_output_stream.dart';
// ignore_for_file: no_leading_underscores_for_local_identifiers

class GetCdnTokenResp extends TarsStruct {
  String url = "";

  String cdnType = "";

  String streamName = "";

  int presenterUid = 0;

  String antiCode = "";

  String sTime = "";

  String flvAntiCode = "";

  String hlsAntiCode = "";

  @override
  void readFrom(TarsInputStream inputStream) {
    url = inputStream.read(url, 0, false);
    cdnType = inputStream.read(cdnType, 1, false);
    streamName = inputStream.read(streamName, 2, false);
    presenterUid = inputStream.read(presenterUid, 3, false);
    antiCode = inputStream.read(antiCode, 4, false);
    sTime = inputStream.read(sTime, 5, false);
    flvAntiCode = inputStream.read(flvAntiCode, 6, false);
    hlsAntiCode = inputStream.read(hlsAntiCode, 7, false);
  }

  @override
  void writeTo(TarsOutputStream outputStream) {
    outputStream.write(url, 0);
    outputStream.write(cdnType, 1);
    outputStream.write(streamName, 2);
    outputStream.write(presenterUid, 3);
    outputStream.write(antiCode, 4);
    outputStream.write(sTime, 5);
    outputStream.write(flvAntiCode, 6);
    outputStream.write(hlsAntiCode, 7);
  }

  @override
  Object deepCopy() {
    return GetCdnTokenResp()
      ..url = url
      ..cdnType = cdnType
      ..streamName = streamName
      ..presenterUid = presenterUid
      ..antiCode = antiCode
      ..sTime = sTime
      ..flvAntiCode = flvAntiCode
      ..hlsAntiCode = hlsAntiCode;
  }

  @override
  void displayAsString(StringBuffer sb, int level) {
    TarsDisplayer ds = TarsDisplayer(sb, level: level);
    ds.DisplayString(url, "url");
    ds.DisplayString(cdnType, "cdnType");
    ds.DisplayString(streamName, "streamName");
    ds.DisplayInt(presenterUid, "presenterUid");
    ds.DisplayString(antiCode, "antiCode");
    ds.DisplayString(sTime, "sTime");
    ds.DisplayString(flvAntiCode, "flvAntiCode");
    ds.DisplayString(hlsAntiCode, "hlsAntiCode");
  }

  @override
  String toString() {
    StringBuffer sb = StringBuffer()..write("GetCdnTokenResp(");
    sb.write("url=$url");
    sb.write(",cdnType=$cdnType");
    sb.write(",streamName=$streamName");
    sb.write(",antiCode=$antiCode");
    sb.write(",sTime=$sTime");
    sb.write(",flvAntiCode=$flvAntiCode");
    sb.write(",hlsAntiCode=$hlsAntiCode");
    sb.write(")");
    return sb.toString();
  }
}
