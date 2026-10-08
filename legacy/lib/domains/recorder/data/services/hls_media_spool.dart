import 'dart:io';
import 'dart:typed_data';

/// A response is published only after its complete body has been received.
/// Small HLS fragments stay in memory; larger ones spill to one owned temp file.
class HlsMediaSpool {
  HlsMediaSpool({
    required this.createDirectory,
    this.memoryLimit = 2 * 1024 * 1024,
    this.byteLimit = 128 * 1024 * 1024,
    this.reusable = false,
  });

  final Future<Directory> Function() createDirectory;
  final int memoryLimit;
  final int byteLimit;
  final bool reusable;
  final BytesBuilder _memory = BytesBuilder();
  Directory? _directory;
  File? _file;
  RandomAccessFile? _writer;
  int _length = 0;
  bool _sealed = false;
  bool _disposed = false;

  int get length => _length;
  int get memoryBytes => _memory.length;
  bool get spilled => _file != null;

  Future<void> add(List<int> bytes) async {
    if (_sealed || _disposed) throw StateError('HLS body is no longer writable');
    if (_length + bytes.length > byteLimit) throw const FormatException('HLS resource exceeds staging limit');
    if (_writer == null && _length + bytes.length > memoryLimit) {
      _directory = await createDirectory();
      _file = File('${_directory!.path}${Platform.pathSeparator}body.bin');
      _writer = await _file!.open(mode: FileMode.writeOnly);
      await _writer!.writeFrom(_memory.takeBytes());
    }
    if (_writer != null) {
      await _writer!.writeFrom(bytes);
    } else {
      _memory.add(bytes);
    }
    _length += bytes.length;
  }

  Future<void> seal({required int expectedLength}) async {
    if (_disposed || _sealed) throw StateError('HLS body seal called outside receiving state');
    if (expectedLength >= 0 && expectedLength != _length) {
      throw const HttpException('HLS response length did not match its complete body');
    }
    await _writer?.close();
    _writer = null;
    _sealed = true;
  }

  Stream<List<int>> read() {
    if (!_sealed || _disposed) throw StateError('Only a complete HLS body may be published');
    return _file?.openRead() ?? Stream<List<int>>.value(reusable ? _memory.toBytes() : _memory.takeBytes());
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _memory.clear();
    try {
      await _writer?.close();
    } finally {
      _writer = null;
      try {
        if (_file != null && await _file!.exists()) await _file!.delete();
      } finally {
        // Never recursively remove a computed parent or any unrelated content.
        if (_directory != null && await _directory!.exists()) await _directory!.delete();
      }
    }
  }
}
