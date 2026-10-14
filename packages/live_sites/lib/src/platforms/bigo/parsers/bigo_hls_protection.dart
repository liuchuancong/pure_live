import 'dart:typed_data';

/// Bigo's web HLS protection: a media playlist tag carries a seed, and the first
/// 16 bytes of each of a segment's first two 188-byte TS packets are XOR-ed with
/// a xorshift stream of that seed (the sync byte and the PAT/PMT become
/// unreadable). Applying [transform] twice with one seed restores the input, so
/// the same call that scrambles a segment unscrambles it.
///
/// The adapter hands out the playlist as the site writes it; whoever plays it
/// relays every segment through [transform] with [seed] (see the ledger's
/// deferred note for bigo playback).
abstract final class BigoHlsProtection {
  /// The bytes a segment's transform touches (two TS packets).
  static const int prefixBytes = 376;

  /// The packet size of an MPEG-TS stream.
  static const int packetBytes = 188;

  static final RegExp _tag = RegExp(r'^#EXT-X-BIGO-WEB-PROTECTION:(.*)$', multiLine: true, caseSensitive: false);
  static final RegExp _seed = RegExp(r'(?:^|,)\s*SEED=([0-9]+)\s*(?:,|$)', caseSensitive: false);

  /// The seed of media [playlist], or null when it is not protected. The seed is
  /// looked for in the tag's attribute list — the tag of 2026-09 carries
  /// `VERSION=1,SEED=…`, and reading `SEED=` only right after the colon leaves
  /// the segments scrambled. A tag without a seed, or a seed over 2³² − 1, is a
  /// [FormatException].
  static int? seed(String playlist) {
    final attributes = _tag.firstMatch(playlist)?.group(1);
    if (attributes == null) return null;
    final value = _seed.firstMatch(attributes.trim())?.group(1);
    final seed = value == null ? null : int.tryParse(value);
    if (seed == null || seed > 0xffffffff) throw FormatException('Invalid Bigo HLS protection', attributes);
    return seed;
  }

  /// [segment] with its first two TS packets transformed by [seed]: for packet
  /// k = 0, 1 the state starts at seed XOR (k + 1) × 2654435769 (1831565813 when
  /// that is 0), and each of the packet's first 16 bytes is XOR-ed with the low
  /// byte of the next xorshift state (13, 17, 5; 165 when that byte is 0).
  /// A segment shorter than [prefixBytes] or a seed out of range is a
  /// [FormatException].
  static Uint8List transform(List<int> segment, int seed) {
    if (seed < 0 || seed > 0xffffffff) throw FormatException('Invalid Bigo HLS protection seed', seed);
    if (segment.length < prefixBytes) throw const FormatException('Truncated Bigo HLS segment');
    final packets = Uint8List.fromList(segment);
    for (var packet = 0; packet < 2; packet++) {
      var state = (seed ^ ((packet + 1) * 2654435769)) & 0xffffffff;
      if (state == 0) state = 1831565813;
      for (var offset = 0; offset < 16; offset++) {
        state = (state ^ ((state << 13) & 0xffffffff)) & 0xffffffff;
        state = (state ^ (state >> 17)) & 0xffffffff;
        state = (state ^ ((state << 5) & 0xffffffff)) & 0xffffffff;
        final mask = state & 0xff;
        packets[packet * packetBytes + offset] ^= mask == 0 ? 165 : mask;
      }
    }
    return packets;
  }
}
