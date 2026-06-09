import 'package:pure_live/core/tars/huya_user_id.dart';
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
  void readFrom(TarsInputStream inputStream) {
    sFlvUrl = inputStream.read(sFlvUrl, 0, false);
    sStreamName = inputStream.read(sStreamName, 1, false);
    iLoopTime = inputStream.read(iLoopTime, 2, false);
    tId = inputStream.read(tId, 3, false);
    iAppId = inputStream.read(iAppId, 4, false);
  }

  @override
  void writeTo(TarsOutputStream outputStream) {
    outputStream.write(sFlvUrl, 0);
    outputStream.write(sStreamName, 1);
    outputStream.write(iLoopTime, 2);
    outputStream.write(tId, 3);
    outputStream.write(iAppId, 4);
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
    TarsDisplayer ds = TarsDisplayer(sb, level: level);
    ds.DisplayString(sFlvUrl, "sFlvUrl");
    ds.DisplayString(sStreamName, "sStreamName");
    ds.DisplayInt(iLoopTime, "iLoopTime");
    ds.DisplayTarsStruct(tId, "tId");
    ds.DisplayInt(iAppId, "iAppId");
  }
}
