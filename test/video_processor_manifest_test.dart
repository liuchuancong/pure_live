import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pure_live/recorder/services/video_processor_service.dart';

void main() {
  test('segment selection isolates overlapping prefixes and never borrows clock-v1 for legacy recovery', () {
    final files = [
      File('attempt_000000.clock-v1.ts'),
      File('attempt_other_000000.clock-v1.ts'),
      File('other_000000.clock-v1.ts'),
    ];
    expect(VideoProcessorService.selectAttemptSegments(candidates: files, filePrefix: 'attempt'), [files.first]);
    expect(
      VideoProcessorService.selectAttemptSegments(candidates: files, filePrefix: 'missing', allowLegacySegments: true),
      isEmpty,
    );
  });
  test('merge timeout scales beyond the old five-second failure window', () {
    expect(VideoProcessorService.mergeTimeout(inputBytes: 1024, recordedSeconds: 1), const Duration(seconds: 30));
    expect(
      VideoProcessorService.mergeTimeout(inputBytes: 2 * 1024 * 1024 * 1024, recordedSeconds: 3600),
      greaterThan(const Duration(minutes: 3)),
    );
  });

  test('concat manifest is explicit and safely escapes portable paths', () {
    final manifest = VideoProcessorService.buildConcatManifest(<String>[
      r'C:\Pure Live\001.ts',
      "/tmp/anchor's/002.ts",
    ]);

    expect(manifest, startsWith('ffconcat version 1.0\n'));
    expect(manifest, contains("file 'C:/Pure Live/001.ts'"));
    expect(manifest, contains(r"file '/tmp/anchor'\''s/002.ts'"));
  });

  test('normal retries never merge segments from an older attempt', () {
    // Host-native separators: basename() must see a directory on every OS.
    final records = p.join(p.rootPrefix(Directory.systemTemp.absolute.path), 'records');
    final files = <File>[
      File(p.join(records, '20260827_080000_001_000000.ts')),
      File(p.join(records, '20260827_080001_002_000000.ts')),
    ];

    expect(
      VideoProcessorService.selectAttemptSegments(
        candidates: files,
        filePrefix: '20260827_080001_002',
      ).map((file) => file.path),
      [p.join(records, '20260827_080001_002_000000.ts')],
    );
    expect(VideoProcessorService.selectAttemptSegments(candidates: files, filePrefix: 'missing'), isEmpty);
    expect(
      VideoProcessorService.selectAttemptSegments(candidates: files, filePrefix: 'legacy', allowLegacySegments: true),
      files,
    );
  });
}
