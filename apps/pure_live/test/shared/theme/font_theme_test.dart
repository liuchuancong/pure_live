import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:live_net/live_net.dart' show DioFactory;
import 'package:live_storage/live_storage.dart' show StorageRepository;
import 'package:pure_live/system/configuration/app_preferences.dart';
import 'package:pure_live/system/resources/font_library.dart';
import 'package:pure_live/system/theme/appearance_preferences/appearance_preferences.dart';
import 'package:pure_live/system/theme/font_recommendations.dart';
import 'package:pure_live/system/theme/ui_configuration_mapper.dart';
import 'package:pure_uikit/pure_uikit.dart';

void main() {
  group('font recommendations', () {
    test('every skin answers — with the platform own font or an honest none', () {
      for (final language in PureDesignLanguage.values) {
        final recommended = recommendedFontFor(language);
        if (recommended.source == RecommendedFontSource.none) {
          expect(recommended.name, isEmpty);
        } else {
          expect(recommended.family, isNotEmpty, reason: language.name);
        }
      }
      // The one technique skin has no vendor font.
      expect(recommendedFontFor(PureDesignLanguage.neumorphic).source, RecommendedFontSource.none);
    });

    test('the table names the shipped official faces, not stylistic stand-ins', () {
      expect(recommendedFontFor(PureDesignLanguage.fluent).family, 'Segoe UI');
      expect(recommendedFontFor(PureDesignLanguage.fluent).source, RecommendedFontSource.installed);
      // The five official faces ship in the app's assets — downloads are
      // replacements, never prerequisites.
      expect(recommendedFontFor(PureDesignLanguage.material).source, RecommendedFontSource.bundled);
      expect(kBundledFonts.map((font) => font.family), ['SFPro', 'SFRounded', 'Roboto', 'Inter', 'Ubuntu']);
      expect(recommendedFontFor(PureDesignLanguage.macos).name, 'SF Pro');
      expect(recommendedFontFor(PureDesignLanguage.cupertino).name, 'SF Pro Rounded');
      expect(recommendedFontFor(PureDesignLanguage.glass).name, 'SF Pro');
      expect(recommendedFontFor(PureDesignLanguage.material).name, 'Roboto');
      expect(recommendedFontFor(PureDesignLanguage.forui).name, 'Inter');
      expect(recommendedFontFor(PureDesignLanguage.wind).name, 'Inter');
      expect(recommendedFontFor(PureDesignLanguage.yaru).name, 'Ubuntu');
    });
  });

  group('resolveThemeFont', () {
    bool Function(String) downloaded(Set<String> onDisk) =>
        (id) => onDisk.contains(id);

    test('bundled and installed faces answer without the download word', () {
      // The presets are in the app binary itself: an empty font tree
      // changes nothing — downloads only ever REPLACE them.
      expect(resolveThemeFont(kThemeFontFamily, PureDesignLanguage.forui, isDownloaded: downloaded({})), 'Inter');
      expect(resolveThemeFont(kThemeFontFamily, PureDesignLanguage.fluent, isDownloaded: downloaded({})), 'Segoe UI');
    });

    test('the technique skin is the system default by rule', () {
      expect(
        resolveThemeFont(kThemeFontFamily, PureDesignLanguage.neumorphic, isDownloaded: downloaded({'x'})),
        isNull,
      );
    });

    test('an explicit choice passes through untouched; empty is the system default', () {
      final stored = resolveThemeFont('roboto-classic', PureDesignLanguage.forui, isDownloaded: downloaded({}));
      expect(stored, 'roboto-classic');
      expect(resolveThemeFont('', PureDesignLanguage.forui, isDownloaded: downloaded({'Inter'})), isNull);
      expect(resolveThemeFont(null, PureDesignLanguage.forui, isDownloaded: downloaded({'Inter'})), isNull);
    });
  });

  group('the mapper', () {
    // The per-language default families retired with the design-language
    // picker: the mapper pins one shipped language, so only the explicit
    // choice and the system default remain as behaviour.
    test('an explicit system choice ignores the recommendation', () {
      final config = uiConfigFromAppearance(
        const AppearancePreferences(designLanguageId: 'fluent', fontFamily: ''),
        themeFontAvailable: (_) => true,
      );
      expect(config.fontFamily, isNull);
    });
  });

  group('the persisted document', () {
    test('a document that predates the feature reads as 跟随设计语言', () {
      final decoded = AppearancePreferences.fromJson(const <String, Object?>{'designLanguageId': 'fluent'});
      expect(decoded.fontFamily, kThemeFontFamily);
    });

    test('an explicit system choice survives the round trip', () {
      const appearance = AppearancePreferences(fontFamily: '');
      final decoded = AppearancePreferences.fromJson(appearance.toJson());
      expect(decoded.fontFamily, '');
    });
  });

  group('the library on disk', () {
    late Directory root;
    late FontLibrary library;

    setUp(() {
      root = Directory.systemTemp.createTempSync('font_theme_test');
      library = FontLibrary(root: root, http: DioFactory().create(), commit: kFontCommit);
    });

    tearDown(() {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });

    test('a family counts as downloaded only with font files in its folder', () async {
      expect(library.isDownloaded('SFRounded'), isFalse);
      final folder = library.folderOf('SFRounded')..createSync(recursive: true);
      File('${folder.path}${Platform.pathSeparator}SFProRounded-Regular.otf').writeAsBytesSync([1, 2, 3]);
      expect(library.isDownloaded('SFRounded'), isTrue);
      // The theme resolver does NOT need any of this any more — the presets
      // are in the binary; the download word is what cloud families' own
      // state (and a future downloadable recommendation) is about.
      expect(resolveThemeFont(kThemeFontFamily, PureDesignLanguage.glass, isDownloaded: library.isDownloaded), 'SFPro');
    });

    test('installed families list every folder on disk with a shown name', () async {
      final official = library.folderOf('SFPro')..createSync(recursive: true);
      File('${official.path}${Platform.pathSeparator}SFProDisplay-Regular.otf').writeAsBytesSync([1]);
      final imported = library.folderOf('local-my-font')..createSync(recursive: true);
      File('${imported.path}${Platform.pathSeparator}font.ttf').writeAsBytesSync([1]);
      final names = {for (final family in library.installedFamilies()) family.id: family.name};
      expect(names['SFPro'], 'SF Pro'); // the recommendation table names it
      expect(names['local-my-font'], 'my font'); // imports read their stem back
      expect(names.containsKey('SFRounded'), isFalse); // empty folders stay hidden
      // The import-only view still answers just the imports.
      expect(library.importedFamilies().map((family) => family.id), ['local-my-font']);
    });

    test('the store stays constructible beside the theme stack', () async {
      // Not a font assertion — the appearance tree and the app-preferences
      // share one box; this guards that shape stays buildable here.
      final store = AppPreferencesStore(repository: _MapRepository());
      await store.load();
      expect(store.value.roomCardCornerRadius, isA<double>());
    });
  });
}

final class _MapRepository implements StorageRepository<Map<dynamic, dynamic>> {
  final Map<String, Map<dynamic, dynamic>> documents = {};

  @override
  Stream<void> watch({String? key}) => const Stream.empty();

  @override
  Map<dynamic, dynamic>? get(String key) => documents[key];

  @override
  Map<String, Map<dynamic, dynamic>> getMany(Iterable<String> keys) => {
    for (final key in keys)
      if (documents.containsKey(key)) key: documents[key]!,
  };

  @override
  List<Map<dynamic, dynamic>> getAll() => List.of(documents.values);

  @override
  Map<String, Map<dynamic, dynamic>> getAllEntries() => Map.of(documents);

  @override
  List<String> getAllKeys() => List.of(documents.keys);

  @override
  bool contains(String key) => documents.containsKey(key);

  @override
  bool containsAll(Iterable<String> keys) => keys.every(documents.containsKey);

  @override
  Future<void> save(String key, Map<dynamic, dynamic> value) async => documents[key] = value;

  @override
  Future<void> saveAll(Map<String, Map<dynamic, dynamic>> values) async => documents.addAll(values);

  @override
  Future<bool> insertIfAbsent(String key, Map<dynamic, dynamic> value) async {
    if (documents.containsKey(key)) {
      return false;
    }
    documents[key] = value;
    return true;
  }

  @override
  Future<bool> update(String key, Map<dynamic, dynamic> Function(Map<dynamic, dynamic> current) updater) async {
    if (!documents.containsKey(key)) {
      return false;
    }
    documents[key] = updater(documents[key]!);
    return true;
  }

  @override
  Future<void> delete(String key) async => documents.remove(key);

  @override
  Future<void> deleteAll(Iterable<String> keys) async => keys.forEach(documents.remove);

  @override
  Future<int> deleteWhere(bool Function(String key, Map<dynamic, dynamic> value) test) async {
    final doomed = [
      for (final entry in documents.entries)
        if (test(entry.key, entry.value)) entry.key,
    ]..forEach(documents.remove);
    return doomed.length;
  }

  @override
  int get count => documents.length;

  @override
  bool get isEmpty => documents.isEmpty;

  @override
  bool get isNotEmpty => documents.isNotEmpty;

  @override
  Future<void> clear() async => documents.clear();

  @override
  Future<void> flush() async {}
}
