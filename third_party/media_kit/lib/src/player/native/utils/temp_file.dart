/// This file is a part of media_kit (https://github.com/media-kit/media-kit).
///
/// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
/// All rights reserved.
/// Use of this source code is governed by MIT license that can be found in the LICENSE file.
import 'dart:io';
import 'package:path/path.dart';
import 'package:safe_local_storage/safe_local_storage.dart';
import 'package:uuid/uuid.dart';

import 'package:media_kit/src/player/native/utils/android_helper.dart';

/// {@template temp_file}
///
/// TempFile
/// --------
/// A simple class to create temporary files.
///
/// {@endtemplate}
abstract class TempFile {
  /// The directory used to create temporary files.
  static String get directory {
    String? result;
    if (Platform.isWindows) {
      result = Directory.systemTemp.path;
    } else if (Platform.isLinux) {
      result = Directory.systemTemp.path;
    } else if (Platform.isMacOS) {
      result = Directory.systemTemp.path;
    } else if (Platform.isIOS) {
      result = Directory.systemTemp.path;
    } else if (Platform.isAndroid) {
      result = AndroidHelper.filesDir;
    } else if (Platform.operatingSystem == 'ohos') {
      result = Directory.systemTemp.path;
    }
    if (result != null) {
      return result;
    }
    throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
  }

  /// Creates a temporary file & returns it.
  static Future<File> create() async {
    final file = File(join(directory, Uuid().v4()));
    await file.create_();
    return file;
  }
}
