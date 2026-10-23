// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_page.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$LivePage<T> extends LivePage<T> {
  @override
  final BuiltList<T> items;
  @override
  final int? totalCount;
  @override
  final String? nextCursor;
  @override
  final bool? hasMore;

  factory _$LivePage([void Function(LivePageBuilder<T>)? updates]) => (LivePageBuilder<T>()..update(updates))._build();

  _$LivePage._({required this.items, this.totalCount, this.nextCursor, this.hasMore}) : super._();
  @override
  LivePage<T> rebuild(void Function(LivePageBuilder<T>) updates) => (toBuilder()..update(updates)).build();

  @override
  LivePageBuilder<T> toBuilder() => LivePageBuilder<T>()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is LivePage &&
        items == other.items &&
        totalCount == other.totalCount &&
        nextCursor == other.nextCursor &&
        hasMore == other.hasMore;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, items.hashCode);
    _$hash = $jc(_$hash, totalCount.hashCode);
    _$hash = $jc(_$hash, nextCursor.hashCode);
    _$hash = $jc(_$hash, hasMore.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'LivePage')
          ..add('items', items)
          ..add('totalCount', totalCount)
          ..add('nextCursor', nextCursor)
          ..add('hasMore', hasMore))
        .toString();
  }
}

class LivePageBuilder<T> implements Builder<LivePage<T>, LivePageBuilder<T>> {
  _$LivePage<T>? _$v;

  ListBuilder<T>? _items;
  ListBuilder<T> get items => _$this._items ??= ListBuilder<T>();
  set items(ListBuilder<T>? items) => _$this._items = items;

  int? _totalCount;
  int? get totalCount => _$this._totalCount;
  set totalCount(int? totalCount) => _$this._totalCount = totalCount;

  String? _nextCursor;
  String? get nextCursor => _$this._nextCursor;
  set nextCursor(String? nextCursor) => _$this._nextCursor = nextCursor;

  bool? _hasMore;
  bool? get hasMore => _$this._hasMore;
  set hasMore(bool? hasMore) => _$this._hasMore = hasMore;

  LivePageBuilder();

  LivePageBuilder<T> get _$this {
    final $v = _$v;
    if ($v != null) {
      _items = $v.items.toBuilder();
      _totalCount = $v.totalCount;
      _nextCursor = $v.nextCursor;
      _hasMore = $v.hasMore;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(LivePage<T> other) {
    _$v = other as _$LivePage<T>;
  }

  @override
  void update(void Function(LivePageBuilder<T>)? updates) {
    if (updates != null) updates(this);
  }

  @override
  LivePage<T> build() => _build();

  _$LivePage<T> _build() {
    _$LivePage<T> _$result;
    try {
      _$result =
          _$v ??
          _$LivePage<T>._(items: items.build(), totalCount: totalCount, nextCursor: nextCursor, hasMore: hasMore);
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'items';
        items.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(r'LivePage', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
