import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/features/settings/surface/settings_search.dart';
import 'package:pure_live/features/settings/surface/settings_sections.dart' show SettingsSection;
import 'package:pure_live/l10n/translations.dart' show Translations;

/// The settings search's pure half: the curated catalogue (one row per
/// destination, its lowered forms built once) and the query's answer (the
/// rows whose title or keywords carry the words, inside the sections the
/// menu can open, in the catalogue's own order).
void main() {
  group('the catalogue', () {
    test('every row carries its lowered forms, and no destination repeats', () {
      final catalog = settingsSearchCatalog(Translations());
      expect(catalog, isNotEmpty);
      final destinations = <String>{};
      for (final hit in catalog) {
        expect(hit.lowerTitle, hit.title.toLowerCase());
        expect(hit.lowerKeywords, hit.keywords.toLowerCase());
        destinations.add('${hit.section.name}\u0000${hit.title}');
      }
      expect(destinations, hasLength(catalog.length)); // a row that exists here is one the viewer can be taken to
    });

    test('the cache answers the same list for one Translations and rebuilds for another', () {
      final first = Translations();
      final built = settingsSearchCatalog(first);
      expect(identical(settingsSearchCatalog(first), built), isTrue); // a keystroke asks again, the list stands

      final other = Translations();
      final rebuilt = settingsSearchCatalog(other);
      expect(identical(rebuilt, built), isFalse); // a locale switch hands a new instance and rebuilds
      expect(rebuilt, hasLength(built.length));

      // The cache has one slot: the first instance asks again and rebuilds.
      expect(identical(settingsSearchCatalog(first), built), isFalse);
    });
  });

  group('the search', () {
    test('an empty query answers nothing, and a section-less ask too', () {
      final t = Translations();
      expect(settingsSearchHits(t, '', SettingsSection.values), isEmpty);
      expect(settingsSearchHits(t, '弹幕', const <SettingsSection>[]), isEmpty);
    });

    test('a word finds its rows through titles and keywords alike', () {
      final t = Translations();
      final hits = settingsSearchHits(t, '字体', SettingsSection.values);
      expect(hits, isNotEmpty);
      for (final hit in hits) {
        expect(hit.lowerTitle.contains('字体') || hit.lowerKeywords.contains('字体'), isTrue, reason: hit.title);
      }
      expect(hits.map((hit) => hit.title), contains(t.settings.fontManagerTitle));
    });

    test("the section filter keeps its own pages, in the catalogue's order", () {
      final t = Translations();
      final displayOnly = settingsSearchHits(t, '字体', [SettingsSection.danmakuDisplay]);
      expect(displayOnly, isNotEmpty);
      expect(displayOnly.every((hit) => hit.section == SettingsSection.danmakuDisplay), isTrue);

      final both = settingsSearchHits(t, '字体', [SettingsSection.fontApp, SettingsSection.danmakuDisplay]);
      expect(both.first.section, SettingsSection.fontApp); // the catalogue's own order wins
      expect(both.map((hit) => hit.section).toSet(), {SettingsSection.fontApp, SettingsSection.danmakuDisplay});
      expect(both, hasLength(displayOnly.length + 1)); // the app face's row joins, nothing more
    });

    test('a keyword finds a row the title never names', () {
      final t = Translations();
      final hits = settingsSearchHits(t, '坚果云', SettingsSection.values);
      expect(hits.map((hit) => hit.title), contains(t.settings.webdavHelpTitle));
    });

    test('one destination answers once however many word sets it carries', () {
      final t = Translations();
      final hits = settingsSearchHits(t, '标签', SettingsSection.values);
      final tagRows = hits.where(
        (hit) => hit.section == SettingsSection.followTags && hit.title == t.settings.tagManagement,
      );
      expect(tagRows, hasLength(1));

      // The merged row still answers both old word sets.
      expect(
        settingsSearchHits(t, '置顶', SettingsSection.values).map((hit) => hit.title),
        contains(t.settings.tagManagement),
      );
      expect(
        settingsSearchHits(t, '自定义', SettingsSection.values).map((hit) => hit.title),
        contains(t.settings.tagManagement),
      );
      // The glass row answers the surface words its second copy carried.
      expect(
        settingsSearchHits(t, '对话框', SettingsSection.values).map((hit) => hit.title),
        contains(t.settings.backgroundGlass),
      );
      expect(
        settingsSearchHits(t, '悬浮', SettingsSection.values).map((hit) => hit.title),
        contains(t.settings.backgroundGlass),
      );
    });

    test('the quality words answer across the pages that carry them', () {
      final t = Translations();
      final hits = settingsSearchHits(t, '清晰度', SettingsSection.values);
      expect(hits.map((hit) => hit.title), contains(t.settings.preferredQuality)); // the live picture's
      expect(hits.map((hit) => hit.title), contains(t.recorder.defaultQualityTitle)); // the recording's
      // The music page's own words are 音质 — it answers that query instead.
      expect(settingsSearchHits(t, '音质', SettingsSection.values).map((hit) => hit.title), contains(t.music.quality));
    });
  });
}
