/// This file is a part of media_kit (https://github.com/media-kit/media-kit).
///
/// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
/// All rights reserved.
/// Use of this source code is governed by MIT license that can be found in the LICENSE file.

// A marker interface for accepting both [Media] and [Playlist] in [Player.open].

/// {@template playable}
///
/// Playable
/// --------
///
/// A playable item in [Player]. It can be [Media] or [Playlist].
///
/// {@endtemplate}
abstract class Playable {
  /// {@macro playable}
  const Playable();
}
