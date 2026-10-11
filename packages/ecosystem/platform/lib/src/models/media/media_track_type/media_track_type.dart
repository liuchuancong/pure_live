// Module: lib/src/models/media/media_ticket.dart
// Purpose: MediaTrackType, split out of the file that bundled it (see package-architecture.md
// §2.1): one public type per file, and the file in a folder of its own so anything generated for
// it lands beside it.
// Author: liuchuancong
// Created: 2026-10-11

import '../../../support/json.dart';
import '../../content/content_ref/content_ref.dart';

enum MediaTrackType { video, audio, subtitle }

/// How the resource is transported.
