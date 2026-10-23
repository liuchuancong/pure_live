// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_search_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$LiveSearchRequest extends LiveSearchRequest {
  @override
  final String query;
  @override
  final LiveSearchTarget target;
  @override
  final int page;
  @override
  final int pageSize;

  factory _$LiveSearchRequest([
    void Function(LiveSearchRequestBuilder)? updates,
  ]) => (LiveSearchRequestBuilder()..update(updates))._build();

  _$LiveSearchRequest._({
    required this.query,
    required this.target,
    required this.page,
    required this.pageSize,
  }) : super._();
  @override
  LiveSearchRequest rebuild(void Function(LiveSearchRequestBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  LiveSearchRequestBuilder toBuilder() =>
      LiveSearchRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is LiveSearchRequest &&
        query == other.query &&
        target == other.target &&
        page == other.page &&
        pageSize == other.pageSize;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, query.hashCode);
    _$hash = $jc(_$hash, target.hashCode);
    _$hash = $jc(_$hash, page.hashCode);
    _$hash = $jc(_$hash, pageSize.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'LiveSearchRequest')
          ..add('query', query)
          ..add('target', target)
          ..add('page', page)
          ..add('pageSize', pageSize))
        .toString();
  }
}

class LiveSearchRequestBuilder
    implements Builder<LiveSearchRequest, LiveSearchRequestBuilder> {
  _$LiveSearchRequest? _$v;

  String? _query;
  String? get query => _$this._query;
  set query(String? query) => _$this._query = query;

  LiveSearchTarget? _target;
  LiveSearchTarget? get target => _$this._target;
  set target(LiveSearchTarget? target) => _$this._target = target;

  int? _page;
  int? get page => _$this._page;
  set page(int? page) => _$this._page = page;

  int? _pageSize;
  int? get pageSize => _$this._pageSize;
  set pageSize(int? pageSize) => _$this._pageSize = pageSize;

  LiveSearchRequestBuilder() {
    LiveSearchRequest._initialize(this);
  }

  LiveSearchRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _query = $v.query;
      _target = $v.target;
      _page = $v.page;
      _pageSize = $v.pageSize;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(LiveSearchRequest other) {
    _$v = other as _$LiveSearchRequest;
  }

  @override
  void update(void Function(LiveSearchRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  LiveSearchRequest build() => _build();

  _$LiveSearchRequest _build() {
    final _$result =
        _$v ??
        _$LiveSearchRequest._(
          query: BuiltValueNullFieldError.checkNotNull(
            query,
            r'LiveSearchRequest',
            'query',
          ),
          target: BuiltValueNullFieldError.checkNotNull(
            target,
            r'LiveSearchRequest',
            'target',
          ),
          page: BuiltValueNullFieldError.checkNotNull(
            page,
            r'LiveSearchRequest',
            'page',
          ),
          pageSize: BuiltValueNullFieldError.checkNotNull(
            pageSize,
            r'LiveSearchRequest',
            'pageSize',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
