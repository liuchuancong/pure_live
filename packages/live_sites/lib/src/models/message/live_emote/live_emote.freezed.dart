// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'live_emote.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LiveEmote {

 String get code; String get url;
/// Create a copy of LiveEmote
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveEmoteCopyWith<LiveEmote> get copyWith => _$LiveEmoteCopyWithImpl<LiveEmote>(this as LiveEmote, _$identity);

  /// Serializes this LiveEmote to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LiveEmote;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveEmote&&(identical(other.code, _this.code) || other.code == _this.code)&&(identical(other.url, _this.url) || other.url == _this.url));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LiveEmote;
  return Object.hash(runtimeType,_this.code,_this.url);
}

@override
String toString() {
  final _this = this as LiveEmote;
  return 'LiveEmote(code: ${_this.code}, url: ${_this.url})';
}


}

/// @nodoc
abstract mixin class $LiveEmoteCopyWith<$Res>  {
  factory $LiveEmoteCopyWith(LiveEmote value, $Res Function(LiveEmote) _then) = _$LiveEmoteCopyWithImpl;
@useResult
$Res call({
 String code, String url
});




}
/// @nodoc
class _$LiveEmoteCopyWithImpl<$Res>
    implements $LiveEmoteCopyWith<$Res> {
  _$LiveEmoteCopyWithImpl(this._self, this._then);

  final LiveEmote _self;
  final $Res Function(LiveEmote) _then;

/// Create a copy of LiveEmote
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? code = null,Object? url = null,}) {
  return _then(LiveEmote(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [LiveEmote].
extension LiveEmotePatterns on LiveEmote {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveEmote value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveEmote() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveEmote value)  $default,){
final _that = this;
switch (_that) {
case _LiveEmote():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveEmote value)?  $default,){
final _that = this;
switch (_that) {
case _LiveEmote() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String code,  String url)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveEmote() when $default != null:
return $default(_that.code,_that.url);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String code,  String url)  $default,) {final _that = this;
switch (_that) {
case _LiveEmote():
return $default(_that.code,_that.url);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String code,  String url)?  $default,) {final _that = this;
switch (_that) {
case _LiveEmote() when $default != null:
return $default(_that.code,_that.url);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveEmote implements LiveEmote {
  const _LiveEmote({required this.code, required this.url});
  factory _LiveEmote.fromJson(Map<String, dynamic> json) => _$LiveEmoteFromJson(json);

@override final  String code;
@override final  String url;

/// Create a copy of LiveEmote
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveEmoteCopyWith<_LiveEmote> get copyWith => __$LiveEmoteCopyWithImpl<_LiveEmote>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LiveEmoteToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveEmote&&(identical(other.code, code) || other.code == code)&&(identical(other.url, url) || other.url == url));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,code,url);
}

@override
String toString() {
    return 'LiveEmote(code: $code, url: $url)';
}


}

/// @nodoc
abstract mixin class _$LiveEmoteCopyWith<$Res> implements $LiveEmoteCopyWith<$Res> {
  factory _$LiveEmoteCopyWith(_LiveEmote value, $Res Function(_LiveEmote) _then) = __$LiveEmoteCopyWithImpl;
@override @useResult
$Res call({
 String code, String url
});




}
/// @nodoc
class __$LiveEmoteCopyWithImpl<$Res>
    implements _$LiveEmoteCopyWith<$Res> {
  __$LiveEmoteCopyWithImpl(this._self, this._then);

  final _LiveEmote _self;
  final $Res Function(_LiveEmote) _then;

/// Create a copy of LiveEmote
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? code = null,Object? url = null,}) {
  return _then(_LiveEmote(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
