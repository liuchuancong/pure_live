import 'package:pure_live/core/tars/types.dart';
import 'package:pure_live/pkg/tars/codec/tars_struct.dart';
import 'package:pure_live/pkg/tars/codec/tars_displayer.dart';
import 'package:pure_live/pkg/tars/codec/tars_input_stream.dart';
import 'package:pure_live/pkg/tars/codec/tars_output_stream.dart';

class GetCdnTokenExReq extends TarsStruct {
  String sFlvUrl = ""; //tag 0
  String sStreamName = ""; //tag 1
  int iLoopTime = 0; //tag 2
  HuyaUserId tId = HuyaUserId(); //tag 3
  int iAppId = 66; //tag 4

  @override
  void readFrom(TarsInputStream tarsInputStream) {
    sFlvUrl = tarsInputStream.read(sFlvUrl, 0, false);
    sStreamName = tarsInputStream.read(sStreamName, 1, false);
    iLoopTime = tarsInputStream.read(iLoopTime, 2, false);
    tId = tarsInputStream.read(tId, 3, false);
    iAppId = tarsInputStream.read(iAppId, 4, false);
  }

  @override
  void writeTo(TarsOutputStream tarsOutputStream) {
    tarsOutputStream.write(sFlvUrl, 0);
    tarsOutputStream.write(sStreamName, 1);
    tarsOutputStream.write(iLoopTime, 2);
    tarsOutputStream.write(tId, 3);
    tarsOutputStream.write(iAppId, 4);
  }

  @override
  TarsStruct deepCopy() {
    return GetCdnTokenExReq()
      ..sFlvUrl = sFlvUrl
      ..sStreamName = sStreamName
      ..iLoopTime = iLoopTime
      ..tId = tId
      ..iAppId = iAppId;
  }

  @override
  displayAsString(StringBuffer sb, int level) {
    TarsDisplayer tarsDisplayer = TarsDisplayer(sb, level: level);
    tarsDisplayer.DisplayString(sFlvUrl, "sFlvUrl");
    tarsDisplayer.DisplayString(sStreamName, "sStreamName");
    tarsDisplayer.DisplayInt(iLoopTime, "iLoopTime");
    tarsDisplayer.DisplayTarsStruct(tId, "tId");
    tarsDisplayer.DisplayInt(iAppId, "iAppId");
  }
}
