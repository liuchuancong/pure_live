// Module: lib/src/lib/src/models/content/content_sort/content_sort.dart
// Purpose: The orderings a source can be asked to serve.
// Author: liuchuancong
// Created: 2026-10-11
//
// Spec: docs/contracts/platform-models.md. Split out of the file that bundled it: one public
// type per file, and the file lives in a folder of its own (§2.1) so a model and anything generated
// for it are found in one place.

enum ContentSort { relevance, latest, popularity, rating, title }

/// A browse query inside one source.
