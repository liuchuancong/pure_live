import 'package:flutter_test/flutter_test.dart';
import 'package:media_core_ingest/media_core_ingest.dart';
import 'package:pure_live/domains/live/data/stream/playback_ingest_needs.dart';

void main() {
  group('playback ingest needs', () {
    test('TwitCasting declares that its children are bare names', () {
      expect(playbackIngestNeeds(Uri.parse('https://twitcasting.tv/c:someone')), <IngestNeed>{
        IngestNeed.relativeChildren,
      });
      // The manifest is served from an IP host under the same suffix.
      expect(
        playbackIngestNeeds(
          Uri.parse('https://203-137-131-14.twitcasting.tv/tc.livehls/v1/streams/1/hls/369.96/media.m3u8'),
        ),
        <IngestNeed>{IngestNeed.relativeChildren},
      );
    });

    test('an unrelated provider declares nothing and stays direct', () {
      final Uri source = Uri.parse('https://cdn.example.com/live/room.m3u8');
      final Set<IngestNeed> needs = playbackIngestNeeds(source);

      expect(needs, isEmpty);
      expect(resolveIngestPlan(needs: needs).strategy, IngestStrategy.direct);
    });

    test("a lookalike host is not the provider's", () {
      expect(playbackIngestNeeds(Uri.parse('https://nottwitcasting.tv/c:x')), isEmpty);
    });

    test('the declared need resolves to a manifest rewrite', () {
      final Uri source = Uri.parse('https://twitcasting.tv/c:someone');
      final Set<IngestNeed> needs = playbackIngestNeeds(source);

      expect(isHlsManifestUri(Uri.parse('https://203-137-131-14.twitcasting.tv/a/media.m3u8')), isTrue);
      expect(resolveIngestPlan(needs: needs, sourceIsManifest: true).strategy, IngestStrategy.manifestRelay);
    });
  });
}
