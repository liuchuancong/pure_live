import 'package:meta/meta.dart';

/// A quality level as the platform names and numbers it.
@immutable
final class LivePlayQuality {
  /// A quality descriptor.
  const new({required this.label, this.quality, this.sort = 0, this.codec});

  /// The platform's own quality number (e.g. bilibili qn=4).
  final int? quality;

  /// Chinese display label, normalized per the platform's convention.
  final String label;

  /// Display sort order, ascending.
  final int sort;

  /// Codec restriction of this quality, when the platform splits by codec.
  final String? codec;

  @override
  String toString() => 'LivePlayQuality($label)';
}

/// A directory area (分区) with its platform id and optional parent.
@immutable
final class LiveArea {
  /// An area descriptor.
  const new({required this.id, required this.name, this.parentId, this.sort = 0});

  /// The platform's area id.
  final String id;

  /// Display name.
  final String name;

  /// The parent area id, for two-level taxonomies.
  final String? parentId;

  /// Display sort order, ascending.
  final int sort;

  @override
  String toString() => 'LiveArea($id, $name)';
}

/// A directory page: one page of rooms plus the pagination facts.
@immutable
final class LivePage<T> {
  /// A page of [items]; [hasMore] is the authoritative continuation
  /// signal, [nextPage] the page number to request next when known.
  const new({required this.items, this.hasMore = false, this.nextPage, this.totalCount});

  /// The rooms (or anchors) of this page.
  final List<T> items;

  /// Whether another page exists.
  final bool hasMore;

  /// The next page number, when the source paginates by number.
  final int? nextPage;

  /// Total matching items, when the source reports it.
  final int? totalCount;
}
