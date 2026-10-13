// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'room_links.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RoomLinks {

 String? get webUrl; String? get appUrl; String? get shareUrl;
/// Create a copy of RoomLinks
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RoomLinksCopyWith<RoomLinks> get copyWith => _$RoomLinksCopyWithImpl<RoomLinks>(this as RoomLinks, _$identity);

  /// Serializes this RoomLinks to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RoomLinks;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RoomLinks&&(identical(other.webUrl, _this.webUrl) || other.webUrl == _this.webUrl)&&(identical(other.appUrl, _this.appUrl) || other.appUrl == _this.appUrl)&&(identical(other.shareUrl, _this.shareUrl) || other.shareUrl == _this.shareUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RoomLinks;
  return Object.hash(runtimeType,_this.webUrl,_this.appUrl,_this.shareUrl);
}

@override
String toString() {
  final _this = this as RoomLinks;
  return 'RoomLinks(webUrl: ${_this.webUrl}, appUrl: ${_this.appUrl}, shareUrl: ${_this.shareUrl})';
}


}

/// @nodoc
abstract mixin class $RoomLinksCopyWith<$Res>  {
  factory $RoomLinksCopyWith(RoomLinks value, $Res Function(RoomLinks) _then) = _$RoomLinksCopyWithImpl;
@useResult
$Res call({
 String? webUrl, String? appUrl, String? shareUrl
});




}
/// @nodoc
class _$RoomLinksCopyWithImpl<$Res>
    implements $RoomLinksCopyWith<$Res> {
  _$RoomLinksCopyWithImpl(this._self, this._then);

  final RoomLinks _self;
  final $Res Function(RoomLinks) _then;

/// Create a copy of RoomLinks
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? webUrl = freezed,Object? appUrl = freezed,Object? shareUrl = freezed,}) {
  return _then(RoomLinks(
webUrl: freezed == webUrl ? _self.webUrl : webUrl // ignore: cast_nullable_to_non_nullable
as String?,appUrl: freezed == appUrl ? _self.appUrl : appUrl // ignore: cast_nullable_to_non_nullable
as String?,shareUrl: freezed == shareUrl ? _self.shareUrl : shareUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [RoomLinks].
extension RoomLinksPatterns on RoomLinks {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RoomLinks value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RoomLinks() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RoomLinks value)  $default,){
final _that = this;
switch (_that) {
case _RoomLinks():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RoomLinks value)?  $default,){
final _that = this;
switch (_that) {
case _RoomLinks() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? webUrl,  String? appUrl,  String? shareUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RoomLinks() when $default != null:
return $default(_that.webUrl,_that.appUrl,_that.shareUrl);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? webUrl,  String? appUrl,  String? shareUrl)  $default,) {final _that = this;
switch (_that) {
case _RoomLinks():
return $default(_that.webUrl,_that.appUrl,_that.shareUrl);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? webUrl,  String? appUrl,  String? shareUrl)?  $default,) {final _that = this;
switch (_that) {
case _RoomLinks() when $default != null:
return $default(_that.webUrl,_that.appUrl,_that.shareUrl);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RoomLinks implements RoomLinks {
  const _RoomLinks({this.webUrl, this.appUrl, this.shareUrl});
  factory _RoomLinks.fromJson(Map<String, dynamic> json) => _$RoomLinksFromJson(json);

@override final  String? webUrl;
@override final  String? appUrl;
@override final  String? shareUrl;

/// Create a copy of RoomLinks
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RoomLinksCopyWith<_RoomLinks> get copyWith => __$RoomLinksCopyWithImpl<_RoomLinks>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RoomLinksToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RoomLinks&&(identical(other.webUrl, webUrl) || other.webUrl == webUrl)&&(identical(other.appUrl, appUrl) || other.appUrl == appUrl)&&(identical(other.shareUrl, shareUrl) || other.shareUrl == shareUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,webUrl,appUrl,shareUrl);
}

@override
String toString() {
    return 'RoomLinks(webUrl: $webUrl, appUrl: $appUrl, shareUrl: $shareUrl)';
}


}

/// @nodoc
abstract mixin class _$RoomLinksCopyWith<$Res> implements $RoomLinksCopyWith<$Res> {
  factory _$RoomLinksCopyWith(_RoomLinks value, $Res Function(_RoomLinks) _then) = __$RoomLinksCopyWithImpl;
@override @useResult
$Res call({
 String? webUrl, String? appUrl, String? shareUrl
});




}
/// @nodoc
class __$RoomLinksCopyWithImpl<$Res>
    implements _$RoomLinksCopyWith<$Res> {
  __$RoomLinksCopyWithImpl(this._self, this._then);

  final _RoomLinks _self;
  final $Res Function(_RoomLinks) _then;

/// Create a copy of RoomLinks
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? webUrl = freezed,Object? appUrl = freezed,Object? shareUrl = freezed,}) {
  return _then(_RoomLinks(
webUrl: freezed == webUrl ? _self.webUrl : webUrl // ignore: cast_nullable_to_non_nullable
as String?,appUrl: freezed == appUrl ? _self.appUrl : appUrl // ignore: cast_nullable_to_non_nullable
as String?,shareUrl: freezed == shareUrl ? _self.shareUrl : shareUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
