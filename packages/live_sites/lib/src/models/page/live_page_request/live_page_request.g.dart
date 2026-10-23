// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_page_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$LivePageRequest extends LivePageRequest {
  @override
  final int page;
  @override
  final int pageSize;
  @override
  final int? offset;
  @override
  final String? cursor;

  factory _$LivePageRequest([void Function(LivePageRequestBuilder)? updates]) =>
      (LivePageRequestBuilder()..update(updates))._build();

  _$LivePageRequest._({required this.page, required this.pageSize, this.offset, this.cursor}) : super._();
  @override
  LivePageRequest rebuild(void Function(LivePageRequestBuilder) updates) => (toBuilder()..update(updates)).build();

  @override
  LivePageRequestBuilder toBuilder() => LivePageRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is LivePageRequest &&
        page == other.page &&
        pageSize == other.pageSize &&
        offset == other.offset &&
        cursor == other.cursor;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, page.hashCode);
    _$hash = $jc(_$hash, pageSize.hashCode);
    _$hash = $jc(_$hash, offset.hashCode);
    _$hash = $jc(_$hash, cursor.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'LivePageRequest')
          ..add('page', page)
          ..add('pageSize', pageSize)
          ..add('offset', offset)
          ..add('cursor', cursor))
        .toString();
  }
}

class LivePageRequestBuilder implements Builder<LivePageRequest, LivePageRequestBuilder> {
  _$LivePageRequest? _$v;

  int? _page;
  int? get page => _$this._page;
  set page(int? page) => _$this._page = page;

  int? _pageSize;
  int? get pageSize => _$this._pageSize;
  set pageSize(int? pageSize) => _$this._pageSize = pageSize;

  int? _offset;
  int? get offset => _$this._offset;
  set offset(int? offset) => _$this._offset = offset;

  String? _cursor;
  String? get cursor => _$this._cursor;
  set cursor(String? cursor) => _$this._cursor = cursor;

  LivePageRequestBuilder() {
    LivePageRequest._initialize(this);
  }

  LivePageRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _page = $v.page;
      _pageSize = $v.pageSize;
      _offset = $v.offset;
      _cursor = $v.cursor;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(LivePageRequest other) {
    _$v = other as _$LivePageRequest;
  }

  @override
  void update(void Function(LivePageRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  LivePageRequest build() => _build();

  _$LivePageRequest _build() {
    final _$result =
        _$v ??
        _$LivePageRequest._(
          page: BuiltValueNullFieldError.checkNotNull(page, r'LivePageRequest', 'page'),
          pageSize: BuiltValueNullFieldError.checkNotNull(pageSize, r'LivePageRequest', 'pageSize'),
          offset: offset,
          cursor: cursor,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
