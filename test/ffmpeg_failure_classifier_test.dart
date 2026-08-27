import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/recorder/services/ffmpeg_service.dart';

void main() {
  test('FFmpeg diagnostics distinguish output configuration from retryable input failures', () {
    final output = FFmpegFailureClassifier.classify(
      code: 1,
      logs: 'Error opening output /storage/emulated/0/PureLive/segment.ts: Permission denied',
    );
    final input = FFmpegFailureClassifier.classify(code: 1, logs: 'Error opening input https://cdn.example/live.flv');

    expect(output.kind, FFmpegFailureKind.outputPath);
    expect(output.retryable, isFalse);
    expect(input.kind, FFmpegFailureKind.inputOpen);
    expect(input.retryable, isTrue);
  });

  test('HTTP, transport, format and decoder failures remain separately observable', () {
    expect(
      FFmpegFailureClassifier.classify(code: 1, logs: 'Server returned 403 Forbidden').kind,
      FFmpegFailureKind.httpAccess,
    );
    expect(FFmpegFailureClassifier.classify(code: 1, logs: 'TLS handshake failed').kind, FFmpegFailureKind.transport);
    expect(
      FFmpegFailureClassifier.classify(code: 1, logs: 'Invalid data found when processing input').kind,
      FFmpegFailureKind.inputFormat,
    );
    expect(
      FFmpegFailureClassifier.classify(code: 1, logs: 'Decoder failed for codec h264').kind,
      FFmpegFailureKind.decoder,
    );
  });

  test('a native minus-two exit is not assumed to be an output path failure', () {
    final unknown = FFmpegFailureClassifier.classify(code: -2, logs: 'native session returned ENOENT');
    final input = FFmpegFailureClassifier.classify(code: -2, logs: 'Error opening input: No such file or directory');

    expect(unknown.kind, FFmpegFailureKind.native);
    expect(unknown.retryable, isTrue);
    expect(input.kind, FFmpegFailureKind.inputOpen);
    expect(input.retryable, isTrue);
  });
}
