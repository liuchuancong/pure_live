// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'live_anchor.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LiveAnchor {

 String get platform; String get anchorId; String get name; String? get avatarUrl; String? get profileUrl; int? get followerCount; String? get introduction; bool? get isVerified; int? get anchorLevel; LiveStatus? get liveStatus;
/// Create a copy of LiveAnchor
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveAnchorCopyWith<LiveAnchor> get copyWith => _$LiveAnchorCopyWithImpl<LiveAnchor>(this as LiveAnchor, _$identity);

  /// Serializes this LiveAnchor to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LiveAnchor;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveAnchor&&(identical(other.platform, _this.platform) || other.platform == _this.platform)&&(identical(other.anchorId, _this.anchorId) || other.anchorId == _this.anchorId)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.avatarUrl, _this.avatarUrl) || other.avatarUrl == _this.avatarUrl)&&(identical(other.profileUrl, _this.profileUrl) || other.profileUrl == _this.profileUrl)&&(identical(other.followerCount, _this.followerCount) || other.followerCount == _this.followerCount)&&(identical(other.introduction, _this.introduction) || other.introduction == _this.introduction)&&(identical(other.isVerified, _this.isVerified) || other.isVerified == _this.isVerified)&&(identical(other.anchorLevel, _this.anchorLevel) || other.anchorLevel == _this.anchorLevel)&&(identical(other.liveStatus, _this.liveStatus) || other.liveStatus == _this.liveStatus));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LiveAnchor;
  return Object.hash(runtimeType,_this.platform,_this.anchorId,_this.name,_this.avatarUrl,_this.profileUrl,_this.followerCount,_this.introduction,_this.isVerified,_this.anchorLevel,_this.liveStatus);
}

@override
String toString() {
  final _this = this as LiveAnchor;
  return 'LiveAnchor(platform: ${_this.platform}, anchorId: ${_this.anchorId}, name: ${_this.name}, avatarUrl: ${_this.avatarUrl}, profileUrl: ${_this.profileUrl}, followerCount: ${_this.followerCount}, introduction: ${_this.introduction}, isVerified: ${_this.isVerified}, anchorLevel: ${_this.anchorLevel}, liveStatus: ${_this.liveStatus})';
}


}

/// @nodoc
abstract mixin class $LiveAnchorCopyWith<$Res>  {
  factory $LiveAnchorCopyWith(LiveAnchor value, $Res Function(LiveAnchor) _then) = _$LiveAnchorCopyWithImpl;
@useResult
$Res call({
 String platform, String anchorId, String name, String? avatarUrl, String? profileUrl, int? followerCount, String? introduction, bool? isVerified, int? anchorLevel, LiveStatus? liveStatus
});




}
/// @nodoc
class _$LiveAnchorCopyWithImpl<$Res>
    implements $LiveAnchorCopyWith<$Res> {
  _$LiveAnchorCopyWithImpl(this._self, this._then);

  final LiveAnchor _self;
  final $Res Function(LiveAnchor) _then;

/// Create a copy of LiveAnchor
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? platform = null,Object? anchorId = null,Object? name = null,Object? avatarUrl = freezed,Object? profileUrl = freezed,Object? followerCount = freezed,Object? introduction = freezed,Object? isVerified = freezed,Object? anchorLevel = freezed,Object? liveStatus = freezed,}) {
  return _then(LiveAnchor(
platform: null == platform ? _self.platform : platform // ignore: cast_nullable_to_non_nullable
as String,anchorId: null == anchorId ? _self.anchorId : anchorId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,profileUrl: freezed == profileUrl ? _self.profileUrl : profileUrl // ignore: cast_nullable_to_non_nullable
as String?,followerCount: freezed == followerCount ? _self.followerCount : followerCount // ignore: cast_nullable_to_non_nullable
as int?,introduction: freezed == introduction ? _self.introduction : introduction // ignore: cast_nullable_to_non_nullable
as String?,isVerified: freezed == isVerified ? _self.isVerified : isVerified // ignore: cast_nullable_to_non_nullable
as bool?,anchorLevel: freezed == anchorLevel ? _self.anchorLevel : anchorLevel // ignore: cast_nullable_to_non_nullable
as int?,liveStatus: freezed == liveStatus ? _self.liveStatus : liveStatus // ignore: cast_nullable_to_non_nullable
as LiveStatus?,
  ));
}

}


/// Adds pattern-matching-related methods to [LiveAnchor].
extension LiveAnchorPatterns on LiveAnchor {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveAnchor value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveAnchor() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveAnchor value)  $default,){
final _that = this;
switch (_that) {
case _LiveAnchor():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveAnchor value)?  $default,){
final _that = this;
switch (_that) {
case _LiveAnchor() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String platform,  String anchorId,  String name,  String? avatarUrl,  String? profileUrl,  int? followerCount,  String? introduction,  bool? isVerified,  int? anchorLevel,  LiveStatus? liveStatus)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveAnchor() when $default != null:
return $default(_that.platform,_that.anchorId,_that.name,_that.avatarUrl,_that.profileUrl,_that.followerCount,_that.introduction,_that.isVerified,_that.anchorLevel,_that.liveStatus);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String platform,  String anchorId,  String name,  String? avatarUrl,  String? profileUrl,  int? followerCount,  String? introduction,  bool? isVerified,  int? anchorLevel,  LiveStatus? liveStatus)  $default,) {final _that = this;
switch (_that) {
case _LiveAnchor():
return $default(_that.platform,_that.anchorId,_that.name,_that.avatarUrl,_that.profileUrl,_that.followerCount,_that.introduction,_that.isVerified,_that.anchorLevel,_that.liveStatus);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String platform,  String anchorId,  String name,  String? avatarUrl,  String? profileUrl,  int? followerCount,  String? introduction,  bool? isVerified,  int? anchorLevel,  LiveStatus? liveStatus)?  $default,) {final _that = this;
switch (_that) {
case _LiveAnchor() when $default != null:
return $default(_that.platform,_that.anchorId,_that.name,_that.avatarUrl,_that.profileUrl,_that.followerCount,_that.introduction,_that.isVerified,_that.anchorLevel,_that.liveStatus);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveAnchor implements LiveAnchor {
  const _LiveAnchor({this.platform = '', this.anchorId = '', this.name = '', this.avatarUrl, this.profileUrl, this.followerCount, this.introduction, this.isVerified, this.anchorLevel, this.liveStatus});
  factory _LiveAnchor.fromJson(Map<String, dynamic> json) => _$LiveAnchorFromJson(json);

@override@JsonKey() final  String platform;
@override@JsonKey() final  String anchorId;
@override@JsonKey() final  String name;
@override final  String? avatarUrl;
@override final  String? profileUrl;
@override final  int? followerCount;
@override final  String? introduction;
@override final  bool? isVerified;
@override final  int? anchorLevel;
@override final  LiveStatus? liveStatus;

/// Create a copy of LiveAnchor
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveAnchorCopyWith<_LiveAnchor> get copyWith => __$LiveAnchorCopyWithImpl<_LiveAnchor>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LiveAnchorToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveAnchor&&(identical(other.platform, platform) || other.platform == platform)&&(identical(other.anchorId, anchorId) || other.anchorId == anchorId)&&(identical(other.name, name) || other.name == name)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.profileUrl, profileUrl) || other.profileUrl == profileUrl)&&(identical(other.followerCount, followerCount) || other.followerCount == followerCount)&&(identical(other.introduction, introduction) || other.introduction == introduction)&&(identical(other.isVerified, isVerified) || other.isVerified == isVerified)&&(identical(other.anchorLevel, anchorLevel) || other.anchorLevel == anchorLevel)&&(identical(other.liveStatus, liveStatus) || other.liveStatus == liveStatus));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,platform,anchorId,name,avatarUrl,profileUrl,followerCount,introduction,isVerified,anchorLevel,liveStatus);
}

@override
String toString() {
    return 'LiveAnchor(platform: $platform, anchorId: $anchorId, name: $name, avatarUrl: $avatarUrl, profileUrl: $profileUrl, followerCount: $followerCount, introduction: $introduction, isVerified: $isVerified, anchorLevel: $anchorLevel, liveStatus: $liveStatus)';
}


}

/// @nodoc
abstract mixin class _$LiveAnchorCopyWith<$Res> implements $LiveAnchorCopyWith<$Res> {
  factory _$LiveAnchorCopyWith(_LiveAnchor value, $Res Function(_LiveAnchor) _then) = __$LiveAnchorCopyWithImpl;
@override @useResult
$Res call({
 String platform, String anchorId, String name, String? avatarUrl, String? profileUrl, int? followerCount, String? introduction, bool? isVerified, int? anchorLevel, LiveStatus? liveStatus
});




}
/// @nodoc
class __$LiveAnchorCopyWithImpl<$Res>
    implements _$LiveAnchorCopyWith<$Res> {
  __$LiveAnchorCopyWithImpl(this._self, this._then);

  final _LiveAnchor _self;
  final $Res Function(_LiveAnchor) _then;

/// Create a copy of LiveAnchor
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? platform = null,Object? anchorId = null,Object? name = null,Object? avatarUrl = freezed,Object? profileUrl = freezed,Object? followerCount = freezed,Object? introduction = freezed,Object? isVerified = freezed,Object? anchorLevel = freezed,Object? liveStatus = freezed,}) {
  return _then(_LiveAnchor(
platform: null == platform ? _self.platform : platform // ignore: cast_nullable_to_non_nullable
as String,anchorId: null == anchorId ? _self.anchorId : anchorId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,profileUrl: freezed == profileUrl ? _self.profileUrl : profileUrl // ignore: cast_nullable_to_non_nullable
as String?,followerCount: freezed == followerCount ? _self.followerCount : followerCount // ignore: cast_nullable_to_non_nullable
as int?,introduction: freezed == introduction ? _self.introduction : introduction // ignore: cast_nullable_to_non_nullable
as String?,isVerified: freezed == isVerified ? _self.isVerified : isVerified // ignore: cast_nullable_to_non_nullable
as bool?,anchorLevel: freezed == anchorLevel ? _self.anchorLevel : anchorLevel // ignore: cast_nullable_to_non_nullable
as int?,liveStatus: freezed == liveStatus ? _self.liveStatus : liveStatus // ignore: cast_nullable_to_non_nullable
as LiveStatus?,
  ));
}


}

// dart format on
