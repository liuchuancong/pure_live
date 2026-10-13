// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'room_audience.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RoomAudience {

@AudienceNumberConverter() int? get popularity;@AudienceNumberConverter() int? get onlineViewers;@AudienceNumberConverter() int? get totalViewers; LiveAudienceMetricType? get primaryMetric;
/// Create a copy of RoomAudience
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RoomAudienceCopyWith<RoomAudience> get copyWith => _$RoomAudienceCopyWithImpl<RoomAudience>(this as RoomAudience, _$identity);

  /// Serializes this RoomAudience to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RoomAudience;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RoomAudience&&(identical(other.popularity, _this.popularity) || other.popularity == _this.popularity)&&(identical(other.onlineViewers, _this.onlineViewers) || other.onlineViewers == _this.onlineViewers)&&(identical(other.totalViewers, _this.totalViewers) || other.totalViewers == _this.totalViewers)&&(identical(other.primaryMetric, _this.primaryMetric) || other.primaryMetric == _this.primaryMetric));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RoomAudience;
  return Object.hash(runtimeType,_this.popularity,_this.onlineViewers,_this.totalViewers,_this.primaryMetric);
}

@override
String toString() {
  final _this = this as RoomAudience;
  return 'RoomAudience(popularity: ${_this.popularity}, onlineViewers: ${_this.onlineViewers}, totalViewers: ${_this.totalViewers}, primaryMetric: ${_this.primaryMetric})';
}


}

/// @nodoc
abstract mixin class $RoomAudienceCopyWith<$Res>  {
  factory $RoomAudienceCopyWith(RoomAudience value, $Res Function(RoomAudience) _then) = _$RoomAudienceCopyWithImpl;
@useResult
$Res call({
@AudienceNumberConverter() int? popularity,@AudienceNumberConverter() int? onlineViewers,@AudienceNumberConverter() int? totalViewers, LiveAudienceMetricType? primaryMetric
});




}
/// @nodoc
class _$RoomAudienceCopyWithImpl<$Res>
    implements $RoomAudienceCopyWith<$Res> {
  _$RoomAudienceCopyWithImpl(this._self, this._then);

  final RoomAudience _self;
  final $Res Function(RoomAudience) _then;

/// Create a copy of RoomAudience
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? popularity = freezed,Object? onlineViewers = freezed,Object? totalViewers = freezed,Object? primaryMetric = freezed,}) {
  return _then(RoomAudience(
popularity: freezed == popularity ? _self.popularity : popularity // ignore: cast_nullable_to_non_nullable
as int?,onlineViewers: freezed == onlineViewers ? _self.onlineViewers : onlineViewers // ignore: cast_nullable_to_non_nullable
as int?,totalViewers: freezed == totalViewers ? _self.totalViewers : totalViewers // ignore: cast_nullable_to_non_nullable
as int?,primaryMetric: freezed == primaryMetric ? _self.primaryMetric : primaryMetric // ignore: cast_nullable_to_non_nullable
as LiveAudienceMetricType?,
  ));
}

}


/// Adds pattern-matching-related methods to [RoomAudience].
extension RoomAudiencePatterns on RoomAudience {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RoomAudience value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RoomAudience() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RoomAudience value)  $default,){
final _that = this;
switch (_that) {
case _RoomAudience():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RoomAudience value)?  $default,){
final _that = this;
switch (_that) {
case _RoomAudience() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@AudienceNumberConverter()  int? popularity, @AudienceNumberConverter()  int? onlineViewers, @AudienceNumberConverter()  int? totalViewers,  LiveAudienceMetricType? primaryMetric)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RoomAudience() when $default != null:
return $default(_that.popularity,_that.onlineViewers,_that.totalViewers,_that.primaryMetric);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@AudienceNumberConverter()  int? popularity, @AudienceNumberConverter()  int? onlineViewers, @AudienceNumberConverter()  int? totalViewers,  LiveAudienceMetricType? primaryMetric)  $default,) {final _that = this;
switch (_that) {
case _RoomAudience():
return $default(_that.popularity,_that.onlineViewers,_that.totalViewers,_that.primaryMetric);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@AudienceNumberConverter()  int? popularity, @AudienceNumberConverter()  int? onlineViewers, @AudienceNumberConverter()  int? totalViewers,  LiveAudienceMetricType? primaryMetric)?  $default,) {final _that = this;
switch (_that) {
case _RoomAudience() when $default != null:
return $default(_that.popularity,_that.onlineViewers,_that.totalViewers,_that.primaryMetric);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RoomAudience extends RoomAudience {
  const _RoomAudience({@AudienceNumberConverter() this.popularity, @AudienceNumberConverter() this.onlineViewers, @AudienceNumberConverter() this.totalViewers, this.primaryMetric}): super._();
  factory _RoomAudience.fromJson(Map<String, dynamic> json) => _$RoomAudienceFromJson(json);

@override@AudienceNumberConverter() final  int? popularity;
@override@AudienceNumberConverter() final  int? onlineViewers;
@override@AudienceNumberConverter() final  int? totalViewers;
@override final  LiveAudienceMetricType? primaryMetric;

/// Create a copy of RoomAudience
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RoomAudienceCopyWith<_RoomAudience> get copyWith => __$RoomAudienceCopyWithImpl<_RoomAudience>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RoomAudienceToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RoomAudience&&(identical(other.popularity, popularity) || other.popularity == popularity)&&(identical(other.onlineViewers, onlineViewers) || other.onlineViewers == onlineViewers)&&(identical(other.totalViewers, totalViewers) || other.totalViewers == totalViewers)&&(identical(other.primaryMetric, primaryMetric) || other.primaryMetric == primaryMetric));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,popularity,onlineViewers,totalViewers,primaryMetric);
}

@override
String toString() {
    return 'RoomAudience(popularity: $popularity, onlineViewers: $onlineViewers, totalViewers: $totalViewers, primaryMetric: $primaryMetric)';
}


}

/// @nodoc
abstract mixin class _$RoomAudienceCopyWith<$Res> implements $RoomAudienceCopyWith<$Res> {
  factory _$RoomAudienceCopyWith(_RoomAudience value, $Res Function(_RoomAudience) _then) = __$RoomAudienceCopyWithImpl;
@override @useResult
$Res call({
@AudienceNumberConverter() int? popularity,@AudienceNumberConverter() int? onlineViewers,@AudienceNumberConverter() int? totalViewers, LiveAudienceMetricType? primaryMetric
});




}
/// @nodoc
class __$RoomAudienceCopyWithImpl<$Res>
    implements _$RoomAudienceCopyWith<$Res> {
  __$RoomAudienceCopyWithImpl(this._self, this._then);

  final _RoomAudience _self;
  final $Res Function(_RoomAudience) _then;

/// Create a copy of RoomAudience
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? popularity = freezed,Object? onlineViewers = freezed,Object? totalViewers = freezed,Object? primaryMetric = freezed,}) {
  return _then(_RoomAudience(
popularity: freezed == popularity ? _self.popularity : popularity // ignore: cast_nullable_to_non_nullable
as int?,onlineViewers: freezed == onlineViewers ? _self.onlineViewers : onlineViewers // ignore: cast_nullable_to_non_nullable
as int?,totalViewers: freezed == totalViewers ? _self.totalViewers : totalViewers // ignore: cast_nullable_to_non_nullable
as int?,primaryMetric: freezed == primaryMetric ? _self.primaryMetric : primaryMetric // ignore: cast_nullable_to_non_nullable
as LiveAudienceMetricType?,
  ));
}


}

// dart format on
