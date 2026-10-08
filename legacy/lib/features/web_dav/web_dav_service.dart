import 'dart:typed_data';

import 'package:webdav_client/webdav_client.dart' as webdav;

class WebDAVService {
  final String url;
  final String username;
  final String password;

  late final webdav.Client _client;

  webdav.Client get client => _client;

  WebDAVService({required this.url, required this.username, required this.password}) {
    // Protocol debug logs include request headers and response bodies, which
    // can contain authentication and backup data.
    _client = webdav.newClient(url.trim(), user: username, password: password, debug: false);
  }

  // readDir validates the HTTP response and parses XML. A collection without
  // children is a successful empty list, not a transport or parsing failure.
  Future<List<webdav.File>> readDirectory(String path) => _client.readDir(path);

  Future<List<int>> readFile(String path) => _client.read(path);

  Future<void> writeFile(String path, Uint8List bytes) => _client.write(path, bytes);

  Future<void> removeFile(String path) => _client.remove(path);

  void close() => _client.c.close(force: true);
}
