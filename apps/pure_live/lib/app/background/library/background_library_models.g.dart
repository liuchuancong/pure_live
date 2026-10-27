// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'background_library_models.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$WallpaperCategory extends WallpaperCategory {
  @override
  final WallpaperCategoryId id;
  @override
  final String query;

  factory _$WallpaperCategory([void Function(WallpaperCategoryBuilder)? updates]) =>
      (WallpaperCategoryBuilder()..update(updates))._build();

  _$WallpaperCategory._({required this.id, required this.query}) : super._();
  @override
  WallpaperCategory rebuild(void Function(WallpaperCategoryBuilder) updates) => (toBuilder()..update(updates)).build();

  @override
  WallpaperCategoryBuilder toBuilder() => WallpaperCategoryBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is WallpaperCategory && id == other.id && query == other.query;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, id.hashCode);
    _$hash = $jc(_$hash, query.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'WallpaperCategory')
          ..add('id', id)
          ..add('query', query))
        .toString();
  }
}

class WallpaperCategoryBuilder implements Builder<WallpaperCategory, WallpaperCategoryBuilder> {
  _$WallpaperCategory? _$v;

  WallpaperCategoryId? _id;
  WallpaperCategoryId? get id => _$this._id;
  set id(WallpaperCategoryId? id) => _$this._id = id;

  String? _query;
  String? get query => _$this._query;
  set query(String? query) => _$this._query = query;

  WallpaperCategoryBuilder();

  WallpaperCategoryBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _id = $v.id;
      _query = $v.query;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(WallpaperCategory other) {
    _$v = other as _$WallpaperCategory;
  }

  @override
  void update(void Function(WallpaperCategoryBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  WallpaperCategory build() => _build();

  _$WallpaperCategory _build() {
    final _$result =
        _$v ??
        _$WallpaperCategory._(
          id: BuiltValueNullFieldError.checkNotNull(id, r'WallpaperCategory', 'id'),
          query: BuiltValueNullFieldError.checkNotNull(query, r'WallpaperCategory', 'query'),
        );
    replace(_$result);
    return _$result;
  }
}

class _$WallpaperSource extends WallpaperSource {
  @override
  final WallpaperSourceId id;
  @override
  final int pageSize;
  @override
  final BuiltList<WallpaperCategory> categories;

  factory _$WallpaperSource([void Function(WallpaperSourceBuilder)? updates]) =>
      (WallpaperSourceBuilder()..update(updates))._build();

  _$WallpaperSource._({required this.id, required this.pageSize, required this.categories}) : super._();
  @override
  WallpaperSource rebuild(void Function(WallpaperSourceBuilder) updates) => (toBuilder()..update(updates)).build();

  @override
  WallpaperSourceBuilder toBuilder() => WallpaperSourceBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is WallpaperSource && id == other.id && pageSize == other.pageSize && categories == other.categories;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, id.hashCode);
    _$hash = $jc(_$hash, pageSize.hashCode);
    _$hash = $jc(_$hash, categories.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'WallpaperSource')
          ..add('id', id)
          ..add('pageSize', pageSize)
          ..add('categories', categories))
        .toString();
  }
}

class WallpaperSourceBuilder implements Builder<WallpaperSource, WallpaperSourceBuilder> {
  _$WallpaperSource? _$v;

  WallpaperSourceId? _id;
  WallpaperSourceId? get id => _$this._id;
  set id(WallpaperSourceId? id) => _$this._id = id;

  int? _pageSize;
  int? get pageSize => _$this._pageSize;
  set pageSize(int? pageSize) => _$this._pageSize = pageSize;

  ListBuilder<WallpaperCategory>? _categories;
  ListBuilder<WallpaperCategory> get categories => _$this._categories ??= ListBuilder<WallpaperCategory>();
  set categories(ListBuilder<WallpaperCategory>? categories) => _$this._categories = categories;

  WallpaperSourceBuilder();

  WallpaperSourceBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _id = $v.id;
      _pageSize = $v.pageSize;
      _categories = $v.categories.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(WallpaperSource other) {
    _$v = other as _$WallpaperSource;
  }

  @override
  void update(void Function(WallpaperSourceBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  WallpaperSource build() => _build();

  _$WallpaperSource _build() {
    _$WallpaperSource _$result;
    try {
      _$result =
          _$v ??
          _$WallpaperSource._(
            id: BuiltValueNullFieldError.checkNotNull(id, r'WallpaperSource', 'id'),
            pageSize: BuiltValueNullFieldError.checkNotNull(pageSize, r'WallpaperSource', 'pageSize'),
            categories: categories.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'categories';
        categories.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(r'WallpaperSource', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

class _$WallpaperItem extends WallpaperItem {
  @override
  final String id;
  @override
  final String name;
  @override
  final String url;
  @override
  final String thumb;
  @override
  final bool video;

  factory _$WallpaperItem([void Function(WallpaperItemBuilder)? updates]) =>
      (WallpaperItemBuilder()..update(updates))._build();

  _$WallpaperItem._({required this.id, required this.name, required this.url, required this.thumb, required this.video})
    : super._();
  @override
  WallpaperItem rebuild(void Function(WallpaperItemBuilder) updates) => (toBuilder()..update(updates)).build();

  @override
  WallpaperItemBuilder toBuilder() => WallpaperItemBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is WallpaperItem &&
        id == other.id &&
        name == other.name &&
        url == other.url &&
        thumb == other.thumb &&
        video == other.video;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, id.hashCode);
    _$hash = $jc(_$hash, name.hashCode);
    _$hash = $jc(_$hash, url.hashCode);
    _$hash = $jc(_$hash, thumb.hashCode);
    _$hash = $jc(_$hash, video.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'WallpaperItem')
          ..add('id', id)
          ..add('name', name)
          ..add('url', url)
          ..add('thumb', thumb)
          ..add('video', video))
        .toString();
  }
}

class WallpaperItemBuilder implements Builder<WallpaperItem, WallpaperItemBuilder> {
  _$WallpaperItem? _$v;

  String? _id;
  String? get id => _$this._id;
  set id(String? id) => _$this._id = id;

  String? _name;
  String? get name => _$this._name;
  set name(String? name) => _$this._name = name;

  String? _url;
  String? get url => _$this._url;
  set url(String? url) => _$this._url = url;

  String? _thumb;
  String? get thumb => _$this._thumb;
  set thumb(String? thumb) => _$this._thumb = thumb;

  bool? _video;
  bool? get video => _$this._video;
  set video(bool? video) => _$this._video = video;

  WallpaperItemBuilder();

  WallpaperItemBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _id = $v.id;
      _name = $v.name;
      _url = $v.url;
      _thumb = $v.thumb;
      _video = $v.video;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(WallpaperItem other) {
    _$v = other as _$WallpaperItem;
  }

  @override
  void update(void Function(WallpaperItemBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  WallpaperItem build() => _build();

  _$WallpaperItem _build() {
    final _$result =
        _$v ??
        _$WallpaperItem._(
          id: BuiltValueNullFieldError.checkNotNull(id, r'WallpaperItem', 'id'),
          name: BuiltValueNullFieldError.checkNotNull(name, r'WallpaperItem', 'name'),
          url: BuiltValueNullFieldError.checkNotNull(url, r'WallpaperItem', 'url'),
          thumb: BuiltValueNullFieldError.checkNotNull(thumb, r'WallpaperItem', 'thumb'),
          video: BuiltValueNullFieldError.checkNotNull(video, r'WallpaperItem', 'video'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
