import 'package:pure_live/pkg/tars/codec/tars_struct.dart';
import 'package:pure_live/pkg/tars/codec/tars_displayer.dart';
import 'package:pure_live/pkg/tars/codec/tars_input_stream.dart';
import 'package:pure_live/pkg/tars/codec/tars_output_stream.dart';

class GetCdnTokenExResp extends TarsStruct {
  String sFlvToken = ""; //tag 0
  int iExpireTime = 0; //tag 1

  @override
  void readFrom(TarsInputStream tarsInputStream) {
    sFlvToken = tarsInputStream.read(sFlvToken, 0, false);
    iExpireTime = tarsInputStream.read(iExpireTime, 1, false);
  }

  @override
  void writeTo(TarsOutputStream tarsOutputStream) {
    tarsOutputStream.write(sFlvToken, 0);
    tarsOutputStream.write(iExpireTime, 1);
  }

  @override
  TarsStruct deepCopy() {
    return GetCdnTokenExResp()
      ..sFlvToken = sFlvToken
      ..iExpireTime = iExpireTime;
  }

  @override
  displayAsString(StringBuffer sb, int level) {
    TarsDisplayer tarsDisplayer = TarsDisplayer(sb, level: level);
    tarsDisplayer.DisplayString(sFlvToken, "sFlvToken");
    tarsDisplayer.DisplayInt(iExpireTime, "iExpireTime");
  }
}
