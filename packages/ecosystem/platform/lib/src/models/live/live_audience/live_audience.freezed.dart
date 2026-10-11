// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'live_audience.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LiveAudience {

/// Concurrent viewers, when the site reports them (huya `totalCount`, acfun `onlineCount`).
@JsonKey(fromJson: _count, toJson: _count) int? get onlineViewers;/// Total visits since the broadcast began. Monotonic; never a headcount of who watches now.
@JsonKey(fromJson: _count, toJson: _count) int? get totalViewers;/// A computed heat score (douyu `room_biz_all.hot`, kugou `hot`). It ranks rooms; it does not count people.
@JsonKey(fromJson: _count, toJson: _count) int? get popularity;/// The figure exactly as the platform worded it ("9.8万"、"热度 12.3万"), for surfaces that show the site's
/// own text rather than our formatting of a number.
@JsonKey(fromJson: _label) String? get label;/// What [label] - or the primary number above - actually measures.
@JsonKey(fromJson: _metric) LiveAudienceMetric get metric;
/// Create a copy of LiveAudience
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveAudienceCopyWith<LiveAudience> get copyWith => _$LiveAudienceCopyWithImpl<LiveAudience>(this as LiveAudience, _$identity);

  /// Serializes this LiveAudience to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LiveAudience;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveAudience&&(identical(other.onlineViewers, _this.onlineViewers) || other.onlineViewers == _this.onlineViewers)&&(identical(other.totalViewers, _this.totalViewers) || other.totalViewers == _this.totalViewers)&&(identical(other.popularity, _this.popularity) || other.popularity == _this.popularity)&&(identical(other.label, _this.label) || other.label == _this.label)&&(identical(other.metric, _this.metric) || other.metric == _this.metric));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LiveAudience;
  return Object.hash(runtimeType,_this.onlineViewers,_this.totalViewers,_this.popularity,_this.label,_this.metric);
}

@override
String toString() {
  final _this = this as LiveAudience;
  return 'LiveAudience(onlineViewers: ${_this.onlineViewers}, totalViewers: ${_this.totalViewers}, popularity: ${_this.popularity}, label: ${_this.label}, metric: ${_this.metric})';
}


}

/// @nodoc
abstract mixin class $LiveAudienceCopyWith<$Res>  {
  factory $LiveAudienceCopyWith(LiveAudience value, $Res Function(LiveAudience) _then) = _$LiveAudienceCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _count, toJson: _count) int? onlineViewers,@JsonKey(fromJson: _count, toJson: _count) int? totalViewers,@JsonKey(fromJson: _count, toJson: _count) int? popularity,@JsonKey(fromJson: _label) String? label,@JsonKey(fromJson: _metric) LiveAudienceMetric metric
});




}
/// @nodoc
class _$LiveAudienceCopyWithImpl<$Res>
    implements $LiveAudienceCopyWith<$Res> {
  _$LiveAudienceCopyWithImpl(this._self, this._then);

  final LiveAudience _self;
  final $Res Function(LiveAudience) _then;

/// Create a copy of LiveAudience
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? onlineViewers = freezed,Object? totalViewers = freezed,Object? popularity = freezed,Object? label = freezed,Object? metric = null,}) {
  return _then(LiveAudience(
onlineViewers: freezed == onlineViewers ? _self.onlineViewers : onlineViewers // ignore: cast_nullable_to_non_nullable
as int?,totalViewers: freezed == totalViewers ? _self.totalViewers : totalViewers // ignore: cast_nullable_to_non_nullable
as int?,popularity: freezed == popularity ? _self.popularity : popularity // ignore: cast_nullable_to_non_nullable
as int?,label: freezed == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String?,metric: null == metric ? _self.metric : metric // ignore: cast_nullable_to_non_nullable
as LiveAudienceMetric,
  ));
}

}


/// Adds pattern-matching-related methods to [LiveAudience].
extension LiveAudiencePatterns on LiveAudience {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveAudience value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveAudience() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveAudience value)  $default,){
final _that = this;
switch (_that) {
case _LiveAudience():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveAudience value)?  $default,){
final _that = this;
switch (_that) {
case _LiveAudience() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _count, toJson: _count)  int? onlineViewers, @JsonKey(fromJson: _count, toJson: _count)  int? totalViewers, @JsonKey(fromJson: _count, toJson: _count)  int? popularity, @JsonKey(fromJson: _label)  String? label, @JsonKey(fromJson: _metric)  LiveAudienceMetric metric)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveAudience() when $default != null:
return $default(_that.onlineViewers,_that.totalViewers,_that.popularity,_that.label,_that.metric);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _count, toJson: _count)  int? onlineViewers, @JsonKey(fromJson: _count, toJson: _count)  int? totalViewers, @JsonKey(fromJson: _count, toJson: _count)  int? popularity, @JsonKey(fromJson: _label)  String? label, @JsonKey(fromJson: _metric)  LiveAudienceMetric metric)  $default,) {final _that = this;
switch (_that) {
case _LiveAudience():
return $default(_that.onlineViewers,_that.totalViewers,_that.popularity,_that.label,_that.metric);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: _count, toJson: _count)  int? onlineViewers, @JsonKey(fromJson: _count, toJson: _count)  int? totalViewers, @JsonKey(fromJson: _count, toJson: _count)  int? popularity, @JsonKey(fromJson: _label)  String? label, @JsonKey(fromJson: _metric)  LiveAudienceMetric metric)?  $default,) {final _that = this;
switch (_that) {
case _LiveAudience() when $default != null:
return $default(_that.onlineViewers,_that.totalViewers,_that.popularity,_that.label,_that.metric);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveAudience extends LiveAudience {
  const _LiveAudience({@JsonKey(fromJson: _count, toJson: _count) this.onlineViewers, @JsonKey(fromJson: _count, toJson: _count) this.totalViewers, @JsonKey(fromJson: _count, toJson: _count) this.popularity, @JsonKey(fromJson: _label) this.label, @JsonKey(fromJson: _metric) this.metric = LiveAudienceMetric.unknown}): super._();
  factory _LiveAudience.fromJson(Map<String, dynamic> json) => _$LiveAudienceFromJson(json);

/// Concurrent viewers, when the site reports them (huya `totalCount`, acfun `onlineCount`).
@override@JsonKey(fromJson: _count, toJson: _count) final  int? onlineViewers;
/// Total visits since the broadcast began. Monotonic; never a headcount of who watches now.
@override@JsonKey(fromJson: _count, toJson: _count) final  int? totalViewers;
/// A computed heat score (douyu `room_biz_all.hot`, kugou `hot`). It ranks rooms; it does not count people.
@override@JsonKey(fromJson: _count, toJson: _count) final  int? popularity;
/// The figure exactly as the platform worded it ("9.8万"、"热度 12.3万"), for surfaces that show the site's
/// own text rather than our formatting of a number.
@override@JsonKey(fromJson: _label) final  String? label;
/// What [label] - or the primary number above - actually measures.
@override@JsonKey(fromJson: _metric) final  LiveAudienceMetric metric;

/// Create a copy of LiveAudience
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveAudienceCopyWith<_LiveAudience> get copyWith => __$LiveAudienceCopyWithImpl<_LiveAudience>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LiveAudienceToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveAudience&&(identical(other.onlineViewers, onlineViewers) || other.onlineViewers == onlineViewers)&&(identical(other.totalViewers, totalViewers) || other.totalViewers == totalViewers)&&(identical(other.popularity, popularity) || other.popularity == popularity)&&(identical(other.label, label) || other.label == label)&&(identical(other.metric, metric) || other.metric == metric));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,onlineViewers,totalViewers,popularity,label,metric);
}

@override
String toString() {
    return 'LiveAudience(onlineViewers: $onlineViewers, totalViewers: $totalViewers, popularity: $popularity, label: $label, metric: $metric)';
}


}

/// @nodoc
abstract mixin class _$LiveAudienceCopyWith<$Res> implements $LiveAudienceCopyWith<$Res> {
  factory _$LiveAudienceCopyWith(_LiveAudience value, $Res Function(_LiveAudience) _then) = __$LiveAudienceCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _count, toJson: _count) int? onlineViewers,@JsonKey(fromJson: _count, toJson: _count) int? totalViewers,@JsonKey(fromJson: _count, toJson: _count) int? popularity,@JsonKey(fromJson: _label) String? label,@JsonKey(fromJson: _metric) LiveAudienceMetric metric
});




}
/// @nodoc
class __$LiveAudienceCopyWithImpl<$Res>
    implements _$LiveAudienceCopyWith<$Res> {
  __$LiveAudienceCopyWithImpl(this._self, this._then);

  final _LiveAudience _self;
  final $Res Function(_LiveAudience) _then;

/// Create a copy of LiveAudience
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? onlineViewers = freezed,Object? totalViewers = freezed,Object? popularity = freezed,Object? label = freezed,Object? metric = null,}) {
  return _then(_LiveAudience(
onlineViewers: freezed == onlineViewers ? _self.onlineViewers : onlineViewers // ignore: cast_nullable_to_non_nullable
as int?,totalViewers: freezed == totalViewers ? _self.totalViewers : totalViewers // ignore: cast_nullable_to_non_nullable
as int?,popularity: freezed == popularity ? _self.popularity : popularity // ignore: cast_nullable_to_non_nullable
as int?,label: freezed == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String?,metric: null == metric ? _self.metric : metric // ignore: cast_nullable_to_non_nullable
as LiveAudienceMetric,
  ));
}


}

// dart format on
