import 'const.dart';
import 'uni_attribute.dart';
import 'request_packet.dart';
import 'package:pure_live/core/common/log.dart';
import 'package:pure_live/pkg/tars/tup/write_buffer.dart';
import 'package:pure_live/pkg/tars/codec/tars_input_stream.dart';
import 'package:pure_live/pkg/tars/codec/tars_output_stream.dart';

class UniPacket extends UniAttribute {
  static const int kUniPacketHeadSize = 4;

  RequestPacket package = RequestPacket();

  /// 获取请求的service名字
  ///
  /// @return
  String get servantName {
    return package.sServantName;
  }

  set servantName(String value) {
    package.sServantName = value;
  }

  /// 获取请求的函数名字
  ///
  /// @return
  String get funcName {
    return package.sFuncName;
  }

  set funcName(String value) {
    package.sFuncName = value;
  }

  /// 获取消息序列号
  ///
  /// @return
  int get requestId {
    return package.iRequestId;
  }

  set requestId(int value) {
    package.iRequestId = value;
  }

  UniPacket() {
    package.iVersion = Const.PACKET_TYPE_TUP3;
  }

  void setVersion(int iVer) {
    version = iVer;
    package.iVersion = iVer;
  }

  int getVersion() {
    return package.iVersion;
  }

  /// 将put的对象进行编码
  @override
  Uint8List encode() {
    if (package.sServantName.compareTo("") == 0) {
      throw ArgumentError("servantName can not is null");
    }
    if (package.sFuncName.compareTo("") == 0) {
      throw ArgumentError("funcName can not is null");
    }

    TarsOutputStream outputStream = TarsOutputStream();
    outputStream.setServerEncoding(encodeName);
    if (package.iVersion == Const.PACKET_TYPE_TUP) {
      throw UnimplementedError();
    } else {
      outputStream.write(newData, 0);
    }

    package.sBuffer = outputStream.toUint8List();

    outputStream = TarsOutputStream();
    outputStream.setServerEncoding(encodeName);
    writeTo(outputStream);
    Uint8List body = outputStream.toUint8List();
    int size = body.lengthInBytes;

    final WriteBuffer buffer = WriteBuffer();
    buffer.putInt32(size + kUniPacketHeadSize, endian: Endian.big);
    buffer.putUint8List(body);
    return buffer.done().buffer.asUint8List();
  }

  /// 对传入的数据进行解码 填充可get的对象
  @override
  void decode(Uint8List buffer, {int index = 0}) {
    if (buffer.lengthInBytes < kUniPacketHeadSize) {
      throw ArgumentError("Decode namespace must include size head");
    }
    try {
      TarsInputStream inputStream = TarsInputStream(buffer, pos: kUniPacketHeadSize + index);
      inputStream.setServerEncoding(encodeName);
      //解码出RequestPacket包
      readFrom(inputStream);

      //设置tup版本
      version = package.iVersion;

      inputStream = TarsInputStream(package.sBuffer);
      inputStream.setServerEncoding(encodeName);

      if (package.iVersion == Const.PACKET_TYPE_TUP) {
        oldData = inputStream.readMapMap<String, String, Uint8List>(
          <String, Map<String, Uint8List>>{
            "": {
              "": Uint8List.fromList([0x0]),
            },
          },
          0,
          false,
        );
      } else {
        newData = inputStream.readMap<String, Uint8List>(
          {
            "": Uint8List.fromList([0x0]),
          },
          0,
          false,
        );
      }
    } catch (e) {
      Log.d('decode exception: $e');
      rethrow;
    }
  }

  @override
  void writeTo(TarsOutputStream outputStream) {
    package.writeTo(outputStream);
  }

  @override
  void readFrom(TarsInputStream inputStream) {
    package.readFrom(inputStream);
  }
}
