import 'dart:typed_data';

import 'package:live_sites/src/common/codec/brotli_dictionary.dart';
import 'package:live_sites/src/common/codec/brotli_tables.dart';

/// Decodes [data], one complete Brotli stream (RFC 7932), and returns the
/// decompressed bytes.
///
/// Throws a [FormatException] when [data] is not exactly one valid stream:
/// truncated, corrupt, followed by more bytes, or using the "large window"
/// extension, which is not part of RFC 7932. Checks that the RFC leaves to the
/// decoder ("should be rejected") are made as in the reference decoder.
///
/// With [maxOutput], a stream that decompresses to more than [maxOutput]
/// bytes is a [FormatException] too. It is raised as soon as a meta-block
/// header announces a length past the limit, before that meta-block is
/// decoded or its memory is allocated, so a small input cannot make the
/// decoder produce or hold more than about [maxOutput] bytes. Set it for data
/// from the network.
///
/// Decoding is one-shot: Missevan danmaku frames and Bilibili protover 3
/// packets each carry one complete stream. The work is bounded by the size of
/// the input and the output, and memory by the output plus a few MiB of
/// prefix code tables.
Uint8List brotliDecode(List<int> data, {int? maxOutput}) {
  if (maxOutput != null) RangeError.checkNotNegative(maxOutput, 'maxOutput');
  final input = data is Uint8List ? data : Uint8List.fromList(data);
  return _BrotliDecoder(input, maxOutput).decode();
}

FormatException _invalid(String problem) => FormatException('Invalid Brotli stream: $problem');

/// Root bits of the two-level prefix code lookup tables.
const int _rootBits = 8;

/// Longest prefix code (RFC 7932 section 3.5).
const int _maxCodeLength = 15;

/// Upper bound of the lookup table of one complete prefix code, root and
/// second-level tables, over an alphabet of `size` symbols is `size + 376`
/// (the bound the reference decoder allocates).
const int _tableSlack = 376;

/// Order of the code length code lengths (RFC 7932 section 3.5).
const List<int> _codeLengthOrder = [1, 2, 3, 4, 0, 5, 17, 6, 16, 7, 8, 9, 10, 11, 12, 13, 14, 15];

/// The fixed variable-length code of the code length code lengths, indexed by
/// the next four bits: the value and the number of bits it takes.
const List<int> _codeLengthValue = [0, 4, 3, 2, 0, 4, 3, 1, 0, 4, 3, 2, 0, 4, 3, 5];
const List<int> _codeLengthBits = [2, 2, 2, 3, 2, 2, 2, 4, 2, 2, 2, 3, 2, 2, 2, 4];

/// Block count codes (RFC 7932 section 6): first count and extra bits.
const List<int> _blockCountBase = [
  // Codes 0 to 25.
  1, 5, 9, 13, 17, 25, 33, 41, 49, 65, 81, 97, 113, 145, 177, 209, 241, 305, 369, 497, 753, 1265, 2289, 4337,
  8433, 16625,
];
const List<int> _blockCountBits = [2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 6, 6, 7, 8, 9, 10, 11, 12, 13, 24];

/// Insert length codes (RFC 7932 section 5): first length and extra bits.
const List<int> _insertBase = [
  // Codes 0 to 23.
  0, 1, 2, 3, 4, 5, 6, 8, 10, 14, 18, 26, 34, 50, 66, 98, 130, 194, 322, 578, 1090, 2114, 6210, 22594,
];
const List<int> _insertBits = [0, 0, 0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 7, 8, 9, 10, 12, 14, 24];

/// Copy length codes (RFC 7932 section 5): first length and extra bits.
const List<int> _copyBase = [
  // Codes 0 to 23.
  2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 14, 18, 22, 30, 38, 54, 70, 102, 134, 198, 326, 582, 1094, 2118,
];
const List<int> _copyBits = [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 7, 8, 9, 10, 24];

/// Insert and copy length code ranges of each block of 64 insert-and-copy
/// symbols (the table in RFC 7932 section 5).
const List<int> _insertRangeStart = [0, 0, 0, 0, 8, 8, 0, 16, 8, 16, 16];
const List<int> _copyRangeStart = [0, 8, 0, 8, 0, 8, 16, 0, 16, 8, 16];

/// Per insert-and-copy symbol: `insert base << 5 | insert extra bits`.
final Int32List _commandInsert = Int32List.fromList([
  for (var symbol = 0; symbol < 704; symbol++)
    _insertBase[_insertRangeStart[symbol >> 6] + (symbol >> 3 & 7)] << 5 |
        _insertBits[_insertRangeStart[symbol >> 6] + (symbol >> 3 & 7)],
]);

/// Per insert-and-copy symbol: `copy base << 5 | copy extra bits`.
final Int32List _commandCopy = Int32List.fromList([
  for (var symbol = 0; symbol < 704; symbol++)
    _copyBase[_copyRangeStart[symbol >> 6] + (symbol & 7)] << 5 |
        _copyBits[_copyRangeStart[symbol >> 6] + (symbol & 7)],
]);

/// Block categories.
const int _literals = 0;
const int _commands = 1;
const int _distances = 2;

/// The prefix codes of one kind in a meta-block: lookup tables packed in
/// [table], tree `i` starting at `offsets[i]`.
final class _CodeGroup {
  new(this.table, this.offsets);

  final Int32List table;
  final Int32List offsets;
}

final class _BrotliDecoder {
  new(this._input, this._maxOutput)
    : _view = ByteData.sublistView(_input),
      _output = Uint8List(_initialCapacity(_input.length, _maxOutput));

  final Uint8List _input;
  final ByteData _view;
  final int? _maxOutput;

  Uint8List _output;
  int _outputLength = 0;

  // Bit reader: the low [_bitCount] bits of [_bitBuffer] are the next bits of
  // the stream, followed by the input from [_inputPosition]. Past the end of
  // the input it supplies zeros; having consumed any of them is reported as
  // truncation at the next refill or at the end of the stream. At most 63 bits
  // are held, so [_bitBuffer] stays non-negative.
  int _bitBuffer = 0;
  int _bitCount = 0;
  int _inputPosition = 0;

  /// Maximum backward distance (RFC 7932 section 9.1).
  int _windowSize = 0;

  /// The last four distances; the last one is at `(_distanceIndex - 1) & 3`.
  final Int32List _distanceRing = Int32List.fromList([16, 15, 11, 4]);
  int _distanceIndex = 0;

  // Block switching, per category: number of block types, symbols left in the
  // current block, and the previous and current block type.
  final Int32List _blockTypeCount = Int32List(3);
  final Int32List _blockLeft = Int32List(3);
  final Int32List _blockTypes = Int32List(6);
  final List<Int32List> _blockTypeCodes = List.filled(3, Int32List(0));
  final List<Int32List> _blockCountCodes = List.filled(3, Int32List(0));

  // Scratch space for reading prefix codes.
  final Int32List _codeLengths = Int32List(704);
  final Int32List _codeLengthCodeLengths = Int32List(18);
  final Int32List _codeLengthTable = Int32List(32);
  final Int32List _simpleSymbols = Int32List(4);
  final Int32List _lengthCount = Int32List(_maxCodeLength + 1);
  final Int32List _lengthOffset = Int32List(_maxCodeLength + 1);
  final Int32List _sortedSymbols = Int32List(704);

  static int _initialCapacity(int inputLength, int? maxOutput) {
    final guess = inputLength < 256 ? 1024 : inputLength * 4;
    return maxOutput != null && maxOutput < guess ? maxOutput : guess;
  }

  Uint8List decode() {
    _windowSize = (1 << _readWindowBits()) - 16;
    var last = false;
    while (!last) {
      last = _readBits(1) == 1;
      if (last && _readBits(1) == 1) break;
      final nibbles = _readBits(2) + 4;
      if (nibbles == 7) {
        _skipMetadata();
        continue;
      }
      var length = 0;
      for (var i = 0; i < nibbles; i++) {
        final nibble = _readBits(4);
        if (i == nibbles - 1 && nibbles > 4 && nibble == 0) throw _invalid('meta-block length has a zero top nibble');
        length |= nibble << 4 * i;
      }
      length++;
      final uncompressed = !last && _readBits(1) == 1;
      _reserve(length);
      if (uncompressed) {
        _copyUncompressed(length);
      } else {
        _decodeCompressed(length);
      }
    }
    _alignToByte();
    final consumed = _inputPosition - (_bitCount >> 3);
    if (consumed > _input.length) throw _invalid('truncated');
    if (consumed < _input.length) throw _invalid('${_input.length - consumed} bytes after the end of the stream');
    return _outputLength == _output.length ? _output : _output.sublist(0, _outputLength);
  }

  int _readWindowBits() {
    if (_readBits(1) == 0) return 16;
    final large = _readBits(3);
    if (large != 0) return 17 + large;
    final small = _readBits(3);
    if (small == 1) throw _invalid('large-window streams are not part of RFC 7932');
    return small == 0 ? 17 : 8 + small;
  }

  /// Makes room for a meta-block of [length] bytes, within the output limit.
  void _reserve(int length) {
    final needed = _outputLength + length;
    final limit = _maxOutput;
    if (limit != null && needed > limit) throw FormatException('Brotli output exceeds the limit of $limit bytes');
    if (needed <= _output.length) return;
    var capacity = _output.length * 2;
    if (capacity < needed) capacity = needed;
    if (limit != null && capacity > limit) capacity = limit;
    _output = Uint8List(capacity)..setRange(0, _outputLength, _output);
  }

  // Bit reader.

  @pragma('vm:prefer-inline')
  void _fill() {
    if (_bitCount < 32) _load();
  }

  void _load() {
    final position = _inputPosition;
    final end = _input.length;
    if (position + 4 <= end) {
      _bitBuffer |= _view.getUint32(position, Endian.little) << _bitCount;
    } else {
      // Near or past the end: the rest of the input, then zeros. Bits already
      // consumed past the end mean the stream is cut short.
      if ((position << 3) - _bitCount > end << 3) throw _invalid('truncated');
      var word = 0;
      for (var i = 0; i < 4 && position + i < end; i++) {
        word |= _input[position + i] << 8 * i;
      }
      _bitBuffer |= word << _bitCount;
    }
    _inputPosition = position + 4;
    _bitCount += 32;
  }

  /// Reads [count] (at most 32) bits.
  @pragma('vm:prefer-inline')
  int _readBits(int count) {
    _fill();
    final value = _bitBuffer & (1 << count) - 1;
    _bitBuffer >>= count;
    _bitCount -= count;
    return value;
  }

  /// Skips to the next byte boundary; the skipped bits must be zero.
  void _alignToByte() {
    if (_readBits(_bitCount & 7) != 0) throw _invalid('non-zero padding bits');
  }

  /// Position of the next input byte, after [_alignToByte]; empties the bit
  /// reader, which continues from [_inputPosition].
  int _takeBytePosition() {
    final position = _inputPosition - (_bitCount >> 3);
    _bitBuffer = 0;
    _bitCount = 0;
    return position;
  }

  void _skipMetadata() {
    if (_readBits(1) != 0) throw _invalid('reserved bit set');
    final bytes = _readBits(2);
    var length = 0;
    for (var i = 0; i < bytes; i++) {
      final byte = _readBits(8);
      if (i == bytes - 1 && bytes > 1 && byte == 0) throw _invalid('metadata length has a zero top byte');
      length |= byte << 8 * i;
    }
    if (bytes > 0) length++;
    _alignToByte();
    final start = _takeBytePosition();
    if (start + length > _input.length) throw _invalid('truncated');
    _inputPosition = start + length;
  }

  void _copyUncompressed(int length) {
    _alignToByte();
    final start = _takeBytePosition();
    if (start + length > _input.length) throw _invalid('truncated');
    _output.setRange(_outputLength, _outputLength + length, _input, start);
    _outputLength += length;
    _inputPosition = start + length;
  }

  // Prefix codes.

  /// Reads the next symbol with the code whose lookup table starts at
  /// [offset] in [table].
  @pragma('vm:prefer-inline')
  int _readSymbol(Int32List table, int offset) {
    _fill();
    final bits = _bitBuffer;
    var index = offset + (bits & 0xff);
    var entry = table[index];
    var length = entry >> 16;
    if (length > _rootBits) {
      index += (entry & 0xffff) + ((bits & (1 << length) - 1) >> _rootBits);
      entry = table[index];
      length = (entry >> 16) + _rootBits;
    }
    _bitBuffer = bits >> length;
    _bitCount -= length;
    return entry & 0xffff;
  }

  /// Reads a prefix code over [alphabetSize] symbols (RFC 7932 sections 3.4
  /// and 3.5) and writes its lookup table to [table] at [offset]; returns the
  /// table's size.
  int _readCode(int alphabetSize, Int32List table, int offset) {
    final lengths = _codeLengths..fillRange(0, alphabetSize, 0);
    final kind = _readBits(2);
    if (kind == 1) {
      final count = _readBits(2) + 1;
      final width = (alphabetSize - 1).bitLength;
      final symbols = _simpleSymbols;
      for (var i = 0; i < count; i++) {
        final symbol = _readBits(width);
        if (symbol >= alphabetSize) throw _invalid('prefix code symbol $symbol out of range');
        for (var j = 0; j < i; j++) {
          if (symbols[j] == symbol) throw _invalid('prefix code symbol $symbol repeated');
        }
        symbols[i] = symbol;
      }
      switch (count) {
        case 1:
          lengths[symbols[0]] = 1; // A single symbol takes no bits; see _buildTable.
        case 2:
          lengths[symbols[0]] = 1;
          lengths[symbols[1]] = 1;
        case 3:
          lengths[symbols[0]] = 1;
          lengths[symbols[1]] = 2;
          lengths[symbols[2]] = 2;
        default:
          final unbalanced = _readBits(1) == 1;
          lengths[symbols[0]] = unbalanced ? 1 : 2;
          lengths[symbols[1]] = 2;
          lengths[symbols[2]] = unbalanced ? 3 : 2;
          lengths[symbols[3]] = unbalanced ? 3 : 2;
      }
      return _buildTable(table, offset, _rootBits, lengths, alphabetSize);
    }

    // Complex code: first the code lengths of the code length alphabet.
    final codeLengthLengths = _codeLengthCodeLengths..fillRange(0, 18, 0);
    var space = 32;
    var codes = 0;
    for (var i = kind; i < 18; i++) {
      _fill();
      final peek = _bitBuffer & 15;
      final value = _codeLengthValue[peek];
      _bitBuffer >>= _codeLengthBits[peek];
      _bitCount -= _codeLengthBits[peek];
      codeLengthLengths[_codeLengthOrder[i]] = value;
      if (value != 0) {
        space -= 32 >> value;
        codes++;
        if (space <= 0) break;
      }
    }
    if (codes != 1 && space != 0) throw _invalid('invalid code length code');
    _buildTable(_codeLengthTable, 0, 5, codeLengthLengths, 18);

    // Then the code lengths of the symbols.
    var symbol = 0;
    var previous = 8;
    var repeat = 0;
    var repeatLength = 0;
    space = 32768;
    while (symbol < alphabetSize && space > 0) {
      _fill();
      final entry = _codeLengthTable[_bitBuffer & 31];
      _bitBuffer >>= entry >> 16;
      _bitCount -= entry >> 16;
      final code = entry & 0xffff;
      if (code < 16) {
        repeat = 0;
        if (code != 0) {
          lengths[symbol] = code;
          previous = code;
          space -= 32768 >> code;
        }
        symbol++;
        continue;
      }
      final extraBits = code == 16 ? 2 : 3;
      final length = code == 16 ? previous : 0;
      final delta = _readBits(extraBits);
      if (repeatLength != length) {
        repeat = 0;
        repeatLength = length;
      }
      final before = repeat;
      if (repeat > 0) repeat = (repeat - 2) << extraBits;
      repeat += delta + 3;
      final count = repeat - before;
      if (symbol + count > alphabetSize) throw _invalid('code lengths run past the alphabet');
      if (length != 0) {
        lengths.fillRange(symbol, symbol + count, length);
        space -= count << (_maxCodeLength - length);
      }
      symbol += count;
    }
    if (space != 0) throw _invalid('prefix code is incomplete or oversubscribed');
    return _buildTable(table, offset, _rootBits, lengths, alphabetSize);
  }

  /// Writes the lookup table of the canonical prefix code with [lengths] (0 for
  /// unused symbols) to [table] at [offset] and returns its size. The code must
  /// be complete or have a single symbol, which then takes no bits.
  ///
  /// Codes are read least significant bit first, so the table is indexed by
  /// bit-reversed codes. Entries are `bits << 16 | symbol`; a root entry whose
  /// bits exceed [rootBits] points to a second-level table instead: `total
  /// bits << 16 | distance from the entry to that table`.
  int _buildTable(Int32List table, int offset, int rootBits, Int32List lengths, int alphabetSize) {
    final count = _lengthCount..fillRange(0, _maxCodeLength + 1, 0);
    for (var symbol = 0; symbol < alphabetSize; symbol++) {
      count[lengths[symbol]]++;
    }
    final next = _lengthOffset..[1] = 0;
    for (var length = 1; length < _maxCodeLength; length++) {
      next[length + 1] = next[length] + count[length];
    }
    final sorted = _sortedSymbols;
    for (var symbol = 0; symbol < alphabetSize; symbol++) {
      final length = lengths[symbol];
      if (length != 0) sorted[next[length]++] = symbol;
    }

    var tableBits = rootBits;
    var tableSize = 1 << tableBits;
    var totalSize = tableSize;
    if (next[_maxCodeLength] == 1) {
      table.fillRange(offset, offset + totalSize, sorted[0]);
      return totalSize;
    }

    var key = 0;
    var symbol = 0;
    for (var length = 1, step = 2; length <= rootBits; length++, step <<= 1) {
      for (; count[length] > 0; count[length]--) {
        _replicate(table, offset + key, step, tableSize, length << 16 | sorted[symbol++]);
        key = _nextKey(key, length);
      }
    }
    final mask = totalSize - 1;
    var low = -1;
    var current = offset;
    for (var length = rootBits + 1, step = 2; length <= _maxCodeLength; length++, step <<= 1) {
      for (; count[length] > 0; count[length]--) {
        if ((key & mask) != low) {
          current += tableSize;
          tableBits = _secondLevelBits(count, length, rootBits);
          tableSize = 1 << tableBits;
          totalSize += tableSize;
          low = key & mask;
          table[offset + low] = (tableBits + rootBits) << 16 | (current - offset - low);
        }
        _replicate(table, current + (key >> rootBits), step, tableSize, (length - rootBits) << 16 | sorted[symbol++]);
        key = _nextKey(key, length);
      }
    }
    return totalSize;
  }

  /// The bit-reversed increment of the [length]-bit reversed code [key].
  static int _nextKey(int key, int length) {
    var step = 1 << (length - 1);
    while ((key & step) != 0) {
      step >>= 1;
    }
    return (key & (step - 1)) + step;
  }

  /// Stores [entry] at `table[index + end - step]`, `table[index + end - 2 *
  /// step]`, ... down to `table[index]`.
  static void _replicate(Int32List table, int index, int step, int end, int entry) {
    var at = end;
    do {
      at -= step;
      table[index + at] = entry;
    } while (at > 0);
  }

  /// Bits of the second-level table for the codes from [length] on.
  static int _secondLevelBits(Int32List count, int length, int rootBits) {
    var bits = length;
    var left = 1 << (bits - rootBits);
    while (bits < _maxCodeLength) {
      left -= count[bits];
      if (left <= 0) break;
      bits++;
      left <<= 1;
    }
    return bits - rootBits;
  }

  /// A standalone table for one code over [alphabetSize] symbols.
  Int32List _readStandaloneCode(int alphabetSize) {
    final table = Int32List(alphabetSize + _tableSlack);
    _readCode(alphabetSize, table, 0);
    return table;
  }

  /// [count] codes over [alphabetSize] symbols.
  _CodeGroup _readCodeGroup(int alphabetSize, int count) {
    final table = Int32List(count * (alphabetSize + _tableSlack));
    final offsets = Int32List(count);
    var next = 0;
    for (var i = 0; i < count; i++) {
      offsets[i] = next;
      next += _readCode(alphabetSize, table, next);
    }
    return _CodeGroup(table, offsets);
  }

  // Meta-block header.

  /// A count from 1 to 256 (NBLTYPES and NTREES, RFC 7932 section 9.2).
  int _readCount() {
    if (_readBits(1) == 0) return 1;
    final bits = _readBits(3);
    if (bits == 0) return 2;
    return (1 << bits) + _readBits(bits) + 1;
  }

  int _readBlockCount(Int32List code) {
    final symbol = _readSymbol(code, 0);
    return _blockCountBase[symbol] + _readBits(_blockCountBits[symbol]);
  }

  /// A context map of [size] entries for [trees] prefix codes (RFC 7932
  /// section 7.3).
  Uint8List _readContextMap(int size, int trees) {
    final map = Uint8List(size);
    if (trees < 2) return map;
    final runLengthCodes = _readBits(1) == 1 ? _readBits(4) + 1 : 0;
    final code = _readStandaloneCode(trees + runLengthCodes);
    var i = 0;
    while (i < size) {
      final symbol = _readSymbol(code, 0);
      if (symbol == 0) {
        i++;
      } else if (symbol > runLengthCodes) {
        map[i++] = symbol - runLengthCodes;
      } else {
        final zeros = (1 << symbol) + _readBits(symbol);
        if (i + zeros > size) throw _invalid('context map run past its end');
        i += zeros;
      }
    }
    if (_readBits(1) == 1) _inverseMoveToFront(map);
    return map;
  }

  static void _inverseMoveToFront(Uint8List values) {
    final table = Uint8List.fromList([for (var i = 0; i < 256; i++) i]);
    for (var i = 0; i < values.length; i++) {
      final index = values[i];
      final value = table[index];
      values[i] = value;
      if (index != 0) {
        table
          ..setRange(1, index + 1, table)
          ..[0] = value;
      }
    }
  }

  /// Reads a block switch command of [category] (RFC 7932 section 6).
  void _switchBlock(int category) {
    final types = _blockTypeCount[category];
    // With one block type the first count is 2^24, more than a meta-block can
    // use unless commands produce nothing (empty dictionary words).
    if (types < 2) throw _invalid('block count exhausted');
    var type = _readSymbol(_blockTypeCodes[category], 0);
    _blockLeft[category] = _readBlockCount(_blockCountCodes[category]);
    final ring = category * 2;
    if (type == 0) {
      type = _blockTypes[ring];
    } else if (type == 1) {
      type = _blockTypes[ring + 1] + 1;
    } else {
      type -= 2;
    }
    if (type >= types) type -= types;
    _blockTypes[ring] = _blockTypes[ring + 1];
    _blockTypes[ring + 1] = type;
  }

  // Meta-block data.

  void _decodeCompressed(int length) {
    for (var category = 0; category < 3; category++) {
      final types = _readCount();
      _blockTypeCount[category] = types;
      _blockTypes[category * 2] = 1;
      _blockTypes[category * 2 + 1] = 0;
      if (types < 2) {
        _blockLeft[category] = 1 << 24;
        continue;
      }
      _blockTypeCodes[category] = _readStandaloneCode(types + 2);
      _blockCountCodes[category] = _readStandaloneCode(26);
      _blockLeft[category] = _readBlockCount(_blockCountCodes[category]);
    }
    final postfixBits = _readBits(2);
    final directCodes = _readBits(4) << postfixBits;
    final postfixMask = (1 << postfixBits) - 1;
    final literalTypes = _blockTypeCount[_literals];
    final contextModes = Uint8List(literalTypes);
    for (var i = 0; i < literalTypes; i++) {
      contextModes[i] = _readBits(2);
    }
    // NTREES codes follow even if the context map does not use them all.
    final literalTrees = _readCount();
    final literalMap = _readContextMap(literalTypes << 6, literalTrees);
    final distanceTrees = _readCount();
    final distanceMap = _readContextMap(_blockTypeCount[_distances] << 2, distanceTrees);
    final literalGroup = _readCodeGroup(256, literalTrees);
    final commandGroup = _readCodeGroup(704, _blockTypeCount[_commands]);
    final distanceGroup = _readCodeGroup(16 + directCodes + (48 << postfixBits), distanceTrees);

    final output = _output;
    final lookup = brotliContextLookup;
    final dictionary = brotliDictionary;
    final literalTable = literalGroup.table;
    final literalOffsets = literalGroup.offsets;
    final commandTable = commandGroup.table;
    final distanceTable = distanceGroup.table;
    final distanceOffsets = distanceGroup.offsets;
    var literalMapStart = 0;
    var lookupStart = contextModes[0] << 9;
    var distanceMapStart = 0;
    var commandTree = commandGroup.offsets[0];
    var position = _outputLength;
    var remaining = length;

    while (remaining > 0) {
      if (_blockLeft[_commands] == 0) {
        _switchBlock(_commands);
        commandTree = commandGroup.offsets[_blockTypes[_commands * 2 + 1]];
      }
      _blockLeft[_commands]--;
      final command = _readSymbol(commandTable, commandTree);
      final insert = _commandInsert[command];
      final copy = _commandCopy[command];
      final insertLength = (insert >> 5) + _readBits(insert & 31);
      final copyLength = (copy >> 5) + _readBits(copy & 31);

      if (insertLength > remaining) throw _invalid('literals run past the meta-block');
      if (insertLength > 0) {
        var p1 = position > 0 ? output[position - 1] : 0;
        var p2 = position > 1 ? output[position - 2] : 0;
        for (var i = 0; i < insertLength; i++) {
          if (_blockLeft[_literals] == 0) {
            _switchBlock(_literals);
            final type = _blockTypes[_literals * 2 + 1];
            literalMapStart = type << 6;
            lookupStart = contextModes[type] << 9;
          }
          _blockLeft[_literals]--;
          final context = lookup[lookupStart + p1] | lookup[lookupStart + 256 + p2];
          final literal = _readSymbol(literalTable, literalOffsets[literalMap[literalMapStart + context]]);
          output[position++] = literal;
          p2 = p1;
          p1 = literal;
        }
        remaining -= insertLength;
        if (remaining == 0) break;
      }

      int distance;
      var remember = true;
      if (command < 128) {
        distance = _distanceRing[(_distanceIndex - 1) & 3];
        remember = false;
      } else {
        if (_blockLeft[_distances] == 0) {
          _switchBlock(_distances);
          distanceMapStart = _blockTypes[_distances * 2 + 1] << 2;
        }
        _blockLeft[_distances]--;
        final context = copyLength > 4 ? 3 : copyLength - 2;
        final code = _readSymbol(distanceTable, distanceOffsets[distanceMap[distanceMapStart + context]]);
        if (code < 16) {
          distance = _shortDistance(code);
          remember = code != 0;
        } else if (code < 16 + directCodes) {
          distance = code - 15;
        } else {
          final value = code - directCodes - 16;
          final extraBits = 1 + (value >> (postfixBits + 1));
          final base = ((2 + ((value >> postfixBits) & 1)) << extraBits) - 4;
          distance = ((base + _readBits(extraBits)) << postfixBits) + (value & postfixMask) + directCodes + 1;
        }
      }

      final maxDistance = position < _windowSize ? position : _windowSize;
      if (distance > maxDistance) {
        // A static dictionary word (RFC 7932 section 8); not remembered.
        if (copyLength < 4 || copyLength > 24) throw _invalid('dictionary word of length $copyLength');
        final bits = brotliDictionaryBits[copyLength];
        final wordId = distance - maxDistance - 1;
        final transform = wordId >> bits;
        if (transform >= brotliTransforms.length) throw _invalid('dictionary transform $transform');
        final produced = brotliTransformedLength(copyLength, transform);
        if (produced > remaining) throw _invalid('dictionary word runs past the meta-block');
        final word = brotliDictionaryOffsets[copyLength] + (wordId & (1 << bits) - 1) * copyLength;
        position = brotliTransformWord(output, position, dictionary, word, copyLength, transform);
        remaining -= produced;
        continue;
      }
      if (remember) {
        _distanceRing[_distanceIndex & 3] = distance;
        _distanceIndex++;
      }
      if (copyLength > remaining) throw _invalid('copy runs past the meta-block');
      final from = position - distance;
      if (distance >= copyLength) {
        if (copyLength <= 16) {
          for (var i = 0; i < copyLength; i++) {
            output[position + i] = output[from + i];
          }
        } else {
          output.setRange(position, position + copyLength, output, from);
        }
      } else if (distance == 1) {
        output.fillRange(position, position + copyLength, output[from]);
      } else {
        for (var i = 0; i < copyLength; i++) {
          output[position + i] = output[from + i];
        }
      }
      position += copyLength;
      remaining -= copyLength;
    }
    _outputLength = position;
  }

  /// Resolves distance symbols 0 to 15 against the last distances (RFC 7932
  /// section 4).
  int _shortDistance(int code) {
    final int distance;
    if (code < 4) {
      distance = _distanceRing[(_distanceIndex - 1 - code) & 3];
    } else if (code < 10) {
      final delta = (code - 4) >> 1;
      distance = _distanceRing[(_distanceIndex - 1) & 3] + (code.isEven ? -1 - delta : 1 + delta);
    } else {
      final delta = (code - 10) >> 1;
      distance = _distanceRing[(_distanceIndex - 2) & 3] + (code.isEven ? -1 - delta : 1 + delta);
    }
    if (distance <= 0) throw _invalid('distance $distance');
    return distance;
  }
}
