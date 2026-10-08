import 'dart:typed_data';

class BinaryWriter {
  List<int> buffer;
  int position = 0;
  BinaryWriter(this.buffer);
  int get length => buffer.length;

  void writeBytes(List<int> list) {
    buffer.addAll(list);
    position += list.length;
  }

  void writeInt(int value, int len, {Endian endian = Endian.big}) {
    var b = Uint8List(len).buffer;
    var bytes = ByteData.view(b);
    if (len == 1) {
      bytes.setUint8(0, value.toUnsigned(8));
    }
    if (len == 2) {
      bytes.setInt16(0, value, endian);
    }
    if (len == 4) {
      bytes.setInt32(0, value, endian);
    }
    if (len == 8) {
      bytes.setInt64(0, value, endian);
    }

    buffer.addAll(bytes.buffer.asUint8List());
    position += len;
  }

  void writeDouble(double value, int len, {Endian endian = Endian.big}) {
    var b = Uint8List(len).buffer;
    var bytes = ByteData.view(b);

    if (len == 4) {
      bytes.setFloat32(0, value, endian);
    }
    if (len == 8) {
      bytes.setFloat64(0, value, endian);
    }

    buffer.addAll(bytes.buffer.asUint8List());
    position += len;
  }
}

class BinaryReader {
  Uint8List buffer;
  int position = 0;
  BinaryReader(this.buffer);
  int get length => buffer.length;

  int read() {
    var byte = buffer[position];
    position += 1;
    return byte;
  }

  int readInt(int len, {Endian endian = Endian.big}) {
    var result = 0;
    // if (len == 1) {
    //   result = buffer[position];
    //   position += len;
    //   return result;
    // }
    var bytes =
        Uint8List.fromList(buffer.getRange(position, position + len).toList());
    var byteBuffer = bytes.buffer;
    var data = ByteData.view(byteBuffer);
    if (len == 1) {
      result = data.getUint8(0);
    }
    if (len == 2) {
      result = data.getInt16(0, endian);
    }
    if (len == 4) {
      result = data.getInt32(0, endian);
    }
    if (len == 8) {
      result = data.getInt64(0, endian);
    }
    position += len;
    return result;
  }

  int readByte({Endian endian = Endian.big}) {
    return readInt(1, endian: endian);
  }

  int readShort({Endian endian = Endian.big}) {
    return readInt(2, endian: endian);
  }

  int readInt32({Endian endian = Endian.big}) {
    return readInt(4, endian: endian);
  }

  int readLong({Endian endian = Endian.big}) {
    return readInt(8, endian: endian);
  }

  Uint8List readBytes(int len) {
    var bytes =
        Uint8List.fromList(buffer.getRange(position, position + len).toList());
    position += len;
    return bytes;
  }

  double readFloat(int len, {Endian endian = Endian.big}) {
    var result = 0.0;
    var bytes =
        Uint8List.fromList(buffer.getRange(position, position + len).toList());
    var byteBuffer = bytes.buffer;
    var data = ByteData.view(byteBuffer);
    if (len == 4) {
      result = data.getFloat32(0, endian);
    }
    if (len == 8) {
      result = data.getFloat64(0, endian);
    }
    position += len;
    return result;
  }
}
