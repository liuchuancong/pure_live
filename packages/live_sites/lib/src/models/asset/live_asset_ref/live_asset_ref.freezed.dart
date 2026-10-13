// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'live_asset_ref.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$LiveAssetRef {

 LiveAssetType get type; String? get path; Uri? get uri; LiveAssetRef? get fallback;
/// Create a copy of LiveAssetRef
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveAssetRefCopyWith<LiveAssetRef> get copyWith => _$LiveAssetRefCopyWithImpl<LiveAssetRef>(this as LiveAssetRef, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as LiveAssetRef;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveAssetRef&&(identical(other.type, _this.type) || other.type == _this.type)&&(identical(other.path, _this.path) || other.path == _this.path)&&(identical(other.uri, _this.uri) || other.uri == _this.uri)&&(identical(other.fallback, _this.fallback) || other.fallback == _this.fallback));
}


@override
int get hashCode {
  final _this = this as LiveAssetRef;
  return Object.hash(runtimeType,_this.type,_this.path,_this.uri,_this.fallback);
}

@override
String toString() {
  final _this = this as LiveAssetRef;
  return 'LiveAssetRef(type: ${_this.type}, path: ${_this.path}, uri: ${_this.uri}, fallback: ${_this.fallback})';
}


}

/// @nodoc
abstract mixin class $LiveAssetRefCopyWith<$Res>  {
  factory $LiveAssetRefCopyWith(LiveAssetRef value, $Res Function(LiveAssetRef) _then) = _$LiveAssetRefCopyWithImpl;
@useResult
$Res call({
 LiveAssetType type, String? path, Uri? uri, LiveAssetRef? fallback
});


$LiveAssetRefCopyWith<$Res>? get fallback;

}
/// @nodoc
class _$LiveAssetRefCopyWithImpl<$Res>
    implements $LiveAssetRefCopyWith<$Res> {
  _$LiveAssetRefCopyWithImpl(this._self, this._then);

  final LiveAssetRef _self;
  final $Res Function(LiveAssetRef) _then;

/// Create a copy of LiveAssetRef
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = null,Object? path = freezed,Object? uri = freezed,Object? fallback = freezed,}) {
  return _then(LiveAssetRef(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as LiveAssetType,path: freezed == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String?,uri: freezed == uri ? _self.uri : uri // ignore: cast_nullable_to_non_nullable
as Uri?,fallback: freezed == fallback ? _self.fallback : fallback // ignore: cast_nullable_to_non_nullable
as LiveAssetRef?,
  ));
}
/// Create a copy of LiveAssetRef
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveAssetRefCopyWith<$Res>? get fallback {
    if (_self.fallback == null) {
    return null;
  }

  return $LiveAssetRefCopyWith<$Res>(_self.fallback!, (value) {
    return _then(_self.copyWith(fallback: value));
  });
}
}


/// Adds pattern-matching-related methods to [LiveAssetRef].
extension LiveAssetRefPatterns on LiveAssetRef {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveAssetRef value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveAssetRef() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveAssetRef value)  $default,){
final _that = this;
switch (_that) {
case _LiveAssetRef():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveAssetRef value)?  $default,){
final _that = this;
switch (_that) {
case _LiveAssetRef() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LiveAssetType type,  String? path,  Uri? uri,  LiveAssetRef? fallback)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveAssetRef() when $default != null:
return $default(_that.type,_that.path,_that.uri,_that.fallback);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LiveAssetType type,  String? path,  Uri? uri,  LiveAssetRef? fallback)  $default,) {final _that = this;
switch (_that) {
case _LiveAssetRef():
return $default(_that.type,_that.path,_that.uri,_that.fallback);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LiveAssetType type,  String? path,  Uri? uri,  LiveAssetRef? fallback)?  $default,) {final _that = this;
switch (_that) {
case _LiveAssetRef() when $default != null:
return $default(_that.type,_that.path,_that.uri,_that.fallback);case _:
  return null;

}
}

}

/// @nodoc


class _LiveAssetRef implements LiveAssetRef {
  const _LiveAssetRef({required this.type, this.path, this.uri, this.fallback});
  

@override final  LiveAssetType type;
@override final  String? path;
@override final  Uri? uri;
@override final  LiveAssetRef? fallback;

/// Create a copy of LiveAssetRef
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveAssetRefCopyWith<_LiveAssetRef> get copyWith => __$LiveAssetRefCopyWithImpl<_LiveAssetRef>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveAssetRef&&(identical(other.type, type) || other.type == type)&&(identical(other.path, path) || other.path == path)&&(identical(other.uri, uri) || other.uri == uri)&&(identical(other.fallback, fallback) || other.fallback == fallback));
}


@override
int get hashCode {
    return Object.hash(runtimeType,type,path,uri,fallback);
}

@override
String toString() {
    return 'LiveAssetRef(type: $type, path: $path, uri: $uri, fallback: $fallback)';
}


}

/// @nodoc
abstract mixin class _$LiveAssetRefCopyWith<$Res> implements $LiveAssetRefCopyWith<$Res> {
  factory _$LiveAssetRefCopyWith(_LiveAssetRef value, $Res Function(_LiveAssetRef) _then) = __$LiveAssetRefCopyWithImpl;
@override @useResult
$Res call({
 LiveAssetType type, String? path, Uri? uri, LiveAssetRef? fallback
});


@override $LiveAssetRefCopyWith<$Res>? get fallback;

}
/// @nodoc
class __$LiveAssetRefCopyWithImpl<$Res>
    implements _$LiveAssetRefCopyWith<$Res> {
  __$LiveAssetRefCopyWithImpl(this._self, this._then);

  final _LiveAssetRef _self;
  final $Res Function(_LiveAssetRef) _then;

/// Create a copy of LiveAssetRef
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = null,Object? path = freezed,Object? uri = freezed,Object? fallback = freezed,}) {
  return _then(_LiveAssetRef(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as LiveAssetType,path: freezed == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String?,uri: freezed == uri ? _self.uri : uri // ignore: cast_nullable_to_non_nullable
as Uri?,fallback: freezed == fallback ? _self.fallback : fallback // ignore: cast_nullable_to_non_nullable
as LiveAssetRef?,
  ));
}

/// Create a copy of LiveAssetRef
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveAssetRefCopyWith<$Res>? get fallback {
    if (_self.fallback == null) {
    return null;
  }

  return $LiveAssetRefCopyWith<$Res>(_self.fallback!, (value) {
    return _then(_self.copyWith(fallback: value));
  });
}
}

// dart format on
