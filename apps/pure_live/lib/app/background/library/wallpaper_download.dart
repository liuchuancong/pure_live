import 'dart:io' show File, FileSystemException;

import 'package:live_net/live_net.dart' show LiveHttp, LiveRequest;
import 'package:path/path.dart' as p;

/// Streams [url] into [directory] as [fileName] and returns the saved file.
///
/// The bytes land in a `.part` beside the target and are renamed only once the
/// whole answer arrived, so a broken transfer never looks like a usable file.
Future<File> downloadMediaFile({
  required LiveHttp http,
  required Uri url,
  required String directory,
  required String fileName,
  Duration timeout = const Duration(minutes: 10),
}) async {
  final target = File(p.join(directory, fileName));
  final part = File('${target.path}.part');
  try {
    await target.parent.create(recursive: true);
    final response = await http.open(LiveRequest.get(url, timeout: timeout));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      await response.close();
      throw FileSystemException('HTTP ${response.statusCode}', url.toString());
    }
    final sink = part.openWrite();
    try {
      await response.stream.forEach(sink.add);
    } finally {
      await sink.close();
    }
    if (target.existsSync()) await target.delete();
    await part.rename(target.path);
    return target;
  } on Object {
    try {
      if (part.existsSync()) await part.delete();
    } on Object {
      // A leftover `.part` is invisible to the UI and harmless.
    }
    rethrow;
  }
}

/// The name an entry lands under: its own title plus whatever extension its
/// address carries, so the file system opens it by double click.
String wallpaperFileName({required String title, required String fallback, required String address}) {
  final extension = p.extension(Uri.tryParse(address)?.path ?? '').replaceFirst('.', '').toLowerCase();
  final cleaned = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  final base = cleaned.isEmpty ? fallback : cleaned;
  if (extension.isEmpty || base.toLowerCase().endsWith('.$extension')) return base;
  return '$base.$extension';
}
