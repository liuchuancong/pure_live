import 'const.dart';
import 'dart:typed_data';
import 'uni_packet.dart';
import 'package:pure_live/core/logging/app_log.dart';

class TarsUniPacket extends UniPacket {
  TarsUniPacket() {
    package.iVersion = Const.PACKET_TYPE_TUP3;
    package.cPacketType = Const.PACKET_TYPE_TARSNORMAL;
    package.iMessageType = 0;
    package.iTimeout = 0;
    package.sBuffer = Uint8List.fromList([0x0]);
    package.context = <String, String>{};
    package.status = <String, String>{};
  }

  void setTarsVersion(int version) {
    setVersion(version);
  }

  void setTarsPacketType(int packetType) {
    package.cPacketType = packetType;
  }

  void setTarsMessageType(int messageType) {
    package.iMessageType = messageType;
  }

  void setTarsTimeout(int timeout) {
    package.iTimeout = timeout;
  }

  void setTarsBuffer(Uint8List buffer) {
    package.sBuffer = buffer;
  }

  void setTarsContext(Map<String, String> context) {
    package.context = context;
  }

  void setTarsStatus(Map<String, String> status) {
    package.status = status;
  }

  int getTarsVersion() {
    return package.iVersion;
  }

  int getTarsPacketType() {
    return package.cPacketType;
  }

  int getTarsMessageType() {
    return package.iMessageType;
  }

  int getTarsTimeout() {
    return package.iTimeout;
  }

  Uint8List? getTarsBuffer() {
    return package.sBuffer;
  }

  Map<String, String>? getTarsContext() {
    return package.context;
  }

  Map<String, String>? getTarsStatus() {
    return package.status;
  }

  int getTarsResultCode() {
    int result = 0;
    try {
      String? rcode = package.status?[Const.STATUS_RESULT_CODE];
      result = (rcode != null ? int.tryParse(rcode) : 0)!;
    } catch (e) {
      Log.d('getTarsResultCode exception: $e');
      return 0;
    }
    return result;
  }

  String getTarsResultDesc() {
    String? rdesc = package.status?[Const.STATUS_RESULT_DESC];
    String result = rdesc ?? "";
    return result;
  }
}
