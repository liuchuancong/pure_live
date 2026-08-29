import 'game_event_message_board_info.dart';
import 'package:pure_live/pkg/tars/codec/tars_struct.dart';
import 'package:pure_live/pkg/tars/codec/tars_displayer.dart';
import 'package:pure_live/pkg/tars/codec/tars_input_stream.dart';
import 'package:pure_live/pkg/tars/codec/tars_output_stream.dart';


class GameEventMessageBoardPanel extends TarsStruct {
  List<GameEventMessageBoardInfo> vGameEventMessageBoardInfo = [GameEventMessageBoardInfo()];

  @override
  void readFrom(TarsInputStream tarsInputStream) {
    vGameEventMessageBoardInfo = tarsInputStream
        .read(vGameEventMessageBoardInfo, 1, false)
        .cast<GameEventMessageBoardInfo>();
  }

  @override
  void writeTo(TarsOutputStream tarsOutputStream) {
    tarsOutputStream.write(vGameEventMessageBoardInfo, 1);
  }

  @override
  Object deepCopy() {
    return GameEventMessageBoardPanel()
      ..vGameEventMessageBoardInfo = vGameEventMessageBoardInfo
          .map((e) => e.deepCopy() as GameEventMessageBoardInfo)
          .toList();
  }

  @override
  void displayAsString(StringBuffer sb, int level) {
    final ds = TarsDisplayer(sb, level: level);
    ds.display(vGameEventMessageBoardInfo, "vGameEventMessageBoardInfo");
  }
}
