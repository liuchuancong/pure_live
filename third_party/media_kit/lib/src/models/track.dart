/// This file is a part of media_kit (https://github.com/media-kit/media-kit).
///
/// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
/// All rights reserved.
/// Use of this source code is governed by MIT license that can be found in the LICENSE file.
import 'package:collection/collection.dart';

/// {@template _track}
///
/// Track
/// -----
///
/// A video, audio or subtitle track available in [Media].
/// This may be selected for output in [Player].
///
/// {@endtemplate}
abstract class _Track {
  final String id;
  final String? title;
  final String? language;
  // ----------------------------------------
  final bool? image; /* image */
  final bool? albumart; /* albumart */
  final String? codec; /* codec */
  final String? decoder; /* decoder-desc */
  final int? w; /* demux-w */
  final int? h; /* demux-h */
  final int? channelscount; /* demux-channel-count */
  final String? channels; /* demux-channels */
  final int? samplerate; /* demux-samplerate */
  final double? fps; /* demux-fps */
  final int? bitrate; /* demux-bitrate */
  final int? rotate; /* demux-rotate */
  final double? par; /* demux-par */
  final int? audiochannels; /* audio-channels */
  // ----------------------------------------

  /// {@macro _track}
  const _Track(
    this.id,
    this.title,
    this.language, {
    this.image,
    this.albumart,
    this.codec,
    this.decoder,
    this.w,
    this.h,
    this.channelscount,
    this.channels,
    this.samplerate,
    this.fps,
    this.bitrate,
    this.rotate,
    this.par,
    this.audiochannels,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (this is VideoTrack && other is VideoTrack) return id == other.id;
    if (this is AudioTrack && other is AudioTrack) return id == other.id;
    if (this is SubtitleTrack && other is SubtitleTrack) return id == other.id;
    return false;
  }

  @override
  int get hashCode {
    if (this is VideoTrack) return 0x1 ^ id.hashCode;
    if (this is AudioTrack) return 0x2 ^ id.hashCode;
    if (this is SubtitleTrack) return 0x3 ^ id.hashCode;
    return 0x0;
  }

  @override
  String toString() => '$runtimeType('
      '$id, '
      '$title, '
      '$language, '
      'image: $image, '
      'albumart: $albumart, '
      'codec: $codec, '
      'decoder: $decoder, '
      'w: $w, '
      'h: $h, '
      'channelscount: $channelscount, '
      'channels: $channels, '
      'samplerate: $samplerate, '
      'fps: $fps, '
      'bitrate: $bitrate, '
      'rotate: $rotate, '
      'par: $par, '
      'audiochannels: $audiochannels'
      ')';
}

/// {@template video_track}
///
/// VideoTrack
/// ----------
///
/// A video available in [Media].
/// This may be selected for output in [Player].
/// {@endtemplate}
class VideoTrack extends _Track {
  /// {@macro video_track}
  const VideoTrack(
    super.id,
    super.title,
    super.language, {
    super.image,
    super.albumart,
    super.codec,
    super.decoder,
    super.w,
    super.h,
    super.channelscount,
    super.channels,
    super.samplerate,
    super.fps,
    super.bitrate,
    super.rotate,
    super.par,
    super.audiochannels,
  });

  /// No video track. Disables video output.
  factory VideoTrack.no() => VideoTrack('no', null, null);

  /// Default video track. Selects the first video track.
  factory VideoTrack.auto() => VideoTrack('auto', null, null);
}

/// {@template audio_track}
///
/// AudioTrack
/// ----------
///
/// An audio available in [Media].
/// This may be selected for output in [Player].
/// {@endtemplate}
class AudioTrack extends _Track {
  /// Whether the audio track is loaded from URI.
  final bool uri;

  /// {@macro audio_track}
  const AudioTrack(
    super.id,
    super.title,
    super.language, {
    super.image,
    super.albumart,
    super.codec,
    super.decoder,
    super.w,
    super.h,
    super.channelscount,
    super.channels,
    super.samplerate,
    super.fps,
    super.bitrate,
    super.rotate,
    super.par,
    super.audiochannels,
    this.uri = false,
  });

  /// No audio track. Disables audio output.
  factory AudioTrack.no() => AudioTrack('no', null, null);

  /// Default audio track. Selects the first audio track.
  factory AudioTrack.auto() => AudioTrack('auto', null, null);

  /// [AudioTrack] loaded with URI.
  ///
  /// This factory constructor may be used to load external audio as URI.
  ///
  /// **NOTE:** External audio track is automatically unloaded upon playback completion.
  factory AudioTrack.uri(
    String uri, {
    String? title,
    String? language,
  }) =>
      AudioTrack(
        uri,
        title,
        language,
        uri: true,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is AudioTrack) {
      return id == other.id && uri == other.uri;
    }
    return false;
  }

  @override
  int get hashCode => 0x3 ^ id.hashCode ^ uri.hashCode;
}

/// {@template subtitle_track}
///
/// SubtitleTrack
/// -------------
///
/// A subtitle available in [Media].
/// This may be selected for output in [Player].
/// {@endtemplate}
class SubtitleTrack extends _Track {
  /// Whether the subtitle track is loaded from URI.
  final bool uri;

  /// Whether the audio track is loaded from data.
  final bool data;

  /// {@macro subtitle_track}
  const SubtitleTrack(
    super.id,
    super.title,
    super.language, {
    super.image,
    super.albumart,
    super.codec,
    super.decoder,
    super.w,
    super.h,
    super.channelscount,
    super.channels,
    super.samplerate,
    super.fps,
    super.bitrate,
    super.rotate,
    super.par,
    super.audiochannels,
    this.uri = false,
    this.data = false,
  });

  /// No subtitle track. Disables subtitle output.
  factory SubtitleTrack.no() => SubtitleTrack('no', null, null);

  /// Default subtitle track. Selects the first subtitle track.
  factory SubtitleTrack.auto() => SubtitleTrack('auto', null, null);

  /// [SubtitleTrack] loaded with URI.
  ///
  /// This factory constructor may be used to load external subtitles e.g. SRT, WebVTT etc. as URI.
  ///
  /// **NOTE:** External audio track is automatically unloaded upon playback completion.
  factory SubtitleTrack.uri(
    String uri, {
    String? title,
    String? language,
  }) =>
      SubtitleTrack(uri, title, language, uri: true);

  /// [SubtitleTrack] loaded with data.
  ///
  /// This factory constructor may be used to load external subtitles e.g. SRT, WebVTT etc. as data.
  ///
  /// **NOTE:** External audio track is automatically unloaded upon playback completion.
  factory SubtitleTrack.data(
    String data, {
    String? title,
    String? language,
  }) =>
      SubtitleTrack(data, title, language, data: true);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is SubtitleTrack) {
      return id == other.id && uri == other.uri && data == other.data;
    }
    return false;
  }

  @override
  int get hashCode => 0x3 ^ id.hashCode ^ uri.hashCode ^ data.hashCode;
}

// For composition in [PlayerState] & [PlayerStreams] classes.

/// {@template track}
///
/// Track
/// -----
///
/// Currently selected tracks.
/// {@endtemplate}
class Track {
  /// Currently selected video track.
  final VideoTrack video;

  /// Currently selected audio track.
  final AudioTrack audio;

  /// Currently selected subtitle track.
  final SubtitleTrack subtitle;

  /// {@macro track}
  const Track({
    this.video = const VideoTrack('auto', null, null),
    this.audio = const AudioTrack('auto', null, null),
    this.subtitle = const SubtitleTrack('auto', null, null),
  });

  Track copyWith({
    VideoTrack? video,
    AudioTrack? audio,
    SubtitleTrack? subtitle,
  }) {
    return Track(
      video: video ?? this.video,
      audio: audio ?? this.audio,
      subtitle: subtitle ?? this.subtitle,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is Track) {
      return video == other.video &&
          audio == other.audio &&
          subtitle == other.subtitle;
    }
    return false;
  }

  @override
  int get hashCode => video.hashCode ^ audio.hashCode ^ subtitle.hashCode;

  @override
  String toString() =>
      'Track(video: $video, audio: $audio, subtitle: $subtitle)';
}

/// {@template tracks}
///
/// Tracks
/// ------
///
/// Currently available tracks.
/// {@endtemplate}
class Tracks {
  /// Currently available video tracks.
  final List<VideoTrack> video;

  /// Currently available audio tracks.
  final List<AudioTrack> audio;

  /// Currently available subtitle tracks.
  final List<SubtitleTrack> subtitle;

  /// {@macro tracks}
  const Tracks({
    this.video = const [
      VideoTrack('auto', null, null),
      VideoTrack('no', null, null),
    ],
    this.audio = const [
      AudioTrack('auto', null, null),
      AudioTrack('no', null, null),
    ],
    this.subtitle = const [
      SubtitleTrack('auto', null, null),
      SubtitleTrack('no', null, null),
    ],
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is Tracks) {
      return ListEquality().equals(video, other.video) &&
          ListEquality().equals(audio, other.audio) &&
          ListEquality().equals(subtitle, other.subtitle);
    }
    return false;
  }

  @override
  int get hashCode =>
      ListEquality().hash(video) ^
      ListEquality().hash(audio) ^
      ListEquality().hash(subtitle);

  @override
  String toString() =>
      'Tracks(video: $video, audio: $audio, subtitle: $subtitle)';
}
