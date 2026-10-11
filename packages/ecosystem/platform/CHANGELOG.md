# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased

- **Added**: `models/live/` as the live domain's own model home. `LiveRoom`, `LiveRoomStatus`, `LiveRoomState`,
  `AnchorSummary`, `DanmakuMessage` and `DanmakuKind` moved out of `models/content/` and `models/media/`, where
  they were mixed in with the generic and the点播 shapes. A room's facts had been travelling as
  `metadata.extra` string keys that each site spelled its own way; `LiveRoom` gives them fields, and derives
  `summary` / `anchor()` from them instead of the other way round.
- **Added**: `LiveRoom` and the two anchor/danmaku models as freezed + json_annotation, generated files
  colocated. `ContentKind.anchor` exists now: the person is not whoever happens to be streaming in their room.
- **Fixed**: a nested `ContentRef` in a generated model was written into `toJson()` as the **object**
  (`'ref': instance.ref`). `jsonEncode` survives that by accident; our storage does not — the repositories persist
  the map itself, and reading it back threw at `json['ref'] as Map<String, dynamic>`. `refFromJson` / `refToJson`
  are now the paired converters every model hangs on a ref field, pinned by round-trip tests on both sides.
- Skeleton created for layer ecosystem as `pure_live_platform`: no dependencies and no implementation yet.
