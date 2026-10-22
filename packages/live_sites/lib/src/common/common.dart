/// The shared primitives every platform adapter builds on:
/// codecs, crypto, HLS parsing, normalization and the danmaku socket.
library;

export 'codec/brotli.dart';
export 'crypto/aes_cbc.dart';
export 'hls/hls_master.dart';
export 'normalization/html_entities.dart';
export 'normalization/site_counts.dart';
export 'normalization/site_urls.dart';
export 'websocket/danmaku_socket.dart';
