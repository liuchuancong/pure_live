// Module: lib/src/constant/huya_identity.dart
// Purpose: The stable names this source puts on its own rows and tickets.
// Author: liuchuancong
// Created: 2026-10-11
//
// Spec: docs/sources/live/huya.md. A source id is also the ContentRef sourceId (plugin-manifest.md §2), so it
// outlives any refactor of this package: changing it orphans every stored favourite, history row and ticket.

/// The source id every huya row carries.
const String huyaSourceId = 'huya.live';

/// The ticket metadata key naming the CDN entry a ticket was opened from, 1-based as a surface shows it.
const String huyaLineKey = 'huya.line';

/// The ticket metadata key holding how many CDN entries the room offered at resolve time.
const String huyaLineCountKey = 'huya.lineCount';

/// The ticket metadata key recording a quality the viewer asked for and the anonymous path cannot give.
const String huyaRequestedQualityKey = 'huya.requestedQuality';
