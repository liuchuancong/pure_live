/// This file is a part of media_kit (https://github.com/media-kit/media-kit).
///
/// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
/// All rights reserved.
/// Use of this source code is governed by MIT license that can be found in the LICENSE file.
import 'dart:ffi';
import 'dart:collection';

import 'package:media_kit/ffi/ffi.dart';

import 'package:media_kit/src/player/native/utils/isolates.dart';

/// {@template android_content_uri_provider}
///
/// AndroidContentUriProvider
/// -------------------------
///
/// This class is used to access content:// URIs on Android.
/// The implementation depends on the mediakitandroidhelper library.
///
/// Learn more: https://github.com/media-kit/media-kit-android-helper
///
/// {@endtemplate}
abstract class AndroidContentUriProvider {
  /// Returns the file descriptor of the content:// URI.
  static Future<int> openFileDescriptor(String uri) async {
    final lookup = _loaded[uri];
    if (lookup != null) {
      return lookup;
    }
    final fileDescriptor = await compute(_openFileDescriptor, uri);
    _loaded[uri] = fileDescriptor;
    return fileDescriptor;
  }

  /// Returns the file descriptor of the content:// URI.
  static int openFileDescriptorSync(String uri) {
    final lookup = _loaded[uri];
    if (lookup != null) {
      return lookup;
    }
    final fileDescriptor = _openFileDescriptor(uri);
    _loaded[uri] = fileDescriptor;
    return fileDescriptor;
  }

  /// Closes the file descriptor of the content:// URI.
  static Future<void> closeFileDescriptor(String uri) async {
    final lookup = _loaded[uri];
    if (lookup != null) {
      _loaded.remove(uri);
      await compute(_closeFileDescriptor, lookup);
    }
  }

  /// Closes the file descriptor of the content:// URI.
  static void closeFileDescriptorSync(String uri) {
    final lookup = _loaded[uri];
    if (lookup != null) {
      _loaded.remove(uri);
      _closeFileDescriptor(lookup);
    }
  }

  /// The native implementation for [openFileDescriptor] & [openFileDescriptorSync].
  static int _openFileDescriptor(String uri) {
    final lib = DynamicLibrary.open('libmediakitandroidhelper.so');
    final fn =
        lib.lookupFunction<OpenFileDescriptorCXX, OpenFileDescriptorDart>(
      'MediaKitAndroidHelperOpenFileDescriptor',
    );
    final name = uri.toNativeUtf8();
    final fileDescriptor = fn.call(name.cast());
    return fileDescriptor;
  }

  /// The native implementation for [closeFileDescriptor] & [closeFileDescriptorSync].
  static void _closeFileDescriptor(int fileDescriptor) {
    final lib = DynamicLibrary.open('libmediakitandroidhelper.so');
    final fn =
        lib.lookupFunction<CloseFileDescriptorCXX, CloseFileDescriptorDart>(
      'MediaKitAndroidHelperCloseFileDescriptor',
    );
    fn.call(fileDescriptor);
  }

  /// Stores the file descriptors of previously loaded content:// URIs. This avoids redundant FFI calls.
  static final HashMap<String, int> _loaded = HashMap<String, int>();
}

// Type definitions for native functions in the shared library.

// C/C++:

typedef OpenFileDescriptorCXX = Int32 Function(Pointer<Utf8> uri);
typedef CloseFileDescriptorCXX = Void Function(Int32 fileDescriptor);

// Dart:

typedef OpenFileDescriptorDart = int Function(Pointer<Utf8> uri);
typedef CloseFileDescriptorDart = void Function(int fileDescriptor);
