import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Who is holding the app's sound. One owner per playing surface kind; the
/// kinds a viewer can legitimately run side by side (two live room windows)
/// share a kind, so they never silence each other.
enum AudioOwnerKind {
  /// A live room's stream (the room page's own player).
  live,

  /// A station replay (the archive player page).
  archive,

  /// A local file preview (recordings, downloads — the media preview page).
  preview,

  /// The music module's engine.
  music,

  /// An audiobook chapter (hongguo).
  audiobook,

  /// An IPTV channel (the IPTV play page).
  iptv,

  /// A VOD episode.
  vod,
}

/// One playing surface's hold on the sound.
@immutable
final class AudioOwner {
  /// A hold.
  const AudioOwner(this.kind, this.id);

  /// The surface's kind; equal kinds coexist.
  final AudioOwnerKind kind;

  /// The instance within the kind (a room's identity key, a file path).
  final String id;

  @override
  bool operator ==(Object other) => other is AudioOwner && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);
}

/// Who may make sound, and who to hush when someone new asks.
///
/// The app plays in several independent surfaces — a live room window, a
/// recording's preview, the music engine — and nothing stopped two of them
/// talking at once: a take opened from the recorder played over the live
/// stream the viewer had left running. Each surface claims the sound when it
/// starts playing, handing the arbiter its own pause verb; a claim from a
/// *different* kind pauses the holders it displaces. The same kind never
/// does: two live windows are watching, not competing.
///
/// The hushed surface is not resumed automatically — what paused it was the
/// viewer opening something else, and whether to go back to it is their
/// call. The room's own walk to a replay keeps its explicit resume, because
/// that walk answers for the whole round trip.
final class AudioArbiterController extends Notifier<Map<AudioOwner, Future<void> Function()>> {
  @override
  Map<AudioOwner, Future<void> Function()> build() => {};

  /// Claims the sound for [owner], hushing every holder of another kind.
  /// [pause] is the owner's own stop verb, kept for the next claim to use.
  ///
  /// The hush runs without waiting: a slow pause must not delay the new
  /// owner's start, and the engines' own stop is independent of the starter.
  Future<void> claim(AudioOwner owner, Future<void> Function() pause) async {
    final displaced = <(AudioOwner, Future<void> Function())>[
      for (final entry in state.entries)
        if (entry.key.kind != owner.kind) (entry.key, entry.value),
    ];
    if (displaced.isNotEmpty) {
      state = {
        for (final entry in state.entries)
          if (entry.key.kind == owner.kind) entry.key: entry.value,
      };
      for (final (displacedOwner, displacedPause) in displaced) {
        unawaited(_hush(displacedOwner, displacedPause));
      }
    }
    state = {...state, owner: pause};
  }

  /// Lets go of [owner]'s hold. A surface that stopped on its own (or was
  /// hushed, its claim already taken) simply leaves the table.
  void release(AudioOwner owner) {
    if (!state.containsKey(owner)) return;
    state = {
      for (final entry in state.entries)
        if (entry.key != owner) entry.key: entry.value,
    };
  }

  /// The kind that holds the sound now, if any.
  AudioOwnerKind? get holdingKind => state.keys.isEmpty ? null : state.keys.first.kind;

  Future<void> _hush(AudioOwner owner, Future<void> Function() pause) async {
    try {
      await pause();
    } on Object {
      // A holder already being torn down refuses; its release call is on
      // its way and settles the table.
    }
  }
}

/// The app's sound table: who is playing, and how to hush them.
final audioArbiterProvider = NotifierProvider<AudioArbiterController, Map<AudioOwner, Future<void> Function()>>(
  AudioArbiterController.new,
);
