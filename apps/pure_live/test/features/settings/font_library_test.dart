// The parts of the font library that decide what an imported family is called
// and which files count as its fonts — both are disk-shaped logic with no engine
// in the way, and both were worth pinning before the picker can be trusted.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:live_net/live_net.dart';
import 'package:pure_live/system/resources/font_library.dart';

void main() {
  group('idForImport', () {
    test('folds what a folder name cannot hold', () {
      expect(FontLibrary.idForImport(r'C:\fonts\My Font:Bold.TTF'), 'local-My-Font-Bold');
      expect(FontLibrary.idForImport('/tmp/a/b/c/SourceHanSans.otf'), 'local-SourceHanSans');
    });

    test('keeps a name written in another language', () => expect(FontLibrary.idForImport('/tmp/思源黑体.ttf'), 'local-思源黑体'));

    test('never answers with an empty or unsafe id', () {
      expect(FontLibrary.idForImport('/tmp/???.ttf'), 'local-font');
      expect(isSafeFontId(FontLibrary.idForImport('/tmp/a*b?.otf')), isTrue);
    });

    test('is told apart from a manifest family by the prefix alone', () {
      expect(FontLibrary.isImported('local-SourceHanSans'), isTrue);
      expect(FontLibrary.isImported('SourceHanSans'), isFalse);
    });

    test('reads back as a shown name with the separators as spaces', () {
      expect(FontLibrary.nameForImport('local-Source_Han-Sans-Regular'), 'Source Han Sans Regular');
    });
  });

  group('the fonts tree', () {
    late Directory root;
    late FontLibrary library;

    setUp(() {
      root = Directory.systemTemp.createTempSync('pure_live_fonts_');
      library = FontLibrary(root: root, http: _NoHttp(), commit: '');
    });
    tearDown(() => root.deleteSync(recursive: true));

    void write(String id, String name) {
      Directory('${root.path}/$id').createSync();
      File('${root.path}/$id/$name').writeAsBytesSync([1]);
    }

    test('counts the formats an import accepts, not only ttf', () {
      write('local-Test', 'font.ttf');
      write('local-Test', 'bold.otf');
      write('local-Test', 'numbers.ttc');

      expect(library.filesOf('local-Test').map((file) => file.uri.pathSegments.last), ['bold.otf', 'font.ttf', 'numbers.ttc']);
      expect(library.isDownloaded('local-Test'), isTrue);
      expect(library.isDownloaded('missing'), isFalse);
      expect(library.filesOf('../escape'), isEmpty);
    });

    test('a non-font file in the folder does not make it a family', () {
      write('local-Notes', 'readme.md');
      expect(library.isDownloaded('local-Notes'), isFalse);
    });

    test('lists only the imported families, by shown name', () {
      write('local-Zeta', 'font.ttf');
      write('local-Alpha', 'font.otf');
      write('CloudFamily', 'font.ttf');
      Directory('${root.path}/local-Empty').createSync();

      expect(library.importedFamilies().map((family) => family.name), ['Alpha', 'Zeta']);
      expect(library.importedFamilies().first.id, 'local-Alpha');
    });
  });
}

/// The transport is only used by the manifest and the download, neither of
/// which these tests start.
final class _NoHttp implements LiveHttp {
  @override
  Future<LiveResponse> send(LiveRequest request) => throw UnsupportedError('no network in this test');

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) => throw UnsupportedError('no network in this test');

  @override
  void close() {}
}
