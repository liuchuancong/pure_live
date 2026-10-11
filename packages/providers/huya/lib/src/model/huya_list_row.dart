// Module: lib/src/model/huya_list_row.dart
// Purpose: One room row, as either the live list or the search endpoint described it.
// Author: liuchuancong
// Created: 2026-10-11
//
// Spec: docs/sources/live/huya.md. The two endpoints describe the same room with different field names
// (`profileRoom`/`room_id`, `screenshot`/`game_screenshot`, `nick`/`game_nick`), so both readings land in one
// row type and only one place turns it into a `ContentSummary`. Two conversions drift: one gets fixed after a
// field rename and the other keeps showing blank tiles.

import 'package:pure_live_platform/pure_live_platform.dart';

import '../constant/huya_endpoints.dart';
import '../constant/huya_identity.dart';

/// A huya room as one of the list endpoints reported it.
final class HuyaListRow {
  const HuyaListRow({
    required this.roomId,
    this.title = '',
    this.fallbackTitle = '',
    this.anchorName = '',
    this.areaName = '',
    this.cover,
    this.viewers,
  });

  /// From a `getLiveListByPage` row.
  factory HuyaListRow.fromList(Map<String, Object?> row) => HuyaListRow(
    roomId: '${row['profileRoom'] ?? ''}',
    title: '${row['introduction'] ?? ''}',
    fallbackTitle: '${row['roomName'] ?? ''}',
    anchorName: '${row['nick'] ?? ''}',
    areaName: '${row['gameFullName'] ?? ''}',
    cover: _thumb(row['screenshot']),
    viewers: _int(row['totalCount']),
  );

  /// From a search `docs` row.
  factory HuyaListRow.fromSearch(Map<String, Object?> row) => HuyaListRow(
    roomId: '${row['room_id'] ?? ''}',
    title: '${row['game_introduction'] ?? ''}',
    fallbackTitle: '${row['game_roomName'] ?? ''}',
    anchorName: '${row['game_nick'] ?? ''}',
    areaName: '${row['gameName'] ?? ''}',
    cover: _thumb(row['game_screenshot'] ?? row['game_imgUrl']),
    viewers: _int(row['game_onlineCount']),
  );

  final String roomId;

  /// The line the source shows first; [fallbackTitle] is what it shows when that is empty.
  final String title;
  final String fallbackTitle;
  final String anchorName;
  final String areaName;
  final String? cover;

  /// Null means the endpoint did not say, which is not the same as zero viewers.
  final int? viewers;

  /// The row as the platform's summary, in the source's own vocabulary.
  ContentSummary toSummary() => ContentSummary(
    ref: ContentRef(sourceId: huyaSourceId, contentId: roomId, kind: ContentKind.liveRoom),
    title: title.trim().isNotEmpty ? title : fallbackTitle,
    subtitle: <String>[if (anchorName.isNotEmpty) anchorName, if (areaName.isNotEmpty) areaName].join(' · '),
    cover: cover,
    metadata: ContentMetadata(popularity: viewers),
  );

  /// The OSS thumbnail parameter, added only where the url does not already carry a query.
  static String? _thumb(Object? value) {
    final raw = '${value ?? ''}';
    if (raw.isEmpty) {
      return null;
    }
    return raw.contains('?') ? raw : '$raw$huyaCoverThumbQuery';
  }

  static int? _int(Object? value) => switch (value) {
    final num number => number.toInt(),
    final String text => int.tryParse(text.trim()),
    _ => null,
  };
}
