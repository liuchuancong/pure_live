// One-off migration, run once then deleted: split the bundled content model files into one public type per
// file, each in its own folder (docs/architecture/package-architecture.md §2.1). Boundaries are the exact line
// ranges read off `grep -n` for the two files, so nothing here guesses at declaration starts.
import 'dart:io';

const String base = 'packages/ecosystem/platform/lib/src/models/content';

class Piece {
  const Piece(this.start, this.end, this.name, this.folder, this.purpose);

  final int start;
  final int end;
  final String name;
  final String folder;
  final String purpose;
}

const List<Piece> contentRef = <Piece>[
  Piece(14, 35, 'ContentKind', 'content_kind', 'What kind of content a reference points at.'),
  Piece(36, 82, 'ContentMetadata', 'content_metadata', 'The descriptive columns a listing shows beside a title.'),
  Piece(83, 115, 'ContentCategory', 'content_category', 'One entry of a source\'s own category table.'),
  Piece(116, 128, 'ContentTag', 'content_tag', 'A label the source puts on content, as the source names it.'),
  Piece(129, 207, 'ContentRef', 'content_ref', 'A reference to content inside one source.'),
  Piece(208, 248, 'ContentSummary', 'content_summary', 'The card-sized view of content, used by lists and search results.'),
  Piece(249, 285, 'ContentDetail', 'content_detail', 'The full answer for one item, including its children.'),
];

const List<Piece> paging = <Piece>[
  Piece(16, 29, 'PageMode', 'page_mode', 'How a listing is continued.'),
  Piece(30, 55, 'PageRequest', 'page_request', 'Which page to fetch.'),
  Piece(56, 111, 'PageResult', 'page_result', 'One page of results.'),
  Piece(112, 114, 'ContentSort', 'content_sort', 'The orderings a source can be asked to serve.'),
  Piece(115, 149, 'ContentQuery', 'content_query', 'One listing request.'),
  Piece(150, 185, 'SearchQuery', 'search_query', 'One search request.'),
  Piece(186, 198, 'RefreshReason', 'refresh_reason', 'Why a ticket is being renewed.'),
  Piece(199, 218, 'SelectionRef', 'selection_ref', 'A choice the viewer made from a menu the source published.'),
];

void emit(List<String> lines, List<String> imports, String header, Iterable<Piece> pieces) {
  for (final piece in pieces) {
    final folder = Directory('$base/${piece.folder}');
    folder.createSync(recursive: true);
    final out = StringBuffer();
    out.writeln('// Module: ${base.replaceFirst("packages/ecosystem/platform/", "lib/src/")}/'
        '${piece.folder}/${piece.folder}.dart');
    out.writeln('// Purpose: ${piece.purpose}');
    out.writeln('// Author: liuchuancong');
    out.writeln('// Created: 2026-10-11');
    out.writeln('//');
    out.writeln('// Spec: docs/contracts/platform-models.md. Split out of the file that bundled it: one public');
    out.writeln('// type per file, and the file lives in a folder of its own (§2.1) so a model and anything generated');
    out.writeln('// for it are found in one place.');
    out.writeln();
    for (final import in imports) {
      out.writeln(import);
    }
    out.writeln();
    out.writeln(lines.sublist(piece.start - 1, piece.end).join('\n'));
    File('${folder.path}/${piece.folder}.dart').writeAsStringSync('${out.toString()}\n');
  }
}

void main() {
  for (final entry in <String, List<Piece>>{
    'content_ref.dart': contentRef,
    'paging.dart': paging,
  }.entries) {
    final file = File('$base/${entry.key}');
    final lines = file.readAsLinesSync();
    final imports = lines.where((line) => line.startsWith('import ')).toList();
    emit(lines, imports, entry.key, entry.value);
    stdout.writeln('split ${entry.key} into ${entry.value.length} files');
  }
}
