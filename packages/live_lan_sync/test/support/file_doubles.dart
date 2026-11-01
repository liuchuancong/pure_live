import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:io' show Directory, File;

import 'package:crypto/crypto.dart' as crypto show sha256;
import 'package:live_lan_sync/live_lan_sync.dart';

/// A file category kept in a temporary directory: `outbox/<fileId>` holds
/// files to send, `inbox/<fileId>` receives them, `staging/` stages them.
class DirectoryFileAdapter implements LanSyncFileAdapter {
  new(this.root, {this.category = 'font', this.maxFileBytes = 64 * 1024 * 1024});

  final Directory root;

  @override
  final String category;

  @override
  final int maxFileBytes;

  /// When set, [validate] refuses every file with this reason.
  String? rejectReason;

  /// Every file committed, in order.
  final List<File> committedFiles = <File>[];

  Directory get outbox => Directory('${root.path}/outbox');

  Directory get inbox => Directory('${root.path}/inbox');

  Directory get staging => Directory('${root.path}/staging');

  /// Puts [bytes] in the outbox as [fileId].
  File offer(String fileId, List<int> bytes) {
    outbox.createSync(recursive: true);
    return File('${outbox.path}/$fileId')..writeAsBytesSync(bytes);
  }

  File received(String fileId) => File('${inbox.path}/$fileId');

  @override
  Future<LocalFile?> localFile(String fileId) async {
    final file = File('${outbox.path}/$fileId');
    return file.existsSync() ? LocalFile(file: file, fileName: '$fileId.ttf', mimeType: 'font/ttf') : null;
  }

  @override
  Future<bool> hasContent({required String fileId, required String sha256}) async {
    final file = received(fileId);
    return file.existsSync() && crypto.sha256.convert(file.readAsBytesSync()).toString() == sha256;
  }

  @override
  Future<Directory> stagingDirectory() async => staging;

  @override
  Future<String?> validate(FileManifest manifest, File staged) async => rejectReason;

  @override
  Future<File> targetFor(FileManifest manifest) async => received(manifest.fileId);

  @override
  Future<void> committed(FileManifest manifest, File file) async => committedFiles.add(file);
}

/// A [PeerFileChannel] calling a [FileReceiver]'s handlers in-process, with
/// a JSON round trip for every JSON body. Counts calls per route
/// (`init`, `chunk`, `status`, `cancel`) and can fail or corrupt them.
final class LoopbackFileChannel implements PeerFileChannel {
  new({required this.receiver, required this.callerId, required this.peerDeviceId});

  /// The receiving device's handlers.
  final FileReceiver receiver;

  /// The sending device, as the server would have authenticated it.
  final String callerId;

  @override
  final String peerDeviceId;

  /// Calls so far, per route.
  final Map<String, int> calls = <String, int>{};

  /// Called before each request with its route and 1-based count; throwing
  /// fails that request.
  void Function(String route, int number)? beforeCall;

  /// Rewrites chunk bytes on the way, as a damaged link would.
  List<int> Function(int index, List<int> bytes)? tamper;

  @override
  Future<Map<String, Object?>> init(Map<String, Object?> body) async {
    _count('init');
    return _wire(await receiver.handleInit(_request('files/init', body: _wire(body))));
  }

  @override
  Future<Map<String, Object?>> putChunk(String transferId, int index, List<int> bytes) async {
    _count('chunk');
    return _wire(
      await receiver.handleChunk(
        _request(
          'files/$transferId/chunks/$index',
          bytes: tamper?.call(index, bytes) ?? bytes,
          parameters: {'transferId': transferId, 'index': '$index'},
        ),
      ),
    );
  }

  @override
  Future<Map<String, Object?>> status(String transferId) async {
    _count('status');
    return _wire(
      await receiver.handleStatus(_request('files/$transferId/status', parameters: {'transferId': transferId})),
    );
  }

  @override
  Future<Map<String, Object?>> cancel(String transferId) async {
    _count('cancel');
    return _wire(await receiver.handleCancel(_request('files/$transferId', parameters: {'transferId': transferId})));
  }

  void _count(String route) {
    final number = calls[route] = (calls[route] ?? 0) + 1;
    beforeCall?.call(route, number);
  }

  PeerRequest _request(
    String path, {
    Map<String, Object?> body = const <String, Object?>{},
    List<int> bytes = const <int>[],
    Map<String, String> parameters = const <String, String>{},
  }) => PeerRequest(
    senderDeviceId: callerId,
    path: '/sync/v1/$path',
    body: body,
    bytes: bytes,
    pathParameters: parameters,
  );

  static Map<String, Object?> _wire(Map<String, Object?> json) =>
      (jsonDecode(jsonEncode(json)) as Map<Object?, Object?>).cast<String, Object?>();
}

/// Deterministic test content of [length] bytes.
List<int> testBytes(int length, {int seed = 7}) => List<int>.generate(length, (i) => (i * 31 + seed) % 256);
