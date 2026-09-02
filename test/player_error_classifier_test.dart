import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/player/core/player_error_classifier.dart';
import 'package:pure_live/player/core/source_event_fence.dart';
import 'package:pure_live/player/models/player_error_type.dart';

void main() {
  group('PlayerErrorClassifier', () {
    test('does not classify the letters io inside video/audio as network', () {
      final result = PlayerErrorClassifier.classify('Video decoder rejected this audio/video codec');

      expect(result.type, PlayerErrorType.codec);
      expect(result.immediatelyTerminal, isFalse);
    });

    test('lets hardware initialization recover but fails an unsupported codec', () {
      final hardwareFallback = PlayerErrorClassifier.classify('MediaCodec decoder initialization failed');
      final terminal = PlayerErrorClassifier.classify('No decoder found for codec av1');
      final packet = PlayerErrorClassifier.classify('Error while decoding frame: invalid NAL unit');

      expect(hardwareFallback.type, PlayerErrorType.codec);
      expect(hardwareFallback.immediatelyTerminal, isFalse);
      expect(terminal.type, PlayerErrorType.codec);
      expect(terminal.immediatelyTerminal, isTrue);
      expect(packet.type, PlayerErrorType.codec);
      expect(packet.immediatelyTerminal, isFalse);
    });

    test('uses concrete transport and source markers', () {
      expect(PlayerErrorClassifier.classify('Input/output error').type, PlayerErrorType.network);
      expect(PlayerErrorClassifier.classify('Server returned 403 Forbidden').type, PlayerErrorType.source);
      expect(PlayerErrorClassifier.classify('Error opening input').type, PlayerErrorType.source);
    });

    test('keeps audio and video decoder diagnostics in separate recovery lanes', () {
      final audio = PlayerErrorClassifier.classify('Decoder initialization failed', nativePrefix: 'ad');
      final video = PlayerErrorClassifier.classify(
        'Error while decoding frame: invalid NAL unit',
        nativePrefix: 'ffmpeg/video',
      );

      expect(audio.component, NativeDiagnosticComponent.audio);
      expect(audio.code, 'audio_decoder_runtime');
      expect(video.component, NativeDiagnosticComponent.video);
      expect(video.code, 'video_decoder_runtime');
    });
  });

  group('SourceEventFence', () {
    test('accepts events after replacement open completes', () {
      final fence = SourceEventFence();
      final generation = fence.begin('https://cdn.example/live.flv?token=new');

      fence.observeNativeSources(const <String>['https://cdn.example/old.flv']);
      expect(fence.isCurrentGeneration(generation), isFalse);
      expect(fence.accepts(generation), isFalse);

      fence.finishOpen(const <String>['https://cdn.example/live.flv?token=new'], authorizeSuccessfulOpen: true);
      expect(fence.isCurrentGeneration(generation), isTrue);
      expect(fence.accepts(generation), isTrue);

      fence.observeNativeSources(const <String>[]);
      expect(fence.accepts(generation), isTrue);
    });

    test('a finished open remains usable when no native path event arrives', () {
      final fence = SourceEventFence();
      final generation = fence.begin('https://cdn.example/live.flv');

      fence.finishOpen(const <String>[], authorizeSuccessfulOpen: true);

      expect(fence.isCurrentGeneration(generation), isTrue);
      expect(fence.accepts(generation), isTrue);
      expect(fence.isNativeSourceConfirmed, isFalse);
    });

    test('redirected native path is diagnostic only and does not block playback', () {
      final fence = SourceEventFence();
      final generation = fence.begin('https://api.example/live.flv?token=request');

      fence.finishOpen(const <String>['https://edge.example/live.flv?token=redirected'], authorizeSuccessfulOpen: true);

      expect(fence.isNativeSourceConfirmed, isFalse);
      expect(fence.accepts(generation), isTrue);
    });

    test('a later source generation invalidates every earlier callback', () {
      final fence = SourceEventFence();
      final oldGeneration = fence.begin('https://cdn.example/old.flv');
      fence.finishOpen(const <String>['https://cdn.example/old.flv'], authorizeSuccessfulOpen: true);
      expect(fence.accepts(oldGeneration), isTrue);

      final newGeneration = fence.begin('https://cdn.example/new.flv');
      fence.finishOpen(const <String>['https://cdn.example/new.flv'], authorizeSuccessfulOpen: true);

      expect(fence.accepts(oldGeneration), isFalse);
      expect(fence.accepts(newGeneration), isTrue);
    });

    test('an unsuccessful open never authorizes callbacks', () {
      final fence = SourceEventFence();
      final generation = fence.begin('https://cdn.example/failing.flv');

      fence.finishOpen(const <String>[], authorizeSuccessfulOpen: false);

      expect(fence.isOpenAuthorized, isFalse);
      expect(fence.isCurrentGeneration(generation), isFalse);
      expect(fence.accepts(generation), isFalse);
    });

    test('manager preparation and final URL keep one generation', () {
      final fence = SourceEventFence();
      final generation = fence.begin(null);

      fence.retargetOpening('https://cdn.example/final.flv');
      fence.finishOpen(const <String>['https://cdn.example/final.flv'], authorizeSuccessfulOpen: true);

      expect(fence.generation, generation);
      expect(fence.isNativeSourceConfirmed, isTrue);
      expect(fence.accepts(generation), isTrue);
    });

    test('reopening the same URL still invalidates the old callback lease', () {
      final fence = SourceEventFence();
      final oldGeneration = fence.begin('https://cdn.example/live.flv');
      fence.finishOpen(const <String>['https://cdn.example/live.flv'], authorizeSuccessfulOpen: true);

      final newGeneration = fence.begin('https://cdn.example/live.flv');
      fence.finishOpen(const <String>['https://cdn.example/live.flv'], authorizeSuccessfulOpen: true);

      expect(fence.accepts(oldGeneration), isFalse);
      expect(fence.accepts(newGeneration), isTrue);
    });
  });
}
