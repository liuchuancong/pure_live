import 'package:pure_live/core/tars/types.dart';
import 'package:pure_live/pkg/tars/codec/tars_struct.dart';
import 'package:pure_live/pkg/tars/codec/tars_displayer.dart';
import 'package:pure_live/pkg/tars/codec/tars_input_stream.dart';
import 'package:pure_live/pkg/tars/codec/tars_output_stream.dart';

class GetGameEventMessageBoardReq extends TarsStruct {
  int lPid = 0; //tag 0
  String sOffset = ""; //tag 1
  HuyaUserId tId = HuyaUserId(); //tag 2
  int iMessageBoardScope = 0; //tag 3
  int iPageSize = 10; //tag 4

  @override
  void readFrom(TarsInputStream tarsInputStream) {
    lPid = tarsInputStream.read(lPid, 0, false);
    sOffset = tarsInputStream.read(sOffset, 1, false);
    tId = tarsInputStream.read(tId, 2, false);
    iMessageBoardScope = tarsInputStream.read(iMessageBoardScope, 3, false);
    iPageSize = tarsInputStream.read(iPageSize, 4, false);
  }

  @override
  void writeTo(TarsOutputStream tarsOutputStream) {
    tarsOutputStream.write(lPid, 0);
    tarsOutputStream.write(sOffset, 1);
    tarsOutputStream.write(tId, 2);
    tarsOutputStream.write(iMessageBoardScope, 3);
    tarsOutputStream.write(iPageSize, 4);
  }

  @override
  TarsStruct deepCopy() {
    return GetGameEventMessageBoardReq()
      ..lPid = lPid
      ..sOffset = sOffset
      ..tId = tId
      ..iMessageBoardScope = iMessageBoardScope
      ..iPageSize = iPageSize;
  }

  @override
  displayAsString(StringBuffer sb, int level) {
    TarsDisplayer tarsDisplayer = TarsDisplayer(sb, level: level);
    tarsDisplayer.DisplayInt(lPid, "lPid");
    tarsDisplayer.DisplayString(sOffset, "sOffset");
    tarsDisplayer.DisplayTarsStruct(tId, "tId");
    tarsDisplayer.DisplayInt(iMessageBoardScope, "iMessageBoardScope");
    tarsDisplayer.DisplayInt(iPageSize, "iPageSize");
  }
}
