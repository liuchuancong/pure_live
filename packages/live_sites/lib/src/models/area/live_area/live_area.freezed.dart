// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'live_area.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LiveArea {

 String get platform; String get areaId; String get areaName; String? get parentAreaId; String? get parentAreaName; String? get iconUrl; String? get shortName; int? get position;
/// Create a copy of LiveArea
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveAreaCopyWith<LiveArea> get copyWith => _$LiveAreaCopyWithImpl<LiveArea>(this as LiveArea, _$identity);

  /// Serializes this LiveArea to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LiveArea;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveArea&&(identical(other.platform, _this.platform) || other.platform == _this.platform)&&(identical(other.areaId, _this.areaId) || other.areaId == _this.areaId)&&(identical(other.areaName, _this.areaName) || other.areaName == _this.areaName)&&(identical(other.parentAreaId, _this.parentAreaId) || other.parentAreaId == _this.parentAreaId)&&(identical(other.parentAreaName, _this.parentAreaName) || other.parentAreaName == _this.parentAreaName)&&(identical(other.iconUrl, _this.iconUrl) || other.iconUrl == _this.iconUrl)&&(identical(other.shortName, _this.shortName) || other.shortName == _this.shortName)&&(identical(other.position, _this.position) || other.position == _this.position));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LiveArea;
  return Object.hash(runtimeType,_this.platform,_this.areaId,_this.areaName,_this.parentAreaId,_this.parentAreaName,_this.iconUrl,_this.shortName,_this.position);
}

@override
String toString() {
  final _this = this as LiveArea;
  return 'LiveArea(platform: ${_this.platform}, areaId: ${_this.areaId}, areaName: ${_this.areaName}, parentAreaId: ${_this.parentAreaId}, parentAreaName: ${_this.parentAreaName}, iconUrl: ${_this.iconUrl}, shortName: ${_this.shortName}, position: ${_this.position})';
}


}

/// @nodoc
abstract mixin class $LiveAreaCopyWith<$Res>  {
  factory $LiveAreaCopyWith(LiveArea value, $Res Function(LiveArea) _then) = _$LiveAreaCopyWithImpl;
@useResult
$Res call({
 String platform, String areaId, String areaName, String? parentAreaId, String? parentAreaName, String? iconUrl, String? shortName, int? position
});




}
/// @nodoc
class _$LiveAreaCopyWithImpl<$Res>
    implements $LiveAreaCopyWith<$Res> {
  _$LiveAreaCopyWithImpl(this._self, this._then);

  final LiveArea _self;
  final $Res Function(LiveArea) _then;

/// Create a copy of LiveArea
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? platform = null,Object? areaId = null,Object? areaName = null,Object? parentAreaId = freezed,Object? parentAreaName = freezed,Object? iconUrl = freezed,Object? shortName = freezed,Object? position = freezed,}) {
  return _then(LiveArea(
platform: null == platform ? _self.platform : platform // ignore: cast_nullable_to_non_nullable
as String,areaId: null == areaId ? _self.areaId : areaId // ignore: cast_nullable_to_non_nullable
as String,areaName: null == areaName ? _self.areaName : areaName // ignore: cast_nullable_to_non_nullable
as String,parentAreaId: freezed == parentAreaId ? _self.parentAreaId : parentAreaId // ignore: cast_nullable_to_non_nullable
as String?,parentAreaName: freezed == parentAreaName ? _self.parentAreaName : parentAreaName // ignore: cast_nullable_to_non_nullable
as String?,iconUrl: freezed == iconUrl ? _self.iconUrl : iconUrl // ignore: cast_nullable_to_non_nullable
as String?,shortName: freezed == shortName ? _self.shortName : shortName // ignore: cast_nullable_to_non_nullable
as String?,position: freezed == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [LiveArea].
extension LiveAreaPatterns on LiveArea {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveArea value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveArea() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveArea value)  $default,){
final _that = this;
switch (_that) {
case _LiveArea():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveArea value)?  $default,){
final _that = this;
switch (_that) {
case _LiveArea() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String platform,  String areaId,  String areaName,  String? parentAreaId,  String? parentAreaName,  String? iconUrl,  String? shortName,  int? position)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveArea() when $default != null:
return $default(_that.platform,_that.areaId,_that.areaName,_that.parentAreaId,_that.parentAreaName,_that.iconUrl,_that.shortName,_that.position);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String platform,  String areaId,  String areaName,  String? parentAreaId,  String? parentAreaName,  String? iconUrl,  String? shortName,  int? position)  $default,) {final _that = this;
switch (_that) {
case _LiveArea():
return $default(_that.platform,_that.areaId,_that.areaName,_that.parentAreaId,_that.parentAreaName,_that.iconUrl,_that.shortName,_that.position);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String platform,  String areaId,  String areaName,  String? parentAreaId,  String? parentAreaName,  String? iconUrl,  String? shortName,  int? position)?  $default,) {final _that = this;
switch (_that) {
case _LiveArea() when $default != null:
return $default(_that.platform,_that.areaId,_that.areaName,_that.parentAreaId,_that.parentAreaName,_that.iconUrl,_that.shortName,_that.position);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveArea implements LiveArea {
  const _LiveArea({this.platform = '', this.areaId = '', this.areaName = '', this.parentAreaId, this.parentAreaName, this.iconUrl, this.shortName, this.position});
  factory _LiveArea.fromJson(Map<String, dynamic> json) => _$LiveAreaFromJson(json);

@override@JsonKey() final  String platform;
@override@JsonKey() final  String areaId;
@override@JsonKey() final  String areaName;
@override final  String? parentAreaId;
@override final  String? parentAreaName;
@override final  String? iconUrl;
@override final  String? shortName;
@override final  int? position;

/// Create a copy of LiveArea
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveAreaCopyWith<_LiveArea> get copyWith => __$LiveAreaCopyWithImpl<_LiveArea>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LiveAreaToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveArea&&(identical(other.platform, platform) || other.platform == platform)&&(identical(other.areaId, areaId) || other.areaId == areaId)&&(identical(other.areaName, areaName) || other.areaName == areaName)&&(identical(other.parentAreaId, parentAreaId) || other.parentAreaId == parentAreaId)&&(identical(other.parentAreaName, parentAreaName) || other.parentAreaName == parentAreaName)&&(identical(other.iconUrl, iconUrl) || other.iconUrl == iconUrl)&&(identical(other.shortName, shortName) || other.shortName == shortName)&&(identical(other.position, position) || other.position == position));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,platform,areaId,areaName,parentAreaId,parentAreaName,iconUrl,shortName,position);
}

@override
String toString() {
    return 'LiveArea(platform: $platform, areaId: $areaId, areaName: $areaName, parentAreaId: $parentAreaId, parentAreaName: $parentAreaName, iconUrl: $iconUrl, shortName: $shortName, position: $position)';
}


}

/// @nodoc
abstract mixin class _$LiveAreaCopyWith<$Res> implements $LiveAreaCopyWith<$Res> {
  factory _$LiveAreaCopyWith(_LiveArea value, $Res Function(_LiveArea) _then) = __$LiveAreaCopyWithImpl;
@override @useResult
$Res call({
 String platform, String areaId, String areaName, String? parentAreaId, String? parentAreaName, String? iconUrl, String? shortName, int? position
});




}
/// @nodoc
class __$LiveAreaCopyWithImpl<$Res>
    implements _$LiveAreaCopyWith<$Res> {
  __$LiveAreaCopyWithImpl(this._self, this._then);

  final _LiveArea _self;
  final $Res Function(_LiveArea) _then;

/// Create a copy of LiveArea
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? platform = null,Object? areaId = null,Object? areaName = null,Object? parentAreaId = freezed,Object? parentAreaName = freezed,Object? iconUrl = freezed,Object? shortName = freezed,Object? position = freezed,}) {
  return _then(_LiveArea(
platform: null == platform ? _self.platform : platform // ignore: cast_nullable_to_non_nullable
as String,areaId: null == areaId ? _self.areaId : areaId // ignore: cast_nullable_to_non_nullable
as String,areaName: null == areaName ? _self.areaName : areaName // ignore: cast_nullable_to_non_nullable
as String,parentAreaId: freezed == parentAreaId ? _self.parentAreaId : parentAreaId // ignore: cast_nullable_to_non_nullable
as String?,parentAreaName: freezed == parentAreaName ? _self.parentAreaName : parentAreaName // ignore: cast_nullable_to_non_nullable
as String?,iconUrl: freezed == iconUrl ? _self.iconUrl : iconUrl // ignore: cast_nullable_to_non_nullable
as String?,shortName: freezed == shortName ? _self.shortName : shortName // ignore: cast_nullable_to_non_nullable
as String?,position: freezed == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
