// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'epg_channel.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$EpgChannel {

/// The source the channel came from.
 String get sourceId;/// The guide's own channel id.
 String get channelId;/// The name shown when the guide gives no better one.
 String get displayName;/// The channel's icon.
 String? get iconUrl;
/// Create a copy of EpgChannel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EpgChannelCopyWith<EpgChannel> get copyWith => _$EpgChannelCopyWithImpl<EpgChannel>(this as EpgChannel, _$identity);

  /// Serializes this EpgChannel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as EpgChannel;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EpgChannel&&(identical(other.sourceId, _this.sourceId) || other.sourceId == _this.sourceId)&&(identical(other.channelId, _this.channelId) || other.channelId == _this.channelId)&&(identical(other.displayName, _this.displayName) || other.displayName == _this.displayName)&&(identical(other.iconUrl, _this.iconUrl) || other.iconUrl == _this.iconUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as EpgChannel;
  return Object.hash(runtimeType,_this.sourceId,_this.channelId,_this.displayName,_this.iconUrl);
}

@override
String toString() {
  final _this = this as EpgChannel;
  return 'EpgChannel(sourceId: ${_this.sourceId}, channelId: ${_this.channelId}, displayName: ${_this.displayName}, iconUrl: ${_this.iconUrl})';
}


}

/// @nodoc
abstract mixin class $EpgChannelCopyWith<$Res>  {
  factory $EpgChannelCopyWith(EpgChannel value, $Res Function(EpgChannel) _then) = _$EpgChannelCopyWithImpl;
@useResult
$Res call({
 String sourceId, String channelId, String displayName, String? iconUrl
});




}
/// @nodoc
class _$EpgChannelCopyWithImpl<$Res>
    implements $EpgChannelCopyWith<$Res> {
  _$EpgChannelCopyWithImpl(this._self, this._then);

  final EpgChannel _self;
  final $Res Function(EpgChannel) _then;

/// Create a copy of EpgChannel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sourceId = null,Object? channelId = null,Object? displayName = null,Object? iconUrl = freezed,}) {
  return _then(EpgChannel(
sourceId: null == sourceId ? _self.sourceId : sourceId // ignore: cast_nullable_to_non_nullable
as String,channelId: null == channelId ? _self.channelId : channelId // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,iconUrl: freezed == iconUrl ? _self.iconUrl : iconUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [EpgChannel].
extension EpgChannelPatterns on EpgChannel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EpgChannel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EpgChannel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EpgChannel value)  $default,){
final _that = this;
switch (_that) {
case _EpgChannel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EpgChannel value)?  $default,){
final _that = this;
switch (_that) {
case _EpgChannel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String sourceId,  String channelId,  String displayName,  String? iconUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EpgChannel() when $default != null:
return $default(_that.sourceId,_that.channelId,_that.displayName,_that.iconUrl);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String sourceId,  String channelId,  String displayName,  String? iconUrl)  $default,) {final _that = this;
switch (_that) {
case _EpgChannel():
return $default(_that.sourceId,_that.channelId,_that.displayName,_that.iconUrl);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String sourceId,  String channelId,  String displayName,  String? iconUrl)?  $default,) {final _that = this;
switch (_that) {
case _EpgChannel() when $default != null:
return $default(_that.sourceId,_that.channelId,_that.displayName,_that.iconUrl);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _EpgChannel implements EpgChannel {
  const _EpgChannel({required this.sourceId, required this.channelId, this.displayName = '', this.iconUrl});
  factory _EpgChannel.fromJson(Map<String, dynamic> json) => _$EpgChannelFromJson(json);

/// The source the channel came from.
@override final  String sourceId;
/// The guide's own channel id.
@override final  String channelId;
/// The name shown when the guide gives no better one.
@override@JsonKey() final  String displayName;
/// The channel's icon.
@override final  String? iconUrl;

/// Create a copy of EpgChannel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EpgChannelCopyWith<_EpgChannel> get copyWith => __$EpgChannelCopyWithImpl<_EpgChannel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$EpgChannelToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _EpgChannel&&(identical(other.sourceId, sourceId) || other.sourceId == sourceId)&&(identical(other.channelId, channelId) || other.channelId == channelId)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.iconUrl, iconUrl) || other.iconUrl == iconUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,sourceId,channelId,displayName,iconUrl);
}

@override
String toString() {
    return 'EpgChannel(sourceId: $sourceId, channelId: $channelId, displayName: $displayName, iconUrl: $iconUrl)';
}


}

/// @nodoc
abstract mixin class _$EpgChannelCopyWith<$Res> implements $EpgChannelCopyWith<$Res> {
  factory _$EpgChannelCopyWith(_EpgChannel value, $Res Function(_EpgChannel) _then) = __$EpgChannelCopyWithImpl;
@override @useResult
$Res call({
 String sourceId, String channelId, String displayName, String? iconUrl
});




}
/// @nodoc
class __$EpgChannelCopyWithImpl<$Res>
    implements _$EpgChannelCopyWith<$Res> {
  __$EpgChannelCopyWithImpl(this._self, this._then);

  final _EpgChannel _self;
  final $Res Function(_EpgChannel) _then;

/// Create a copy of EpgChannel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sourceId = null,Object? channelId = null,Object? displayName = null,Object? iconUrl = freezed,}) {
  return _then(_EpgChannel(
sourceId: null == sourceId ? _self.sourceId : sourceId // ignore: cast_nullable_to_non_nullable
as String,channelId: null == channelId ? _self.channelId : channelId // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,iconUrl: freezed == iconUrl ? _self.iconUrl : iconUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
