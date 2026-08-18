import 'dart:ui';

class ColorUtil {
  const ColorUtil._();

  static Color fromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  static Color fromInt(int value) {
    return Color(value);
  }

  static int toARGB32(Color color) {
    return color.toARGB32();
  }
}
