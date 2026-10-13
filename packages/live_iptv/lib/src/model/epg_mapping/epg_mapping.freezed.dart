// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'epg_mapping.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$EpgMapping {

/// The playlist channel it belongs to.
 String get channelId;/// The guide channel's storage key, as `epgChannelKey` writes it.
 String get epgChannelKey;/// The playlist it came from.
 String get playlistId;/// The guide source the key belongs to.
 String get epgSourceId;/// Whether the user pinned it.
 bool get locked;/// Who created it: [epgAutoMappingOrigin] for the matcher, anything else
/// for a human.
 String get origin;
/// Create a copy of EpgMapping
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EpgMappingCopyWith<EpgMapping> get copyWith => _$EpgMappingCopyWithImpl<EpgMapping>(this as EpgMapping, _$identity);

  /// Serializes this EpgMapping to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as EpgMapping;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EpgMapping&&(identical(other.channelId, _this.channelId) || other.channelId == _this.channelId)&&(identical(other.epgChannelKey, _this.epgChannelKey) || other.epgChannelKey == _this.epgChannelKey)&&(identical(other.playlistId, _this.playlistId) || other.playlistId == _this.playlistId)&&(identical(other.epgSourceId, _this.epgSourceId) || other.epgSourceId == _this.epgSourceId)&&(identical(other.locked, _this.locked) || other.locked == _this.locked)&&(identical(other.origin, _this.origin) || other.origin == _this.origin));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as EpgMapping;
  return Object.hash(runtimeType,_this.channelId,_this.epgChannelKey,_this.playlistId,_this.epgSourceId,_this.locked,_this.origin);
}

@override
String toString() {
  final _this = this as EpgMapping;
  return 'EpgMapping(channelId: ${_this.channelId}, epgChannelKey: ${_this.epgChannelKey}, playlistId: ${_this.playlistId}, epgSourceId: ${_this.epgSourceId}, locked: ${_this.locked}, origin: ${_this.origin})';
}


}

/// @nodoc
abstract mixin class $EpgMappingCopyWith<$Res>  {
  factory $EpgMappingCopyWith(EpgMapping value, $Res Function(EpgMapping) _then) = _$EpgMappingCopyWithImpl;
@useResult
$Res call({
 String channelId, String epgChannelKey, String playlistId, String epgSourceId, bool locked, String origin
});




}
/// @nodoc
class _$EpgMappingCopyWithImpl<$Res>
    implements $EpgMappingCopyWith<$Res> {
  _$EpgMappingCopyWithImpl(this._self, this._then);

  final EpgMapping _self;
  final $Res Function(EpgMapping) _then;

/// Create a copy of EpgMapping
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? channelId = null,Object? epgChannelKey = null,Object? playlistId = null,Object? epgSourceId = null,Object? locked = null,Object? origin = null,}) {
  return _then(EpgMapping(
channelId: null == channelId ? _self.channelId : channelId // ignore: cast_nullable_to_non_nullable
as String,epgChannelKey: null == epgChannelKey ? _self.epgChannelKey : epgChannelKey // ignore: cast_nullable_to_non_nullable
as String,playlistId: null == playlistId ? _self.playlistId : playlistId // ignore: cast_nullable_to_non_nullable
as String,epgSourceId: null == epgSourceId ? _self.epgSourceId : epgSourceId // ignore: cast_nullable_to_non_nullable
as String,locked: null == locked ? _self.locked : locked // ignore: cast_nullable_to_non_nullable
as bool,origin: null == origin ? _self.origin : origin // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [EpgMapping].
extension EpgMappingPatterns on EpgMapping {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EpgMapping value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EpgMapping() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EpgMapping value)  $default,){
final _that = this;
switch (_that) {
case _EpgMapping():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EpgMapping value)?  $default,){
final _that = this;
switch (_that) {
case _EpgMapping() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String channelId,  String epgChannelKey,  String playlistId,  String epgSourceId,  bool locked,  String origin)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EpgMapping() when $default != null:
return $default(_that.channelId,_that.epgChannelKey,_that.playlistId,_that.epgSourceId,_that.locked,_that.origin);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String channelId,  String epgChannelKey,  String playlistId,  String epgSourceId,  bool locked,  String origin)  $default,) {final _that = this;
switch (_that) {
case _EpgMapping():
return $default(_that.channelId,_that.epgChannelKey,_that.playlistId,_that.epgSourceId,_that.locked,_that.origin);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String channelId,  String epgChannelKey,  String playlistId,  String epgSourceId,  bool locked,  String origin)?  $default,) {final _that = this;
switch (_that) {
case _EpgMapping() when $default != null:
return $default(_that.channelId,_that.epgChannelKey,_that.playlistId,_that.epgSourceId,_that.locked,_that.origin);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _EpgMapping implements EpgMapping {
  const _EpgMapping({required this.channelId, required this.epgChannelKey, this.playlistId = '', this.epgSourceId = '', this.locked = false, this.origin = epgAutoMappingOrigin});
  factory _EpgMapping.fromJson(Map<String, dynamic> json) => _$EpgMappingFromJson(json);

/// The playlist channel it belongs to.
@override final  String channelId;
/// The guide channel's storage key, as `epgChannelKey` writes it.
@override final  String epgChannelKey;
/// The playlist it came from.
@override@JsonKey() final  String playlistId;
/// The guide source the key belongs to.
@override@JsonKey() final  String epgSourceId;
/// Whether the user pinned it.
@override@JsonKey() final  bool locked;
/// Who created it: [epgAutoMappingOrigin] for the matcher, anything else
/// for a human.
@override@JsonKey() final  String origin;

/// Create a copy of EpgMapping
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EpgMappingCopyWith<_EpgMapping> get copyWith => __$EpgMappingCopyWithImpl<_EpgMapping>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$EpgMappingToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _EpgMapping&&(identical(other.channelId, channelId) || other.channelId == channelId)&&(identical(other.epgChannelKey, epgChannelKey) || other.epgChannelKey == epgChannelKey)&&(identical(other.playlistId, playlistId) || other.playlistId == playlistId)&&(identical(other.epgSourceId, epgSourceId) || other.epgSourceId == epgSourceId)&&(identical(other.locked, locked) || other.locked == locked)&&(identical(other.origin, origin) || other.origin == origin));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,channelId,epgChannelKey,playlistId,epgSourceId,locked,origin);
}

@override
String toString() {
    return 'EpgMapping(channelId: $channelId, epgChannelKey: $epgChannelKey, playlistId: $playlistId, epgSourceId: $epgSourceId, locked: $locked, origin: $origin)';
}


}

/// @nodoc
abstract mixin class _$EpgMappingCopyWith<$Res> implements $EpgMappingCopyWith<$Res> {
  factory _$EpgMappingCopyWith(_EpgMapping value, $Res Function(_EpgMapping) _then) = __$EpgMappingCopyWithImpl;
@override @useResult
$Res call({
 String channelId, String epgChannelKey, String playlistId, String epgSourceId, bool locked, String origin
});




}
/// @nodoc
class __$EpgMappingCopyWithImpl<$Res>
    implements _$EpgMappingCopyWith<$Res> {
  __$EpgMappingCopyWithImpl(this._self, this._then);

  final _EpgMapping _self;
  final $Res Function(_EpgMapping) _then;

/// Create a copy of EpgMapping
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? channelId = null,Object? epgChannelKey = null,Object? playlistId = null,Object? epgSourceId = null,Object? locked = null,Object? origin = null,}) {
  return _then(_EpgMapping(
channelId: null == channelId ? _self.channelId : channelId // ignore: cast_nullable_to_non_nullable
as String,epgChannelKey: null == epgChannelKey ? _self.epgChannelKey : epgChannelKey // ignore: cast_nullable_to_non_nullable
as String,playlistId: null == playlistId ? _self.playlistId : playlistId // ignore: cast_nullable_to_non_nullable
as String,epgSourceId: null == epgSourceId ? _self.epgSourceId : epgSourceId // ignore: cast_nullable_to_non_nullable
as String,locked: null == locked ? _self.locked : locked // ignore: cast_nullable_to_non_nullable
as bool,origin: null == origin ? _self.origin : origin // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
