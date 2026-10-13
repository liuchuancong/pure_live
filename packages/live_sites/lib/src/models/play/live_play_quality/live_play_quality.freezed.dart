// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'live_play_quality.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$LivePlayQuality {

 String get label; String? get qualityId; int get platformOrder; bool get isPlaybackUnconfirmed; LiveStreamCodec? get codec;
/// Create a copy of LivePlayQuality
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LivePlayQualityCopyWith<LivePlayQuality> get copyWith => _$LivePlayQualityCopyWithImpl<LivePlayQuality>(this as LivePlayQuality, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as LivePlayQuality;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LivePlayQuality&&(identical(other.label, _this.label) || other.label == _this.label)&&(identical(other.qualityId, _this.qualityId) || other.qualityId == _this.qualityId)&&(identical(other.platformOrder, _this.platformOrder) || other.platformOrder == _this.platformOrder)&&(identical(other.isPlaybackUnconfirmed, _this.isPlaybackUnconfirmed) || other.isPlaybackUnconfirmed == _this.isPlaybackUnconfirmed)&&(identical(other.codec, _this.codec) || other.codec == _this.codec));
}


@override
int get hashCode {
  final _this = this as LivePlayQuality;
  return Object.hash(runtimeType,_this.label,_this.qualityId,_this.platformOrder,_this.isPlaybackUnconfirmed,_this.codec);
}

@override
String toString() {
  final _this = this as LivePlayQuality;
  return 'LivePlayQuality(label: ${_this.label}, qualityId: ${_this.qualityId}, platformOrder: ${_this.platformOrder}, isPlaybackUnconfirmed: ${_this.isPlaybackUnconfirmed}, codec: ${_this.codec})';
}


}

/// @nodoc
abstract mixin class $LivePlayQualityCopyWith<$Res>  {
  factory $LivePlayQualityCopyWith(LivePlayQuality value, $Res Function(LivePlayQuality) _then) = _$LivePlayQualityCopyWithImpl;
@useResult
$Res call({
 String label, String? qualityId, int platformOrder, bool isPlaybackUnconfirmed, LiveStreamCodec? codec
});




}
/// @nodoc
class _$LivePlayQualityCopyWithImpl<$Res>
    implements $LivePlayQualityCopyWith<$Res> {
  _$LivePlayQualityCopyWithImpl(this._self, this._then);

  final LivePlayQuality _self;
  final $Res Function(LivePlayQuality) _then;

/// Create a copy of LivePlayQuality
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? label = null,Object? qualityId = freezed,Object? platformOrder = null,Object? isPlaybackUnconfirmed = null,Object? codec = freezed,}) {
  return _then(LivePlayQuality(
label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,qualityId: freezed == qualityId ? _self.qualityId : qualityId // ignore: cast_nullable_to_non_nullable
as String?,platformOrder: null == platformOrder ? _self.platformOrder : platformOrder // ignore: cast_nullable_to_non_nullable
as int,isPlaybackUnconfirmed: null == isPlaybackUnconfirmed ? _self.isPlaybackUnconfirmed : isPlaybackUnconfirmed // ignore: cast_nullable_to_non_nullable
as bool,codec: freezed == codec ? _self.codec : codec // ignore: cast_nullable_to_non_nullable
as LiveStreamCodec?,
  ));
}

}


/// Adds pattern-matching-related methods to [LivePlayQuality].
extension LivePlayQualityPatterns on LivePlayQuality {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LivePlayQuality value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LivePlayQuality() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LivePlayQuality value)  $default,){
final _that = this;
switch (_that) {
case _LivePlayQuality():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LivePlayQuality value)?  $default,){
final _that = this;
switch (_that) {
case _LivePlayQuality() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String label,  String? qualityId,  int platformOrder,  bool isPlaybackUnconfirmed,  LiveStreamCodec? codec)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LivePlayQuality() when $default != null:
return $default(_that.label,_that.qualityId,_that.platformOrder,_that.isPlaybackUnconfirmed,_that.codec);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String label,  String? qualityId,  int platformOrder,  bool isPlaybackUnconfirmed,  LiveStreamCodec? codec)  $default,) {final _that = this;
switch (_that) {
case _LivePlayQuality():
return $default(_that.label,_that.qualityId,_that.platformOrder,_that.isPlaybackUnconfirmed,_that.codec);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String label,  String? qualityId,  int platformOrder,  bool isPlaybackUnconfirmed,  LiveStreamCodec? codec)?  $default,) {final _that = this;
switch (_that) {
case _LivePlayQuality() when $default != null:
return $default(_that.label,_that.qualityId,_that.platformOrder,_that.isPlaybackUnconfirmed,_that.codec);case _:
  return null;

}
}

}

/// @nodoc


class _LivePlayQuality implements LivePlayQuality {
  const _LivePlayQuality({required this.label, this.qualityId, this.platformOrder = 0, this.isPlaybackUnconfirmed = false, this.codec});
  

@override final  String label;
@override final  String? qualityId;
@override@JsonKey() final  int platformOrder;
@override@JsonKey() final  bool isPlaybackUnconfirmed;
@override final  LiveStreamCodec? codec;

/// Create a copy of LivePlayQuality
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LivePlayQualityCopyWith<_LivePlayQuality> get copyWith => __$LivePlayQualityCopyWithImpl<_LivePlayQuality>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LivePlayQuality&&(identical(other.label, label) || other.label == label)&&(identical(other.qualityId, qualityId) || other.qualityId == qualityId)&&(identical(other.platformOrder, platformOrder) || other.platformOrder == platformOrder)&&(identical(other.isPlaybackUnconfirmed, isPlaybackUnconfirmed) || other.isPlaybackUnconfirmed == isPlaybackUnconfirmed)&&(identical(other.codec, codec) || other.codec == codec));
}


@override
int get hashCode {
    return Object.hash(runtimeType,label,qualityId,platformOrder,isPlaybackUnconfirmed,codec);
}

@override
String toString() {
    return 'LivePlayQuality(label: $label, qualityId: $qualityId, platformOrder: $platformOrder, isPlaybackUnconfirmed: $isPlaybackUnconfirmed, codec: $codec)';
}


}

/// @nodoc
abstract mixin class _$LivePlayQualityCopyWith<$Res> implements $LivePlayQualityCopyWith<$Res> {
  factory _$LivePlayQualityCopyWith(_LivePlayQuality value, $Res Function(_LivePlayQuality) _then) = __$LivePlayQualityCopyWithImpl;
@override @useResult
$Res call({
 String label, String? qualityId, int platformOrder, bool isPlaybackUnconfirmed, LiveStreamCodec? codec
});




}
/// @nodoc
class __$LivePlayQualityCopyWithImpl<$Res>
    implements _$LivePlayQualityCopyWith<$Res> {
  __$LivePlayQualityCopyWithImpl(this._self, this._then);

  final _LivePlayQuality _self;
  final $Res Function(_LivePlayQuality) _then;

/// Create a copy of LivePlayQuality
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? label = null,Object? qualityId = freezed,Object? platformOrder = null,Object? isPlaybackUnconfirmed = null,Object? codec = freezed,}) {
  return _then(_LivePlayQuality(
label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,qualityId: freezed == qualityId ? _self.qualityId : qualityId // ignore: cast_nullable_to_non_nullable
as String?,platformOrder: null == platformOrder ? _self.platformOrder : platformOrder // ignore: cast_nullable_to_non_nullable
as int,isPlaybackUnconfirmed: null == isPlaybackUnconfirmed ? _self.isPlaybackUnconfirmed : isPlaybackUnconfirmed // ignore: cast_nullable_to_non_nullable
as bool,codec: freezed == codec ? _self.codec : codec // ignore: cast_nullable_to_non_nullable
as LiveStreamCodec?,
  ));
}


}

// dart format on
