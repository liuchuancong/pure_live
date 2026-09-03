import 'game_event_message_board_panel.dart';

import 'package:pure_live/pkg/tars/codec/tars_struct.dart';
import 'package:pure_live/pkg/tars/codec/tars_displayer.dart';
import 'package:pure_live/pkg/tars/codec/tars_input_stream.dart';
import 'package:pure_live/pkg/tars/codec/tars_output_stream.dart';

class GetGameEventMessageBoardRsp extends TarsStruct {
  GameEventMessageBoardPanel tMessageBoardPanel = GameEventMessageBoardPanel();
  // mMessageBoardShowStyle--复用 bilibili sc样式
  @override
  void readFrom(TarsInputStream tarsInputStream) {
    tMessageBoardPanel = tarsInputStream.read(tMessageBoardPanel, 1, false);
  }

  @override
  void writeTo(TarsOutputStream tarsOutputStream) {
    tarsOutputStream.write(tMessageBoardPanel, 1);
  }

  @override
  Object deepCopy() {
    return GetGameEventMessageBoardRsp()
      ..tMessageBoardPanel = tMessageBoardPanel.deepCopy() as GameEventMessageBoardPanel;
  }

  @override
  void displayAsString(StringBuffer sb, int level) {
    final ds = TarsDisplayer(sb, level: level);
    ds.display(tMessageBoardPanel, 'tMessageBoardPanel');
  }
}
