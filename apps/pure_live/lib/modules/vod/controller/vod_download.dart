import 'dart:async' show Future;
import 'dart:io' show Directory, File, HttpClient, HttpException;

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart' show getApplicationDocumentsDirectory, getApplicationSupportDirectory;

/// How a download ended, or that it is still going.
enum VodDownloadStatus { running, done, failed, cancelled }

/// The folder this app keeps downloaded pictures in:
/// `Documents/PureLive/Videos`, falling back to the app-support folder when
/// the documents folder is not there (a stripped mobile platform).
Future<Directory> vodDownloadFolder() async {
  Directory base;
  try {
    base = await getApplicationDocumentsDirectory();
  } on Object {
    base = await getApplicationSupportDirectory();
  }
  final folder = Directory(p.join(base.path, 'PureLive', 'Videos'));
  await folder.create(recursive: true);
  return folder;
}

/// The file a download writes: the archive's name, the part's name when it
/// has more than one, and the container the source served.
String vodDownloadFileName({
  required String title,
  required String part,
  int index = 1,
  int parts = 1,
  String extension = 'mp4',
}) {
  final raw = parts > 1 ? '$title - P$index $part' : title;
  final clean = raw.replaceAll(RegExp(r'[\\/:*?"<>|\r\n\t]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  final name = clean.isEmpty ? 'bilibili_$index' : clean;
  return '$name.$extension';
}

/// A file named [name] in [folder] that does not exist yet, adding `_2`,
/// `_3` … when the name is taken.
File freeDownloadFile(Directory folder, String name) {
  final base = p.basenameWithoutExtension(name);
  final extension = p.extension(name);
  var file = File(p.join(folder.path, name));
  for (var index = 2; file.existsSync(); index++) {
    file = File(p.join(folder.path, '${base}_$index$extension'));
  }
  return file;
}

/// One file being fetched off a CDN into the viewer's Videos folder.
///
/// The address is signed and short-lived, so the page resolves it right
/// before the task starts. The bytes land in a `.part` file beside the
/// target and the finished file is renamed into place, so a cancelled or
/// failed download leaves nothing half-written behind.
final class VodDownloadTask extends ChangeNotifier {
  /// A task for [url], written as [fileName] under the app's Videos folder.
  VodDownloadTask({required this.url, required this.headers, required this.fileName});

  /// The signed CDN address.
  final String url;

  /// What the CDN checks: the referer, the browser string, the sign-in.
  final Map<String, String> headers;

  /// The name the finished file takes.
  final String fileName;

  VodDownloadStatus _status = VodDownloadStatus.running;
  int _received = 0;
  int _total = 0;
  int _lastNotify = 0;
  File? _file;
  String? _error;
  HttpClient? _client;
  bool _cancelled = false;

  /// Where the download stands.
  VodDownloadStatus get status => _status;

  /// Bytes written so far.
  int get received => _received;

  /// The answer's length, when it named one.
  int get total => _total;

  /// The finished file; null until [status] is done.
  File? get file => _file;

  /// What went wrong, when it did.
  String? get error => _error;

  /// The answered fraction, when the response named its length.
  double? get progress => _total > 0 ? (_received / _total).clamp(0.0, 1.0) : null;

  /// Runs the download to its end; answers when it stops for any reason.
  Future<void> start() async {
    File? scratch;
    try {
      final target = freeDownloadFile(await vodDownloadFolder(), fileName);
      scratch = File('${target.path}.part');
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
      _client = client;
      final request = await client.getUrl(Uri.parse(url));
      for (final entry in headers.entries) {
        request.headers.set(entry.key, entry.value);
      }
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('HTTP ${response.statusCode}');
      }
      _total = response.contentLength;
      final sink = scratch.openWrite();
      try {
        await for (final chunk in response) {
          if (_cancelled) break;
          _received += chunk.length;
          sink.add(chunk);
          _notifyThrottled();
        }
      } finally {
        await sink.flush();
        await sink.close();
      }
      if (_cancelled) {
        await _delete(scratch);
        _status = VodDownloadStatus.cancelled;
        return;
      }
      _file = await scratch.rename(target.path);
      _status = VodDownloadStatus.done;
    } on Object catch (error) {
      _error = '$error';
      _status = _cancelled ? VodDownloadStatus.cancelled : VodDownloadStatus.failed;
      if (scratch != null) await _delete(scratch);
    } finally {
      _client?.close(force: true);
      _client = null;
      notifyListeners();
    }
  }

  /// Stops the download and drops the part file.
  void cancel() {
    if (_status != VodDownloadStatus.running) return;
    _cancelled = true;
    _client?.close(force: true);
  }

  void _notifyThrottled() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastNotify < 200) return;
    _lastNotify = now;
    notifyListeners();
  }

  static Future<void> _delete(File file) async {
    try {
      if (file.existsSync()) await file.delete();
    } on Object {
      // A part file the system still holds is left for the cleaner.
    }
  }
}
