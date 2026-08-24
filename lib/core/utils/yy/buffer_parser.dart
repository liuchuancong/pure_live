import 'dart:convert';
import 'dart:typed_data';

class BufferParser {
  late Uint8List buffer;
  int offset = 0;

  BufferParser(this.buffer);

  // 读取 32 位无符号整数
  int getUI32() {
    final value = ByteData.view(buffer.buffer).getUint32(offset, Endian.little);
    offset += 4;
    return value;
  }

  // 读取 16 位无符号整数
  int getUI16() {
    final value = ByteData.view(buffer.buffer).getUint16(offset, Endian.little);
    offset += 2;
    return value;
  }

  // 读取 UTF8 字符串（先读长度再读内容）
  String getUTF8() {
    final len = getUI16();
    final subBuffer = buffer.sublist(offset, offset + len);
    offset += len;
    return utf8.decode(subBuffer);
  }

  // 读取 String-String 映射
  Map<String, String> getStrStrMap() {
    final map = <String, String>{};
    final len = getUI32();
    for (var i = 0; i < len; i++) {
      final key = getUTF8();
      final value = getUTF8();
      map[key] = value;
    }
    return map;
  }

  // 64 位整数拼接（对应 JS addToUInt64）
  int addToUInt64(int high, int low) {
    return (high << 32) | (low & 0xFFFFFFFF);
  }
}
