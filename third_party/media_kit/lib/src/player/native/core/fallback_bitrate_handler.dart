/// This file is a part of media_kit (https://github.com/media-kit/media-kit).
///
/// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
/// All rights reserved.
/// Use of this source code is governed by MIT license that can be found in the LICENSE file.
import 'dart:io';
import 'package:uri_parser/uri_parser.dart';
import 'package:safe_local_storage/safe_local_storage.dart';

abstract class FallbackBitrateHandler {
  static bool supported(String uri) => extractFilePath(uri) != null;

  static String? extractFilePath(String uri) {
    try {
      final parser = URIParser(uri);
      final formats = ['AAC', 'M4A', 'OGG', 'OPUS', 'FLAC'];
      if (parser.type == URIType.file &&
          formats.contains(parser.file!.extension)) {
        return parser.file!.path;
      }
    } catch (_) {}
    return null;
  }

  static Future<double> calculateBitrate(String uri, Duration duration) async {
    try {
      final filePath = extractFilePath(uri);
      if (filePath != null) {
        final file = File(filePath);
        final length = await file.length_();
        final result = length * 8 / duration.inSeconds;
        return result;
      }
    } catch (_) {}
    return 0;
  }
}
