// Dart port of hongguoTV's MediaCrypto (kotlin-tv/core), itself derived from
// drpys 22261ad; GPL-3.0-only. Derives the CDN content key from the model's
// `spade_a`, decrypts the legacy URL envelope, parses the CENC sample map
// out of the mp4 header and decrypts ranges on the fly.
import 'dart:convert' show utf8;
import 'dart:math' as math;
import 'dart:typed_data' show ByteData, Uint8List;

import 'package:crypto/crypto.dart' as crypto show sha512;
import 'package:pointycastle/export.dart' show AESEngine, CTRStreamCipher, KeyParameter, ParametersWithIV;

import 'package:pure_live/modules/hongguo/official/hongguo_signer.dart'
    show hongguoAesCbc, hongguoDecode64;

/// One encrypted range in the file: its place, its IV and how far into the
/// sample's cipher stream it begins (sub-sample clear leads).
final class HongguoSample {
  /// Creates the sample.
  const HongguoSample(this.start, this.end, this.iv, {this.encryptedOffset = 0});

  /// The first encrypted byte's file offset.
  final int start;

  /// One past the last encrypted byte.
  final int end;

  /// The sample's 16-byte CTR block (IV with the counter at zero).
  final Uint8List iv;

  /// How many encrypted bytes precede [start] inside this sample.
  final int encryptedOffset;
}

/// The parsed header: the de-encryptionised bytes a player may read as a
/// plain mp4, and the encrypted sample map over the rest of the file.
final class HongguoPrepared {
  /// Creates the prepared header.
  const HongguoPrepared(this.header, this.samples);

  /// The header bytes with `encv`/`enca` restored from `frma` and `sinf`
  /// blanked — what a plain mp4 reader expects.
  final Uint8List header;

  /// The encrypted samples, in file order.
  final List<HongguoSample> samples;
}

final class HongguoMediaCrypto {
  const HongguoMediaCrypto._();

  /// The KDF salt the URL envelope and the device register share.
  static final Uint8List kdfSalt = _hex(
    '4dd4c2e6b83162090e52b3c7a6733ba41cb2462b829ab58a196b39db57177524'
    'f49baf7f08e8d68d26a72e37c1a95a2f1f05a51892aef2949732b62a38aadd58',
  );

  /// Derives the 16-byte AES content key from the model's `spade_a`.
  static Uint8List deriveKey(String value) {
    final raw = hongguoDecode64(value);
    if (raw.length < 3) {
      throw const FormatException('内容密钥格式异常');
    }
    final length = math.min(raw.length - (raw[0] ^ raw[1] ^ raw[2]) + 47, raw.length - 1);
    if (length < 33) {
      throw const FormatException('内容密钥格式异常');
    }
    final work = Uint8List.fromList(raw.sublist(1, 1 + length));
    var a = 85;
    var b = 246;
    for (var i = 0; i < work.length; i++) {
      final old = work[i];
      final previous = i & 1 != 0 ? a : b;
      if (i & 1 != 0) {
        a = old;
      } else {
        b = old;
      }
      work[i] = (-21 - _bitCount(i) + (previous ^ old)) & 0xFF;
    }
    final key = _hex(utf8.decode(work.sublist(1, 33), allowMalformed: true));
    if (key.length != 16) {
      throw const FormatException('内容密钥格式异常');
    }
    return key;
  }

  /// Decrypts the legacy fallback API's URL envelope with its `key_seed`.
  static String decryptUrl(String value, Uint8List seed) {
    final raw = hongguoDecode64(value);
    if (raw.length < 20 || raw[0] != 0xA8 || raw[2] != 1 || raw[3] != 0) {
      throw const FormatException('播放地址格式异常');
    }
    final hashed = crypto.sha512.convert([...crypto.sha512.convert(seed).bytes, ...kdfSalt]).bytes;
    final body = raw.sublist(4, 4 + (raw.length - 4) ~/ 16 * 16);
    final bytes = hongguoAesCbc(
      Uint8List.fromList(hashed.sublist(0, 16)),
      Uint8List.fromList(hashed.sublist(16, 32)),
      Uint8List.fromList(body),
      decrypt: true,
    );
    var end = bytes.length;
    final padding = bytes.last;
    if (padding >= 1 && padding <= 16 && padding <= end) end -= padding;
    while (end > 0 && bytes[end - 1] == 0) {
      end--;
    }
    return utf8.decode(bytes.sublist(0, end), allowMalformed: true);
  }

  static int _u32(Uint8List data, int at) => ByteData.sublistView(data).getUint32(at);

  static int _i32(Uint8List data, int at) => ByteData.sublistView(data).getInt32(at);

  static int _i64(Uint8List data, int at) => ByteData.sublistView(data).getInt64(at);

  /// Where the mp4's moov ends: the header a player needs before samples.
  static int headerEnd(Uint8List first, int total) {
    if (first.length < 16 || String.fromCharCodes(first.sublist(4, 8)) != 'ftyp') {
      throw const FormatException('不支持的视频容器');
    }
    final ftyp = _u32(first, 0);
    if (ftyp < 8 || ftyp + 8 > first.length || String.fromCharCodes(first.sublist(ftyp + 4, ftyp + 8)) != 'moov') {
      throw const FormatException('视频索引不在文件开头');
    }
    final size = _u32(first, ftyp);
    final end = ftyp + size;
    if (size < 8 || end > total || end > 8 * 1024 * 1024) {
      throw const FormatException('视频索引大小异常');
    }
    return end;
  }

  static ({int start, int end, int body, String type})? _box(Uint8List data, int at, [int? limit]) {
    final bound = limit ?? data.length;
    if (at < 0 || at + 8 > bound) return null;
    var size = _u32(data, at);
    var header = 8;
    if (size == 1) {
      if (at + 16 > bound) return null;
      size = _i64(data, at + 8);
      header = 16;
    }
    if (size == 0) size = bound - at;
    if (size < header || size > bound - at) return null;
    return (
      start: at,
      end: at + size,
      body: at + header,
      type: String.fromCharCodes(data.sublist(at + 4, at + 8)),
    );
  }

  static ({int start, int end, int body, String type})? _find(Uint8List data, String type, int start, int limit) {
    for (var at = start; at <= limit - 8; at++) {
      if (data[at + 4] == type.codeUnitAt(0)) {
        final box = _box(data, at, limit);
        if (box?.type == type) return box;
      }
    }
    return null;
  }

  /// Parses the header's CENC sample map and returns the playable header.
  static HongguoPrepared prepare(Uint8List data, Uint8List? key) {
    if (key == null) return HongguoPrepared(Uint8List.fromList(data), const []);
    final moov = _box(data, _u32(data, 0));
    if (moov == null || moov.type != 'moov') {
      throw const FormatException('视频索引不完整');
    }
    final samples = <HongguoSample>[];
    final header = Uint8List.fromList(data);
    var cursor = moov.body;
    while (cursor < moov.end) {
      final track = _box(data, cursor, moov.end);
      if (track == null) throw const FormatException('视频轨道格式异常');
      cursor = track.end;
      if (track.type != 'trak') continue;
      final stbl = _find(data, 'stbl', track.body, track.end);
      if (stbl == null) continue;
      final saiz = _find(data, 'saiz', stbl.body, stbl.end);
      if (saiz == null) continue;
      final saio = _find(data, 'saio', stbl.body, stbl.end);
      if (saio == null) throw const FormatException('视频加密索引缺失');
      final stsz = _find(data, 'stsz', stbl.body, stbl.end);
      if (stsz == null) throw const FormatException('样本索引缺失');
      final stsc = _find(data, 'stsc', stbl.body, stbl.end);
      if (stsc == null) throw const FormatException('块索引缺失');
      final chunksBox = _find(data, 'stco', stbl.body, stbl.end) ?? _find(data, 'co64', stbl.body, stbl.end);
      if (chunksBox == null) throw const FormatException('块偏移缺失');
      int count(int at, int limit) {
        if (at + 4 > limit) throw const FormatException('索引越界');
        final value = _u32(data, at);
        if (value > 200000) throw const FormatException('索引数量过大');
        return value;
      }

      final n = count(stsz.body + 8, stsz.end);
      final defaultSize = _u32(data, stsz.body + 4);
      if (defaultSize == 0 && stsz.body + 12 + n * 4 > stsz.end) {
        throw const FormatException('样本索引截断');
      }
      final sizes = List<int>.generate(n, (i) => defaultSize > 0 ? defaultSize : _u32(data, stsz.body + 12 + i * 4));
      final chunkCount = count(chunksBox.body + 4, chunksBox.end);
      final width = chunksBox.type == 'co64' ? 8 : 4;
      if (chunksBox.body + 8 + chunkCount * width > chunksBox.end) {
        throw const FormatException('块偏移截断');
      }
      final offsets = List<int>.generate(
        chunkCount,
        (i) => width == 8 ? _i64(data, chunksBox.body + 8 + i * width) : _u32(data, chunksBox.body + 8 + i * width),
      );
      final entryCount = count(stsc.body + 4, stsc.end);
      if (stsc.body + 8 + entryCount * 12 > stsc.end || entryCount == 0) {
        throw const FormatException('块索引截断');
      }
      final entries = List.generate(entryCount, (i) => (_u32(data, stsc.body + 8 + i * 12), _u32(data, stsc.body + 12 + i * 12)));
      final sizeBase = saiz.body + 4 + ((_i32(data, saiz.body) & 1) != 0 ? 8 : 0);
      if (sizeBase + 5 > saiz.end) throw const FormatException('辅助索引截断');
      final auxDefault = data[sizeBase];
      final auxCount = count(sizeBase + 1, saiz.end);
      if (auxCount != n || (auxDefault == 0 && sizeBase + 5 + n > saiz.end)) {
        throw const FormatException('辅助索引数量不一致');
      }
      final auxSizes = List<int>.generate(n, (i) => auxDefault > 0 ? auxDefault : data[sizeBase + 5 + i]);
      final offsetBase = saio.body + 4 + ((_i32(data, saio.body) & 1) != 0 ? 8 : 0);
      final offsetWidth = data[saio.body] == 1 ? 8 : 4;
      if (count(offsetBase, saio.end) != 1 || offsetBase + 4 + offsetWidth > saio.end) {
        throw const FormatException('不支持的辅助索引布局');
      }
      var aux = offsetWidth == 8 ? _i64(data, offsetBase + 4) : _u32(data, offsetBase + 4);
      final auxEnd = aux + auxSizes.fold(0, (total, size) => total + size);
      if (aux < 0 || auxEnd > data.length) throw const FormatException('辅助数据超出索引范围');
      var sampleIndex = 0;
      var entry = 0;
      for (var chunk = 0; chunk < offsets.length; chunk++) {
        while (entry + 1 < entries.length && entries[entry + 1].$1 <= chunk + 1) {
          entry++;
        }
        final sampleCount = entries[entry].$2;
        if (sampleCount > n - sampleIndex || entries[entry].$1 > chunk + 1) {
          throw const FormatException('样本与块数量不一致');
        }
        var position = offsets[chunk];
        for (var repeat = 0; repeat < sampleCount; repeat++) {
          final length = sizes[sampleIndex];
          final auxSize = auxSizes[sampleIndex];
          if (position < 0 || length <= 0 || position > 0x7FFFFFFFFFFFFFFF - length || auxSize < 8) {
            throw const FormatException('样本索引异常');
          }
          final iv = Uint8List(16)..setRange(0, 8, data.sublist(aux, aux + 8));
          if (auxSize == 8) {
            samples.add(HongguoSample(position, position + length, iv));
          } else {
            if (auxSize < 10) throw const FormatException('不支持的加密样本格式');
            final subs = (data[aux + 8] << 8) | data[aux + 9];
            if (auxSize != 10 + subs * 6) throw const FormatException('加密子样本索引异常');
            var offset = position;
            var encrypted = 0;
            for (var sub = 0; sub < subs; sub++) {
              final at = aux + 10 + sub * 6;
              final clear = (data[at] << 8) | data[at + 1];
              final size = _u32(data, at + 2);
              offset += clear;
              if (offset + size > position + length) throw const FormatException('加密子样本越界');
              if (size > 0) samples.add(HongguoSample(offset, offset + size, iv, encryptedOffset: encrypted));
              encrypted += size;
              offset += size;
            }
            if (offset != position + length) throw const FormatException('加密子样本长度异常');
          }
          position += length;
          aux += auxSize;
          sampleIndex++;
        }
      }
      if (sampleIndex != n) throw const FormatException('视频样本不完整');
      // Restore the original codec fourcc from frma and blank the sinf
      // wrapper, so a plain mp4 reader sees the track it can decode.
      var at = stbl.body;
      while (at + 8 <= stbl.end) {
        final sinf = _find(data, 'sinf', at, stbl.end);
        if (sinf == null) break;
        final frma = _find(data, 'frma', sinf.body, sinf.end);
        if (frma == null) throw const FormatException('原始编码格式缺失');
        if (frma.body + 4 > frma.end) throw const FormatException('原始编码格式无效');
        final original = data.sublist(frma.body, frma.body + 4);
        var entryAt = sinf.start - 1;
        while (entryAt >= stbl.body) {
          final type = String.fromCharCodes(data.sublist(entryAt, entryAt + 4));
          if (type == 'encv' || type == 'enca') {
            header.setRange(entryAt, entryAt + 4, original);
            break;
          }
          entryAt--;
        }
        header
          ..setRange(sinf.start + 4, sinf.start + 8, utf8.encode('free'))
          ..fillRange(sinf.body, sinf.end, 0);
        at = sinf.end;
      }
    }
    if (samples.isEmpty) throw const FormatException('视频加密索引不可用');
    samples.sort((a, b) => a.start.compareTo(b.start));
    final sorted = samples;
    for (var i = 0; i + 1 < sorted.length; i++) {
      if (sorted[i].end > sorted[i + 1].start) {
        throw const FormatException('视频样本重叠');
      }
    }
    return HongguoPrepared(header, sorted);
  }

  /// Decrypts [data], the bytes read from absolute file offset [start].
  static Uint8List decrypt(Uint8List data, int start, Uint8List? key, HongguoPrepared prepared) {
    final result = Uint8List.fromList(data);
    final end = start + data.length;
    if (start < prepared.header.length) {
      final stop = math.min(end, prepared.header.length);
      result.setRange(0, stop - start, prepared.header.sublist(start, stop));
    }
    if (key == null) return result;
    final samples = prepared.samples;
    var low = 0;
    var high = samples.length;
    while (low < high) {
      final middle = (low + high) >>> 1;
      if (samples[middle].end <= start) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    for (var i = low; i < samples.length; i++) {
      final sample = samples[i];
      if (sample.start >= end) break;
      final begin = math.max(start, sample.start);
      final stop = math.min(end, sample.end);
      if (begin >= stop) continue;
      final relative = begin - sample.start + sample.encryptedOffset;
      final skip = relative % 16;
      final iv = _counterPlus(sample.iv, relative ~/ 16);
      final chunk = Uint8List(skip + (stop - begin));
      chunk.setRange(skip, chunk.length, result.sublist(begin - start, stop - start));
      final decrypted = _aesCtr(key, iv, chunk).sublist(skip);
      result.setRange(begin - start, stop - start, decrypted);
    }
    return result;
  }

  /// IV + block counter, the top bytes kept, the low 64 added.
  static Uint8List _counterPlus(Uint8List iv, int blocks) {
    final out = Uint8List.fromList(iv);
    var carry = blocks;
    for (var i = 15; i >= 0 && carry > 0; i--) {
      final sum = out[i] + (carry & 0xFF);
      out[i] = sum & 0xFF;
      carry = (carry >>> 8) + (sum >>> 8);
    }
    return out;
  }

  static Uint8List _aesCtr(Uint8List key, Uint8List iv, Uint8List data) {
    final cipher = CTRStreamCipher(AESEngine())
      ..init(false, ParametersWithIV(KeyParameter(key), iv));
    return cipher.process(data);
  }

  static int _bitCount(int value) {
    var count = 0;
    var v = value;
    while (v != 0) {
      v &= v - 1;
      count++;
    }
    return count;
  }

  static Uint8List _hex(String value) => Uint8List.fromList([
    for (var i = 0; i < value.length; i += 2) int.parse(value.substring(i, i + 2), radix: 16),
  ]);
}
