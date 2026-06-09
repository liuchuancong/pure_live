import 'dart:core';
import 'dart:typed_data';
import 'package:pure_live/pkg/tars/codec/tars_struct.dart';
import 'package:pure_live/pkg/tars/codec/tars_displayer.dart';
import 'package:pure_live/pkg/tars/codec/tars_input_stream.dart';
import 'package:pure_live/pkg/tars/codec/tars_output_stream.dart';
import 'package:pure_live/pkg/tars/codec/tars_deep_copyable.dart';
// ignore_for_file: non_constant_identifier_names, avoid_renaming_method_parameters, no_leading_underscores_for_local_identifiers

class RequestPacket extends TarsStruct {
  String className() {
    return "RequestPacket";
  }

  int iVersion = 0;

  int cPacketType = 0;

  int iMessageType = 0;

  int iRequestId = 0;

  String sServantName = "";

  String sFuncName = "";

  Uint8List? sBuffer;

  int iTimeout = 0;

  Map<String, String>? context;

  Map<String, String>? status;

  RequestPacket({
    this.iVersion = 0,
    this.cPacketType = 0,
    this.iMessageType = 0,
    this.iRequestId = 0,
    this.sServantName = "",
    this.sFuncName = "",
    this.sBuffer,
    this.iTimeout = 0,
    this.context,
    this.status,
  });

  @override
  void writeTo(TarsOutputStream outputStream) {
    outputStream.write(iVersion, 1);
    outputStream.write(cPacketType, 2);
    outputStream.write(iMessageType, 3);
    outputStream.write(iRequestId, 4);
    outputStream.write(sServantName, 5);
    outputStream.write(sFuncName, 6);
    outputStream.write(sBuffer, 7);
    outputStream.write(iTimeout, 8);
    outputStream.write(context, 9);
    outputStream.write(status, 10);
  }

  static Uint8List cache_sBuffer = Uint8List.fromList([0x0]);
  static Map<String, String> cache_context = {"": ""};
  static Map<String, String> cache_status = {"": ""};

  @override
  void readFrom(TarsInputStream inputStream) {
    iVersion = inputStream.read<int>(iVersion, 1, false);
    cPacketType = inputStream.read<int>(cPacketType, 2, false);
    iMessageType = inputStream.read<int>(iMessageType, 3, false);
    iRequestId = inputStream.read<int>(iRequestId, 4, false);
    sServantName = inputStream.read<String>(sServantName, 5, false);
    sFuncName = inputStream.read<String>(sFuncName, 6, false);
    sBuffer = inputStream.read<int>(cache_sBuffer, 7, false);
    iTimeout = inputStream.read<int>(iTimeout, 8, false);
    context = inputStream.readMap<String, String>(cache_context, 9, false);
    status = inputStream.readMap<String, String>(cache_status, 10, false);
  }

  @override
  void displayAsString(StringBuffer outputStream, int _level) {
    TarsDisplayer ds = TarsDisplayer(outputStream, level: _level);
    ds.display(iVersion, "iVersion");
    ds.display(cPacketType, "cPacketType");
    ds.display(iMessageType, "iMessageType");
    ds.display(iRequestId, "iRequestId");
    ds.display(sServantName, "sServantName");
    ds.display(sFuncName, "sFuncName");
    ds.display(sBuffer, "sBuffer");
    ds.display(iTimeout, "iTimeout");
    ds.display(context, "context");
    ds.display(status, "status");
  }

  @override
  Object deepCopy() {
    var o = RequestPacket();
    o.iVersion = iVersion;
    o.cPacketType = cPacketType;
    o.iMessageType = iMessageType;
    o.iRequestId = iRequestId;
    o.sServantName = sServantName;
    o.sFuncName = sFuncName;
    o.sBuffer = sBuffer;
    o.iTimeout = iTimeout;
    if (null != context) {
      o.context = mapDeepCopy<String, String>(context!);
    }
    if (null != status) {
      o.status = mapDeepCopy<String, String>(status!);
    }
    return o;
  }
}
