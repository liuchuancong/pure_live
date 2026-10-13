// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'iptv_playlist.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$IptvPlaylist {

 String get id; String get name; DateTime get importedAt; String? get url; int get channelCount;
/// Create a copy of IptvPlaylist
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$IptvPlaylistCopyWith<IptvPlaylist> get copyWith => _$IptvPlaylistCopyWithImpl<IptvPlaylist>(this as IptvPlaylist, _$identity);

  /// Serializes this IptvPlaylist to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as IptvPlaylist;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is IptvPlaylist&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.importedAt, _this.importedAt) || other.importedAt == _this.importedAt)&&(identical(other.url, _this.url) || other.url == _this.url)&&(identical(other.channelCount, _this.channelCount) || other.channelCount == _this.channelCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as IptvPlaylist;
  return Object.hash(runtimeType,_this.id,_this.name,_this.importedAt,_this.url,_this.channelCount);
}

@override
String toString() {
  final _this = this as IptvPlaylist;
  return 'IptvPlaylist(id: ${_this.id}, name: ${_this.name}, importedAt: ${_this.importedAt}, url: ${_this.url}, channelCount: ${_this.channelCount})';
}


}

/// @nodoc
abstract mixin class $IptvPlaylistCopyWith<$Res>  {
  factory $IptvPlaylistCopyWith(IptvPlaylist value, $Res Function(IptvPlaylist) _then) = _$IptvPlaylistCopyWithImpl;
@useResult
$Res call({
 String id, String name, DateTime importedAt, String? url, int channelCount
});




}
/// @nodoc
class _$IptvPlaylistCopyWithImpl<$Res>
    implements $IptvPlaylistCopyWith<$Res> {
  _$IptvPlaylistCopyWithImpl(this._self, this._then);

  final IptvPlaylist _self;
  final $Res Function(IptvPlaylist) _then;

/// Create a copy of IptvPlaylist
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? importedAt = null,Object? url = freezed,Object? channelCount = null,}) {
  return _then(IptvPlaylist(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,importedAt: null == importedAt ? _self.importedAt : importedAt // ignore: cast_nullable_to_non_nullable
as DateTime,url: freezed == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String?,channelCount: null == channelCount ? _self.channelCount : channelCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [IptvPlaylist].
extension IptvPlaylistPatterns on IptvPlaylist {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _IptvPlaylist value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _IptvPlaylist() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _IptvPlaylist value)  $default,){
final _that = this;
switch (_that) {
case _IptvPlaylist():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _IptvPlaylist value)?  $default,){
final _that = this;
switch (_that) {
case _IptvPlaylist() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  DateTime importedAt,  String? url,  int channelCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _IptvPlaylist() when $default != null:
return $default(_that.id,_that.name,_that.importedAt,_that.url,_that.channelCount);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  DateTime importedAt,  String? url,  int channelCount)  $default,) {final _that = this;
switch (_that) {
case _IptvPlaylist():
return $default(_that.id,_that.name,_that.importedAt,_that.url,_that.channelCount);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  DateTime importedAt,  String? url,  int channelCount)?  $default,) {final _that = this;
switch (_that) {
case _IptvPlaylist() when $default != null:
return $default(_that.id,_that.name,_that.importedAt,_that.url,_that.channelCount);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _IptvPlaylist implements IptvPlaylist {
  const _IptvPlaylist({required this.id, required this.name, required this.importedAt, this.url, this.channelCount = 0});
  factory _IptvPlaylist.fromJson(Map<String, dynamic> json) => _$IptvPlaylistFromJson(json);

@override final  String id;
@override final  String name;
@override final  DateTime importedAt;
@override final  String? url;
@override@JsonKey() final  int channelCount;

/// Create a copy of IptvPlaylist
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$IptvPlaylistCopyWith<_IptvPlaylist> get copyWith => __$IptvPlaylistCopyWithImpl<_IptvPlaylist>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$IptvPlaylistToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _IptvPlaylist&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.importedAt, importedAt) || other.importedAt == importedAt)&&(identical(other.url, url) || other.url == url)&&(identical(other.channelCount, channelCount) || other.channelCount == channelCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,name,importedAt,url,channelCount);
}

@override
String toString() {
    return 'IptvPlaylist(id: $id, name: $name, importedAt: $importedAt, url: $url, channelCount: $channelCount)';
}


}

/// @nodoc
abstract mixin class _$IptvPlaylistCopyWith<$Res> implements $IptvPlaylistCopyWith<$Res> {
  factory _$IptvPlaylistCopyWith(_IptvPlaylist value, $Res Function(_IptvPlaylist) _then) = __$IptvPlaylistCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, DateTime importedAt, String? url, int channelCount
});




}
/// @nodoc
class __$IptvPlaylistCopyWithImpl<$Res>
    implements _$IptvPlaylistCopyWith<$Res> {
  __$IptvPlaylistCopyWithImpl(this._self, this._then);

  final _IptvPlaylist _self;
  final $Res Function(_IptvPlaylist) _then;

/// Create a copy of IptvPlaylist
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? importedAt = null,Object? url = freezed,Object? channelCount = null,}) {
  return _then(_IptvPlaylist(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,importedAt: null == importedAt ? _self.importedAt : importedAt // ignore: cast_nullable_to_non_nullable
as DateTime,url: freezed == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String?,channelCount: null == channelCount ? _self.channelCount : channelCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
