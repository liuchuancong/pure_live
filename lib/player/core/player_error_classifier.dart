import '../models/player_error_type.dart';

enum NativeDiagnosticComponent { video, audio, either }

/// A semantic interpretation of one native-player diagnostic line.
///
/// media_kit forwards selected mpv log lines through `Player.stream.error`.
/// Those lines are not all terminal playback failures: hardware decoders may
/// reject one profile before mpv falls back, and a corrupt live packet may be
/// followed by a valid keyframe. [immediatelyTerminal] is therefore reserved
/// for errors which cannot recover without changing source or player state.
class NativePlayerErrorClassification {
  const NativePlayerErrorClassification({
    required this.type,
    required this.code,
    required this.immediatelyTerminal,
    this.component = NativeDiagnosticComponent.either,
  });

  final PlayerErrorType type;
  final String code;
  final bool immediatelyTerminal;
  final NativeDiagnosticComponent component;
}

class PlayerErrorClassifier {
  const PlayerErrorClassifier._();

  static NativePlayerErrorClassification classify(String message, {String? nativePrefix}) {
    final value = message.trim().toLowerCase();
    final prefix = nativePrefix?.trim().toLowerCase();
    final decoderComponent = prefix == 'ad' || prefix == 'ffmpeg/audio'
        ? NativeDiagnosticComponent.audio
        : prefix == 'vd' || prefix == 'ffmpeg/video'
        ? NativeDiagnosticComponent.video
        : NativeDiagnosticComponent.either;

    if (_containsAny(value, const <String>[
      'player has been disposed',
      'player has been released',
      'operation was cancelled',
      'operation was canceled',
    ])) {
      return const NativePlayerErrorClassification(
        type: PlayerErrorType.lifecycle,
        code: 'lifecycle',
        immediatelyTerminal: true,
      );
    }

    if (_containsAny(value, const <String>[
      'surface has been released',
      'failed to create surface',
      'failed to create texture',
      'texture is unavailable',
      'egl_bad',
      'vulkan error',
      'gpu context failed',
    ])) {
      return const NativePlayerErrorClassification(
        type: PlayerErrorType.texture,
        code: 'video_output',
        immediatelyTerminal: true,
      ).withComponent(decoderComponent);
    }

    if (_containsAny(value, const <String>[
      'no decoder found',
      'unsupported codec',
      'codec is not supported',
    ])) {
      return const NativePlayerErrorClassification(
        type: PlayerErrorType.codec,
        code: 'decoder_init',
        immediatelyTerminal: true,
      ).withComponent(decoderComponent);
    }

    if (_containsAny(value, const <String>[
      'mediacodec',
      'decoder',
      'decode',
      'codec',
      'invalid nal',
      'non-existing pps',
      'missing reference picture',
      'corrupt decoded frame',
      'error while decoding',
    ])) {
      return const NativePlayerErrorClassification(
        type: PlayerErrorType.codec,
        code: 'decoder_runtime',
        immediatelyTerminal: false,
      ).withComponent(decoderComponent);
    }

    if (_containsAny(value, const <String>[
      'server returned 401',
      'server returned 403',
      'server returned 404',
      'http error 401',
      'http error 403',
      'http error 404',
      'protocol not found',
      'unknown protocol',
      'no protocol handler',
      'failed to open input',
      'error opening input',
      'unable to open input',
      'invalid data found when processing input',
      'could not find codec parameters',
      'no streams found',
    ])) {
      return const NativePlayerErrorClassification(
        type: PlayerErrorType.source,
        code: 'source_open',
        immediatelyTerminal: true,
      );
    }

    if (_containsAny(value, const <String>[
      'connection timed out',
      'network timeout',
      'network is unreachable',
      'host is unreachable',
      'connection refused',
      'connection reset',
      'failed to resolve',
      'temporary failure in name resolution',
      'name or service not known',
      'tls handshake',
      'ssl handshake',
      'certificate verify failed',
      'input/output error',
      'i/o error',
    ])) {
      return const NativePlayerErrorClassification(
        type: PlayerErrorType.network,
        code: 'transport',
        immediatelyTerminal: true,
      );
    }

    if (_containsAny(value, const <String>[
      'demuxer',
      'failed to open',
      'error opening',
      'unable to open',
      'end of file',
      'unexpected eof',
    ])) {
      return const NativePlayerErrorClassification(
        type: PlayerErrorType.source,
        code: 'source_runtime',
        immediatelyTerminal: false,
      );
    }

    return const NativePlayerErrorClassification(
      type: PlayerErrorType.native,
      code: 'native_diagnostic',
      immediatelyTerminal: false,
    );
  }

  static bool _containsAny(String value, List<String> markers) => markers.any(value.contains);
}

extension on NativePlayerErrorClassification {
  NativePlayerErrorClassification withComponent(NativeDiagnosticComponent value) {
    return NativePlayerErrorClassification(
      type: type,
      code: value == NativeDiagnosticComponent.audio
          ? 'audio_$code'
          : value == NativeDiagnosticComponent.video
          ? 'video_$code'
          : code,
      immediatelyTerminal: immediatelyTerminal,
      component: value,
    );
  }
}
