import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/recorder/services/ffmpeg_service.dart';

void main() {
  test('FFmpeg diagnostics distinguish output configuration from retryable input failures', () {
    final output = FFmpegFailureClassifier.classify(
      code: 1,
      logs: 'Error opening output /storage/emulated/0/PureLive/segment.ts: Permission denied',
    );
    final input = FFmpegFailureClassifier.classify(
      code: 1,
      logs: 'Error opening input https://cdn.example/live.flv',
    );

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
    expect(
      FFmpegFailureClassifier.classify(code: 1, logs: 'TLS handshake failed').kind,
      FFmpegFailureKind.transport,
    );
    expect(
      FFmpegFailureClassifier.classify(
        code: 1,
        logs: 'Invalid data found when processing input',
      ).kind,
      FFmpegFailureKind.inputFormat,
    );
    expect(
      FFmpegFailureClassifier.classify(code: 1, logs: 'Decoder failed for codec h264').kind,
      FFmpegFailureKind.decoder,
    );
  });

  test('a native minus-two exit is not assumed to be an output path failure', () {
    final unknown = FFmpegFailureClassifier.classify(
      code: -2,
      logs: 'native session returned ENOENT',
    );
    final input = FFmpegFailureClassifier.classify(
      code: -2,
      logs: 'Error opening input: No such file or directory',
    );

    expect(unknown.kind, FFmpegFailureKind.native);
    expect(unknown.retryable, isTrue);
    expect(input.kind, FFmpegFailureKind.inputOpen);
    expect(input.retryable, isTrue);
  });

  test(
    'input Invalid argument remains retryable unless option parsing proves a command defect',
    () {
      final input = FFmpegFailureClassifier.classify(
        code: 1,
        logs: 'Error opening input https://cdn.example/live: Invalid argument',
      );
      final ambiguous = FFmpegFailureClassifier.classify(
        code: 1,
        logs: 'live input failed: Invalid argument',
      );
      final command = FFmpegFailureClassifier.classify(
        code: 1,
        logs: 'Unrecognized option rw_timeout',
      );

      expect(input.kind, FFmpegFailureKind.inputOpen);
      expect(input.retryable, isTrue);
      expect(ambiguous.kind, FFmpegFailureKind.native);
      expect(ambiguous.retryable, isTrue);
      expect(command.kind, FFmpegFailureKind.command);
      expect(command.retryable, isFalse);
    },
  );

  test('live recorder accepts only an explicit stop as successful completion', () {
    final userStop = FFmpegTerminalDecision.forSession(
      code: 255,
      manuallyStopped: true,
      liveRecording: true,
    );
    final cleanEof = FFmpegTerminalDecision.forSession(
      code: 0,
      manuallyStopped: false,
      liveRecording: true,
    );
    final avEof = FFmpegTerminalDecision.forSession(
      code: -541478725,
      manuallyStopped: false,
      liveRecording: true,
    );
    final nativeFailure = FFmpegTerminalDecision.forSession(
      code: 1,
      manuallyStopped: false,
      liveRecording: true,
    );
    final completedMerge = FFmpegTerminalDecision.forSession(
      code: 0,
      manuallyStopped: false,
      liveRecording: false,
    );
    final leaseRotation = FFmpegTerminalDecision.forSession(
      code: 255,
      manuallyStopped: false,
      liveRecording: true,
      leaseRefresh: true,
    );

    expect(userStop.isComplete, isTrue);
    expect(userStop.unexpectedEof, isFalse);
    expect(cleanEof.isComplete, isFalse);
    expect(cleanEof.unexpectedEof, isTrue);
    expect(cleanEof.retryable, isTrue);
    expect(avEof.unexpectedEof, isTrue);
    expect(nativeFailure.isComplete, isFalse);
    expect(nativeFailure.unexpectedEof, isFalse);
    expect(completedMerge.isComplete, isTrue);
    expect(completedMerge.unexpectedEof, isFalse);
    expect(leaseRotation.isComplete, isFalse);
    expect(leaseRotation.retryable, isTrue);
    expect(leaseRotation.unexpectedEof, isTrue);
  });
}
