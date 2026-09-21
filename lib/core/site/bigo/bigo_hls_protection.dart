import 'dart:typed_data';

/// Parser and packet-prefix transform for Bigo's public web HLS extension.
/// Applying [transformSegment] twice with the same seed restores the source.
final class BigoHlsProtection {
  const BigoHlsProtection._();

  static final RegExp _tag = RegExp(
    r'^#EXT-X-BIGO-WEB-PROTECTION:SEED=([0-9]+)\s*$',
    multiLine: true,
    caseSensitive: false,
  );

  static int? seedFromManifest(String manifest) {
    final match = _tag.firstMatch(manifest);
    if (match == null) return null;
    final value = int.tryParse(match.group(1)!);
    if (value == null || value < 0 || value > 0xffffffff) {
      throw const FormatException('Invalid Bigo HLS protection seed');
    }
    return value;
  }

  static Uint8List transformSegment(List<int> source, int seed) {
    if (seed < 0 || seed > 0xffffffff) throw const FormatException('Invalid Bigo HLS protection seed');
    if (source.length < 376) throw const FormatException('Truncated Bigo HLS segment');
    final packets = Uint8List.fromList(source);
    for (var packet = 0; packet < 2; packet++) {
      var state = (seed ^ ((packet + 1) * 2654435769)) & 0xffffffff;
      if (state == 0) state = 1831565813;
      final packetOffset = packet * 188;
      for (var offset = 0; offset < 16; offset++) {
        state = (state ^ ((state << 13) & 0xffffffff)) & 0xffffffff;
        state = (state ^ (state >> 17)) & 0xffffffff;
        state = (state ^ ((state << 5) & 0xffffffff)) & 0xffffffff;
        var mask = state & 0xff;
        if (mask == 0) mask = 165;
        packets[packetOffset + offset] ^= mask;
      }
    }
    return packets;
  }
}
