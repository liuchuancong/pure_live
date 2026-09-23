import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/recorder/services/hls_retained_manifest.dart';
import 'package:pure_live/recorder/services/hls_retained_window.dart';

final source = Uri.parse('https://origin.example/video/index.m3u8');
String manifest(String body, {String properties = '', int first = 40}) =>
    '#EXTM3U\n#EXT-X-VERSION:9\n#EXT-X-TARGETDURATION:2\n'
    '#EXT-X-MEDIA-SEQUENCE:$first\n$properties$body';
HlsRetainedWindow retain(String text, {int count = 64}) =>
    HlsRetainedWindow(source, maximumSegments: count)..merge(HlsMediaSnapshot.parse(text, source));
String render(HlsRetainedWindow window, {int? through, bool finish = false}) =>
    renderHlsRetainedManifest(window, localUri: (uri) => uri, throughSequence: through, finish: finish);
void sameMedia(HlsRetainedWindow window, String text, {int? count}) {
  final actual = HlsMediaSnapshot.parse(text, source).segments;
  final expected = window.segments.take(count ?? window.segments.length).toList();
  expect(actual.map((s) => s.identity), expected.map((s) => s.identity));
  expect(actual.map((s) => s.programTime), expected.map((s) => s.programTime));
  expect(actual.map((s) => s.extinf), expected.map((s) => s.extinf));
}

void main() {
  test('retained prefix preserves sequence, range, discontinuity and inferred first PDT', () {
    final window = retain(
      manifest(
        '#EXT-X-KEY:METHOD=AES-128,URI="key,a",IV=0x01\n'
        '#EXT-X-MAP:URI="init.mp4",BYTERANGE="8@16"\n'
        '#EXT-X-PROGRAM-DATE-TIME:2026-09-09T08:00:00.123Z\n'
        '#EXTINF:2,old\n#EXT-X-BYTERANGE:10@100\nall.mp4\n'
        '#EXTINF:2,retained\n#EXT-X-BYTERANGE:20\nall.mp4\n'
        '#EXT-X-DISCONTINUITY\n#EXT-X-PROGRAM-DATE-TIME:2026-09-09T08:00:07.123Z\n'
        '#EXTINF:2,after discontinuity\n#EXT-X-BYTERANGE:30\nall.mp4\n',
        properties: '#EXT-X-INDEPENDENT-SEGMENTS\n#EXT-X-DISCONTINUITY-SEQUENCE:7\n',
      ),
      count: 2,
    );
    final text = render(window);
    expect(text, contains('#EXT-X-MEDIA-SEQUENCE:41\n'));
    expect(text, contains('#EXT-X-DISCONTINUITY-SEQUENCE:7\n'));
    expect(text, contains('#EXT-X-BYTERANGE:20@110\n'));
    expect(text, contains('#EXT-X-PROGRAM-DATE-TIME:2026-09-09T08:00:02.123Z'));
    expect(text, contains('#EXT-X-VERSION:9\n'));
    expect(text, contains('#EXT-X-INDEPENDENT-SEGMENTS\n'));
    sameMedia(window, text);
  });
  test('initialization key is restored before map then media key and NONE are restored', () {
    final window = retain(
      manifest(
        '#EXT-X-KEY:METHOD=AES-128,URI="init-key",IV=0x01\n'
        '#EXT-X-MAP:URI="init.mp4"\n'
        '#EXT-X-KEY:METHOD=AES-128,URI="media-key",IV=0x02\n'
        '#EXTINF:2,\na.m4s\n'
        '#EXT-X-KEY:METHOD=NONE\n#EXTINF:2,\nb.m4s\n'
        '#EXT-X-KEY:METHOD=SAMPLE-AES,URI="other",KEYFORMAT="custom",KEYFORMATVERSIONS="1/2"\n'
        '#EXT-X-MAP:URI="new-init.mp4"\n#EXTINF:2,\nc.m4s\n',
      ),
      count: 2,
    );
    final text = render(window);
    sameMedia(window, text);
    expect(text.indexOf('init-key'), lessThan(text.indexOf('#EXT-X-MAP:')));
    expect(text, contains('#EXT-X-KEY:METHOD=NONE\n#EXTINF:2,\n'));
    expect(text, contains('KEYFORMATVERSIONS="1/2"'));
  });
  test('removing one key format clears stale formats without changing retained descriptors', () {
    final window = retain(
      manifest(
        '#EXT-X-KEY:METHOD=SAMPLE-AES,URI="one",KEYFORMAT="one"\n'
        '#EXT-X-KEY:METHOD=SAMPLE-AES,URI="two",KEYFORMAT="two"\n'
        '#EXTINF:2,\na.m4s\n#EXT-X-KEY:METHOD=NONE\n'
        '#EXT-X-KEY:METHOD=SAMPLE-AES,URI="two",KEYFORMAT="two"\n'
        '#EXTINF:2,\nb.m4s\n',
      ),
    );
    sameMedia(window, render(window));
    expect(window.segments.first.keys.length, 2);
  });
  test('partial availability does not publish ENDLIST; stop freezes only requested prefix', () {
    final window = retain(manifest('#EXTINF:2,\na.ts\n#EXT-X-GAP\n#EXTINF:2,\nb.ts\n#EXT-X-ENDLIST\n'));
    final text = render(window, through: 40);
    expect(text, isNot(contains('#EXT-X-ENDLIST')));
    expect(text, isNot(contains('b.ts')));
    sameMedia(window, text, count: 1);
    expect(render(window, through: 40, finish: true), contains('#EXT-X-ENDLIST\n'));
    sameMedia(window, render(window));
    expect(render(window), contains('#EXT-X-GAP\n'));
    expect(render(window), contains('#EXT-X-ENDLIST\n'));
    expect(() => render(window, through: 39), throwsArgumentError);
    expect(window.segments.length, 2);
  });
  test('EVENT becomes ordinary bounded media while VOD eviction is rejected atomically', () {
    final event = manifest('#EXTINF:2,\na.ts\n#EXTINF:2,\nb.ts\n', properties: '#EXT-X-PLAYLIST-TYPE:EVENT\n');
    final window = retain(event, count: 1);
    expect(render(window), isNot(contains('#EXT-X-PLAYLIST-TYPE')));
    sameMedia(window, render(window));
    final vod = HlsRetainedWindow(source, maximumSegments: 1);
    expect(() => vod.merge(HlsMediaSnapshot.parse(event.replaceFirst('EVENT', 'VOD'), source)), throwsFormatException);
    expect(vod.segments, isEmpty);
    expect(vod.targetDuration, 1);
    expect(
      () => window.merge(HlsMediaSnapshot.parse(event.replaceFirst('EVENT', 'VOD'), source)),
      throwsFormatException,
    );
  });
  test('local URI rewrite covers keys, maps and media without changing original snapshots', () {
    final window = retain(
      manifest(
        '#EXT-X-KEY:METHOD=AES-128,URI="k",IV=0x01\n'
        '#EXT-X-MAP:URI="init.mp4"\n#EXTINF:2,\na.m4s\n',
      ),
    );
    final seen = <Uri>[];
    final text = renderHlsRetainedManifest(
      window,
      localUri: (uri) {
        seen.add(uri);
        return uri.replace(scheme: 'http', host: '127.0.0.1', port: 12345);
      },
    );
    expect(seen.map((uri) => uri.path), ['/video/k', '/video/init.mp4', '/video/a.m4s']);
    expect(text, isNot(contains('origin.example')));
    expect(window.segments.single.uri.host, 'origin.example');
    expect(() => renderHlsRetainedManifest(window, localUri: (_) => Uri.parse('file:///bad')), throwsFormatException);
    expect(() => renderHlsRetainedManifest(window, localUri: (uri) => uri, maximumBytes: 30), throwsFormatException);
    expect(() => renderHlsRetainedManifest(window, localUri: (uri) => uri, maximumBytes: 0), throwsArgumentError);
  });
  test('unsupported MAP and KEY attributes are not silently lost', () {
    final parsed = HlsMediaSnapshot.parse(manifest('#EXT-X-MAP:URI="init.mp4",OTHER=1\n#EXTINF:2,\na.m4s\n'), source);
    expect(parsed.unhandledTags, contains('#EXT-X-MAP:attributes'));
    expect(() => HlsRetainedWindow(source).merge(parsed), throwsFormatException);
    final key = retain(manifest('#EXT-X-KEY:METHOD=AES-128,URI="k",OTHER=1\n#EXTINF:2,\na.ts\n'));
    expect(() => render(key), throwsFormatException);
  });
  test('legacy ALLOW-CACHE YES permits retention, while NO keeps fallback', () {
    final yes = manifest('#EXTINF:2,\na.ts\n', properties: '#EXT-X-ALLOW-CACHE:YES\n');
    final window = retain(yes);
    final output = render(window);
    sameMedia(window, output);
    expect(output, isNot(contains('#EXT-X-ALLOW-CACHE')));

    for (final value in ['NO', 'MAYBE', 'yes']) {
      final parsed = HlsMediaSnapshot.parse(
        manifest('#EXTINF:2,\na.ts\n', properties: '#EXT-X-ALLOW-CACHE:$value\n'),
        source,
      );
      expect(parsed.unhandledTags, contains('#EXT-X-ALLOW-CACHE'));
      expect(() => HlsRetainedWindow(source).merge(parsed), throwsFormatException);
    }
    expect(
      () => HlsMediaSnapshot.parse(
        manifest('#EXTINF:2,\na.ts\n', properties: '#EXT-X-ALLOW-CACHE:YES\n#EXT-X-ALLOW-CACHE:YES\n'),
        source,
      ),
      throwsFormatException,
    );
  });
  test('map disappearance and pathological discontinuity expansion fail instead of changing media meaning', () {
    final window = retain(manifest('#EXT-X-MAP:URI="init.mp4"\n#EXTINF:2,\na.m4s\n'));
    window.merge(HlsMediaSnapshot.parse(manifest('#EXTINF:2,\nb.ts\n', first: 41), source));
    expect(() => render(window), throwsFormatException);
    final jump = retain(manifest('#EXTINF:2,\na.ts\n'));
    jump.merge(
      HlsMediaSnapshot.parse(
        manifest('#EXTINF:2,\nb.ts\n', first: 41, properties: '#EXT-X-DISCONTINUITY-SEQUENCE:9223372036854775800\n'),
        source,
      ),
    );
    expect(() => render(jump), throwsFormatException);
  });
  test('empty ended publication is valid and low source version gains MAP compatibility', () {
    final window = retain(manifest('#EXT-X-ENDLIST\n').replaceFirst('VERSION:9', 'VERSION:1'));
    final text = render(window);
    expect(text, contains('#EXT-X-VERSION:6\n'));
    expect(HlsMediaSnapshot.parse(text, source).ended, true);
  });
}
