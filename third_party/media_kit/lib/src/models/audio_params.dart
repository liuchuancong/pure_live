/// This file is a part of media_kit (https://github.com/media-kit/media-kit).
///
/// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
/// All rights reserved.
/// Use of this source code is governed by MIT license that can be found in the LICENSE file.

/// {@template audio_params}
///
/// AudioParams
/// -----------
///
/// Audio format as output by the audio decoder.
///
/// {@endtemplate}
class AudioParams {
  /// The sample format as string. This uses the same names as used in other places of mpv.
  final String? format;

  /// Sample rate.
  final int? sampleRate;

  /// The channel layout as a string. This is similar to what the --audio-channels accepts.
  final String? channels;

  /// Number of audio channels.
  final int? channelCount;

  /// As channels, but instead of the possibly cryptic actual layout sent to the audio device, return a hopefully more human readable form.
  /// Usually only audio-out-params/hr-channels makes sense.
  final String? hrChannels;

  /// {@macro audio_params}
  const AudioParams({
    this.format,
    this.sampleRate,
    this.channels,
    this.channelCount,
    this.hrChannels,
  });

  @override
  operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AudioParams &&
        other.format == format &&
        other.sampleRate == sampleRate &&
        other.channels == channels &&
        other.channelCount == channelCount &&
        other.hrChannels == hrChannels;
  }

  @override
  int get hashCode =>
      format.hashCode ^
      sampleRate.hashCode ^
      channels.hashCode ^
      channelCount.hashCode ^
      hrChannels.hashCode;

  @override
  String toString() => 'AudioParams('
      'format: $format, '
      'sampleRate: $sampleRate, '
      'channels: $channels, '
      'channelCount: $channelCount, '
      'hrChannels: $hrChannels'
      ')';
}
