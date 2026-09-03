import 'dart:typed_data';

import 'package:pure_live/pkg/tars/codec/tars_struct.dart';
import 'package:pure_live/pkg/tars/tup/request_packet.dart';
import 'package:pure_live/pkg/tars/codec/tars_displayer.dart';
import 'package:pure_live/pkg/tars/codec/tars_input_stream.dart';
import 'package:pure_live/pkg/tars/codec/tars_output_stream.dart';

// ignore_for_file: no_leading_underscores_for_local_identifiers

class TarsMessage extends TarsStruct {
  String className() {
    return 'TarsMessage';
  }

  RequestPacket header = RequestPacket();
  Map<String, Uint8List> body = <String, Uint8List>{};

  @override
  void readFrom(TarsInputStream _is) {
    header = _is.readTarsStruct(header, 0, false) as RequestPacket;
    body = _is.readMap<String, Uint8List>(body, 1, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(header, 0);
    _os.write(body, 1);
  }

  @override
  TarsStruct deepCopy() {
    return TarsMessage()
      ..header = header.deepCopy() as RequestPacket
      ..body = Map<String, Uint8List>.from(body);
  }

  @override
  void displayAsString(StringBuffer sb, int level) {
    TarsDisplayer _ds = TarsDisplayer(sb, level: level);
    _ds.display(header, 'header');
    _ds.display(body, 'body');
  }
}
