// Module: test/models/content_test.dart
// Purpose: Verify the ContentRef family rules from docs/contracts/platform-models.md sections 7 and 16.
// Author: liuchuancong
// Created: 2026-10-08
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:test/test.dart';

void main() {
  test('test_contentRef_jsonRoundTrip_preservesEveryField', () {
    const ref = ContentRef(
      sourceId: 'src-1',
      contentId: 'room-42',
      kind: ContentKind.liveRoom,
      parentId: 'group-1',
      providerId: 'prov-1',
      metadata: <String, Object?>{'platform.data_freshness': 12},
    );

    expect(ContentRef.fromJson(ref.toJson()), ref);
  });

  test('test_contentRef_equal_ignoresMetadataDifferences', () {
    // Section 16: equality is the identity tuple, so a refreshed description must not create a new key.
    const a = ContentRef(
      sourceId: 's',
      contentId: 'c',
      kind: ContentKind.vod,
      metadata: <String, Object?>{'note': 'old'},
    );
    const b = ContentRef(
      sourceId: 's',
      contentId: 'c',
      kind: ContentKind.vod,
      metadata: <String, Object?>{'note': 'new'},
    );

    expect(a, equals(b));
    expect(a.hashCode, b.hashCode);
  });

  test('test_contentRef_notEqual_whenAnyIdentityFieldDiffers', () {
    const base = ContentRef(sourceId: 's', contentId: 'c', kind: ContentKind.vod);
    expect(base, isNot(equals(const ContentRef(sourceId: 'other', contentId: 'c', kind: ContentKind.vod))));
    expect(base, isNot(equals(const ContentRef(sourceId: 's', contentId: 'c', kind: ContentKind.movie))));
    expect(base, isNot(equals(const ContentRef(sourceId: 's', contentId: 'c', kind: ContentKind.vod, parentId: 'p'))));
  });

  test('test_contentRef_fromJson_toleratesUnknownFieldsAndMissingOptionals', () {
    // Section 16 forward compatibility: a newer writer must not break an older reader.
    final ref = ContentRef.fromJson(<String, Object?>{
      'sourceId': 's',
      'contentId': 'c',
      'kind': 'movie',
      'aFieldFromTheFuture': <String, Object?>{'nested': true},
    });

    expect(ref.kind, ContentKind.movie);
    expect(ref.parentId, isNull);
    expect(ref.providerId, isNull);
  });

  test('test_contentRef_fromJson_degradesUnknownEnumToKnownValue', () {
    final ref = ContentRef.fromJson(<String, Object?>{'sourceId': 's', 'contentId': 'c', 'kind': 'karaoke'});

    expect(ref.kind, ContentKind.vod);
  });

  test('test_contentRef_json_encodesEnumByName_notByIndex', () {
    const ref = ContentRef(sourceId: 's', contentId: 'c', kind: ContentKind.series);

    expect(ref.toJson()['kind'], 'series');
  });

  test('test_contentSummary_jsonRoundTrip_keepsMetadataNumbers', () {
    const summary = ContentSummary(
      ref: ContentRef(sourceId: 's', contentId: 'c', kind: ContentKind.movie),
      title: 'Title',
      subtitle: 'Sub',
      cover: 'https://cover',
      metadata: ContentMetadata(
        year: '2026',
        region: 'CN',
        language: 'zh',
        duration: Duration(minutes: 93),
        rating: 8.4,
        popularity: 1200,
        extra: <String, Object?>{'tvbox.note': 'kept'},
      ),
    );

    final decoded = ContentSummary.fromJson(summary.toJson());
    expect(decoded.title, 'Title');
    expect(decoded.metadata.duration, const Duration(minutes: 93));
    expect(decoded.metadata.rating, 8.4);
    expect(decoded.metadata.popularity, 1200);
    expect(decoded.metadata.extra['tvbox.note'], 'kept');
  });

  test('test_contentMetadata_json_dropsAbsentFields', () {
    const metadata = ContentMetadata();

    expect(metadata.toJson(), isEmpty);
  });
}
