import 'package:pure_live/core/tars/types.dart';
import 'package:pure_live/pkg/tars/codec/tars_struct.dart';
import 'package:pure_live/pkg/tars/codec/tars_displayer.dart';
import 'package:pure_live/pkg/tars/codec/tars_input_stream.dart';
import 'package:pure_live/pkg/tars/codec/tars_output_stream.dart';



class GameEventMessageBoardInfo extends TarsStruct {
  MessageUser tMessageUser = MessageUser(); //tag 0
  String sContent = ""; //tag 1
  int iCost = 0; //tag 2
  int iTotalSec = 0; //tag 4
  int iCountDown = 0; //tag 5
  int lMessageId = 0; //tag 9
  int iCostPay = 0; //tag 12

  @override
  void readFrom(TarsInputStream tarsInputStream) {
    tMessageUser         = tarsInputStream.read(tMessageUser, 0, false);
    sContent             = tarsInputStream.read(sContent, 1, false);
    iCost                = tarsInputStream.read(iCost, 2, false);
    iTotalSec            = tarsInputStream.read(iTotalSec, 4, false);
    iCountDown           = tarsInputStream.read(iCountDown, 5, false);
    lMessageId           = tarsInputStream.read(lMessageId, 9, false);
    iCostPay             = tarsInputStream.read(iCostPay, 12, false);
  }

  @override
  void writeTo(TarsOutputStream tarsOutputStream) {
    tarsOutputStream.write(tMessageUser, 0);
    tarsOutputStream.write(sContent, 1);
    tarsOutputStream.write(iCost, 2);
    tarsOutputStream.write(iTotalSec, 4);
    tarsOutputStream.write(iCountDown, 5);
    tarsOutputStream.write(lMessageId, 9);
    tarsOutputStream.write(iCostPay, 12);
  }

  @override
  TarsStruct deepCopy() {
    return GameEventMessageBoardInfo()
      ..tMessageUser = tMessageUser
      ..sContent = sContent
      ..iCost = iCost
      ..iTotalSec = iTotalSec
      ..iCountDown = iCountDown
      ..lMessageId = lMessageId
      ..iCostPay = iCostPay
    ;
  }

  @override
  displayAsString(StringBuffer sb, int level) {
    TarsDisplayer tarsDisplayer = TarsDisplayer(sb, level: level);
    tarsDisplayer.DisplayTarsStruct(tMessageUser, "tMessageUser");
    tarsDisplayer.DisplayString(sContent, "sContent");
    tarsDisplayer.DisplayInt(iCost, "iCost");
    tarsDisplayer.DisplayInt(iTotalSec, "iTotalSec");
    tarsDisplayer.DisplayInt(iCountDown, "iCountDown");
    tarsDisplayer.DisplayInt(lMessageId, "lMessageId");
    tarsDisplayer.DisplayInt(iCostPay, "iCostPay");
  }
}