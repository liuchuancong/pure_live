// Module: lib/src/models/media/media_protocol/media_protocol.dart
// Purpose: MediaProtocol, split out of the file that bundled it (see package-architecture.md
// §2.1): one public type per file, and the file in a folder of its own so anything generated for
// it lands beside it.
// Author: liuchuancong
// Created: 2026-10-11

/// How the resource is transported.
enum MediaProtocol { http, https, hls, dash, rtmp, rtsp, websocket, file, unknown }
