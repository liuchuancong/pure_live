// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'live_badge.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LiveBadge {

 String get url; String get id;
/// Create a copy of LiveBadge
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveBadgeCopyWith<LiveBadge> get copyWith => _$LiveBadgeCopyWithImpl<LiveBadge>(this as LiveBadge, _$identity);

  /// Serializes this LiveBadge to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LiveBadge;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveBadge&&(identical(other.url, _this.url) || other.url == _this.url)&&(identical(other.id, _this.id) || other.id == _this.id));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LiveBadge;
  return Object.hash(runtimeType,_this.url,_this.id);
}

@override
String toString() {
  final _this = this as LiveBadge;
  return 'LiveBadge(url: ${_this.url}, id: ${_this.id})';
}


}

/// @nodoc
abstract mixin class $LiveBadgeCopyWith<$Res>  {
  factory $LiveBadgeCopyWith(LiveBadge value, $Res Function(LiveBadge) _then) = _$LiveBadgeCopyWithImpl;
@useResult
$Res call({
 String url, String id
});




}
/// @nodoc
class _$LiveBadgeCopyWithImpl<$Res>
    implements $LiveBadgeCopyWith<$Res> {
  _$LiveBadgeCopyWithImpl(this._self, this._then);

  final LiveBadge _self;
  final $Res Function(LiveBadge) _then;

/// Create a copy of LiveBadge
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? url = null,Object? id = null,}) {
  return _then(LiveBadge(
url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [LiveBadge].
extension LiveBadgePatterns on LiveBadge {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveBadge value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveBadge() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveBadge value)  $default,){
final _that = this;
switch (_that) {
case _LiveBadge():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveBadge value)?  $default,){
final _that = this;
switch (_that) {
case _LiveBadge() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String url,  String id)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveBadge() when $default != null:
return $default(_that.url,_that.id);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String url,  String id)  $default,) {final _that = this;
switch (_that) {
case _LiveBadge():
return $default(_that.url,_that.id);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String url,  String id)?  $default,) {final _that = this;
switch (_that) {
case _LiveBadge() when $default != null:
return $default(_that.url,_that.id);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveBadge implements LiveBadge {
  const _LiveBadge({required this.url, this.id = ''});
  factory _LiveBadge.fromJson(Map<String, dynamic> json) => _$LiveBadgeFromJson(json);

@override final  String url;
@override@JsonKey() final  String id;

/// Create a copy of LiveBadge
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveBadgeCopyWith<_LiveBadge> get copyWith => __$LiveBadgeCopyWithImpl<_LiveBadge>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LiveBadgeToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveBadge&&(identical(other.url, url) || other.url == url)&&(identical(other.id, id) || other.id == id));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,url,id);
}

@override
String toString() {
    return 'LiveBadge(url: $url, id: $id)';
}


}

/// @nodoc
abstract mixin class _$LiveBadgeCopyWith<$Res> implements $LiveBadgeCopyWith<$Res> {
  factory _$LiveBadgeCopyWith(_LiveBadge value, $Res Function(_LiveBadge) _then) = __$LiveBadgeCopyWithImpl;
@override @useResult
$Res call({
 String url, String id
});




}
/// @nodoc
class __$LiveBadgeCopyWithImpl<$Res>
    implements _$LiveBadgeCopyWith<$Res> {
  __$LiveBadgeCopyWithImpl(this._self, this._then);

  final _LiveBadge _self;
  final $Res Function(_LiveBadge) _then;

/// Create a copy of LiveBadge
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? url = null,Object? id = null,}) {
  return _then(_LiveBadge(
url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
