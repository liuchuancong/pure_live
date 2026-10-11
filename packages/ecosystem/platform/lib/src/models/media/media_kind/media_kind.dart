// Module: lib/src/models/media/media_ticket.dart
// Purpose: MediaKind, split out of the file that bundled it (see package-architecture.md
// §2.1): one public type per file, and the file in a folder of its own so anything generated for
// it lands beside it.
// Author: liuchuancong
// Created: 2026-10-11

import '../../../support/json.dart';
import '../../content/content_ref/content_ref.dart';
import '../media_track_type/media_track_type.dart';

enum MediaKind { live, vod, music, file }

/// Which essence a track carries. Mirrors media_core's `MediaTrackType` one for one
/// (packages/media_core/lib/source/media_track_type.dart); it is not [MediaKind], which classifies the
/// resource as a whole rather than one stream inside it.
