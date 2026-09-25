/// This file is a part of media_kit (https://github.com/media-kit/media-kit).
///
/// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
/// All rights reserved.
/// Use of this source code is governed by MIT license that can be found in the LICENSE file.
// ignore_for_file: camel_case_types
import 'package:media_kit/src/player/native/player/player.dart';
import 'package:media_kit/src/player/web/player/player.dart';

// ----------------------------------------
// BACKWARD COMPATIBILITY
// ----------------------------------------

@Deprecated('Use [NativePlayer] instead')
typedef libmpvPlayer = NativePlayer;

@Deprecated('Use [WebPlayer] instead')
typedef webPlayer = WebPlayer;
