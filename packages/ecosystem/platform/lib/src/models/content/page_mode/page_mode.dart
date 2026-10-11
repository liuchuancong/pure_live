// Module: lib/src/models/content/page_mode/page_mode.dart
// Purpose: How a listing is continued.
// Author: liuchuancong
// Created: 2026-10-11
//
// Spec: docs/contracts/platform-models.md. Split out of the file that bundled it: one public
// type per file, and the file lives in a folder of its own (§2.1) so a model and anything generated
// for it are found in one place.

import '../page_request/page_request.dart';

/// How a source pages its listings. The source declares the mode on every
/// answer; the consumer reads the fields the mode names and must not assume.
/// Sources in the wild genuinely differ: fixed page tables, opaque server
/// cursors, and lists that simply come back whole.
enum PageMode {
  /// One-based page numbers with a page size; the classic table.
  fixedPage,

  /// The answer carries [PageResult.nextCursor]; the next request passes it
  /// back as [PageRequest.cursor] and the page number is meaningless.
  cursor,

  /// The answer is the whole list. hasMore is always false by definition, and
  /// asking for page 2 returns empty.
  singleShot,
}
