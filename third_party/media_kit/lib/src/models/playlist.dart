/// This file is a part of media_kit (https://github.com/media-kit/media-kit).
///
/// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
/// All rights reserved.
/// Use of this source code is governed by MIT license that can be found in the LICENSE file.

import 'package:collection/collection.dart';
import 'package:media_kit/src/models/playable.dart';
import 'package:media_kit/src/models/media/media.dart';

/// {@template playlist}
///
/// Playlist
/// --------
///
/// A [Playlist] represents a list of [Media]s & currently playing [index].
/// This may be opened in [Player] for playback.
///
/// ```dart
/// final playable = Playlist(
///   [
///     Media('https://user-images.githubusercontent.com/28951144/229373695-22f88f13-d18f-4288-9bf1-c3e078d83722.mp4'),
///     Media('https://user-images.githubusercontent.com/28951144/229373709-603a7a89-2105-4e1b-a5a5-a6c3567c9a59.mp4'),
///     Media('https://user-images.githubusercontent.com/28951144/229373716-76da0a4e-225a-44e4-9ee7-3e9006dbc3e3.mp4'),
///     Media('https://user-images.githubusercontent.com/28951144/229373718-86ce5e1d-d195-45d5-baa6-ef94041d0b90.mp4'),
///     Media('https://user-images.githubusercontent.com/28951144/229373720-14d69157-1a56-4a78-a2f4-d7a134d7c3e9.mp4'),
///   ],
/// );
/// ```
///
/// {@endtemplate}
class Playlist extends Playable {
  /// Currently opened [List] of [Media]s.
  final List<Media> medias;

  /// Currently playing [index].
  final int index;

  /// {@macro playlist}
  const Playlist(
    this.medias, {
    this.index = 0,
  });

  Playlist copyWith({
    List<Media>? medias,
    int? index,
  }) {
    return Playlist(
      medias ?? this.medias,
      index: index ?? this.index,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Playlist &&
          ListEquality().equals(medias, other.medias) &&
          index == other.index;

  @override
  int get hashCode => ListEquality().hash(medias) ^ index.hashCode;

  @override
  String toString() => 'Playlist(medias: $medias, index: $index)';
}
