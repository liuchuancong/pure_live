import 'package:pure_live/pkg/tars/codec/tars_struct.dart';
import 'package:pure_live/pkg/tars/codec/tars_displayer.dart';
import 'package:pure_live/pkg/tars/codec/tars_input_stream.dart';
import 'package:pure_live/pkg/tars/codec/tars_output_stream.dart';
// ignore_for_file: no_leading_underscores_for_local_identifiers

class GetCdnTokenExResp extends TarsStruct {
  String sFlvToken = ""; //tag 0
  int iExpireTime = 0; //tag 1

  @override
  void readFrom(TarsInputStream inputStream) {
    sFlvToken = inputStream.read(sFlvToken, 0, false);
    iExpireTime = inputStream.read(iExpireTime, 1, false);
  }

  @override
  void writeTo(TarsOutputStream outputStream) {
    outputStream.write(sFlvToken, 0);
    outputStream.write(iExpireTime, 1);
  }

  @override
  TarsStruct deepCopy() {
    return GetCdnTokenExResp()
      ..sFlvToken = sFlvToken
      ..iExpireTime = iExpireTime;
  }

  @override
  displayAsString(StringBuffer sb, int level) {
    TarsDisplayer ds = TarsDisplayer(sb, level: level);
    ds.DisplayString(sFlvToken, "sFlvToken");
    ds.DisplayInt(iExpireTime, "iExpireTime");
  }
}
