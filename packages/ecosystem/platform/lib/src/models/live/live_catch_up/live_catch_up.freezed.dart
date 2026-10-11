// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'live_catch_up.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LiveCatchUp {

/// Whether this room has time-shift at all. False is an answer, not missing data.
 bool get active;/// The template or address the site hands out for a rewound stream, when it gives one separately.
@JsonKey(fromJson: _text) String? get url;/// The earliest offset the site keeps, in seconds within the available window.
@JsonKey(fromJson: _seconds, toJson: _seconds) int? get start;/// The latest offset it will serve, in the same frame as [start].
@JsonKey(fromJson: _seconds, toJson: _seconds) int? get end;/// The site's own mode word (`catchup`, `seek`, `timeshift`, `playlist`), kept verbatim because the player
/// has to build the url the way that mode expects.
@JsonKey(fromJson: _text) String? get mode;/// Which endpoint described this window, so a failure traces to one site field instead of to "the room said
/// something about replay".
@JsonKey(fromJson: _text) String? get source;/// How many days back the archive reaches, when the site states it as days.
@JsonKey(fromJson: _number, toJson: _number) double? get days;/// The offset between the site's published clock and wall time, in hours. Null means the site never said,
/// which is not 0: 0 claims the two agree.
@JsonKey(fromJson: _number, toJson: _number) double? get correctionHours;
/// Create a copy of LiveCatchUp
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveCatchUpCopyWith<LiveCatchUp> get copyWith => _$LiveCatchUpCopyWithImpl<LiveCatchUp>(this as LiveCatchUp, _$identity);

  /// Serializes this LiveCatchUp to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LiveCatchUp;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveCatchUp&&(identical(other.active, _this.active) || other.active == _this.active)&&(identical(other.url, _this.url) || other.url == _this.url)&&(identical(other.start, _this.start) || other.start == _this.start)&&(identical(other.end, _this.end) || other.end == _this.end)&&(identical(other.mode, _this.mode) || other.mode == _this.mode)&&(identical(other.source, _this.source) || other.source == _this.source)&&(identical(other.days, _this.days) || other.days == _this.days)&&(identical(other.correctionHours, _this.correctionHours) || other.correctionHours == _this.correctionHours));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LiveCatchUp;
  return Object.hash(runtimeType,_this.active,_this.url,_this.start,_this.end,_this.mode,_this.source,_this.days,_this.correctionHours);
}

@override
String toString() {
  final _this = this as LiveCatchUp;
  return 'LiveCatchUp(active: ${_this.active}, url: ${_this.url}, start: ${_this.start}, end: ${_this.end}, mode: ${_this.mode}, source: ${_this.source}, days: ${_this.days}, correctionHours: ${_this.correctionHours})';
}


}

/// @nodoc
abstract mixin class $LiveCatchUpCopyWith<$Res>  {
  factory $LiveCatchUpCopyWith(LiveCatchUp value, $Res Function(LiveCatchUp) _then) = _$LiveCatchUpCopyWithImpl;
@useResult
$Res call({
 bool active,@JsonKey(fromJson: _text) String? url,@JsonKey(fromJson: _seconds, toJson: _seconds) int? start,@JsonKey(fromJson: _seconds, toJson: _seconds) int? end,@JsonKey(fromJson: _text) String? mode,@JsonKey(fromJson: _text) String? source,@JsonKey(fromJson: _number, toJson: _number) double? days,@JsonKey(fromJson: _number, toJson: _number) double? correctionHours
});




}
/// @nodoc
class _$LiveCatchUpCopyWithImpl<$Res>
    implements $LiveCatchUpCopyWith<$Res> {
  _$LiveCatchUpCopyWithImpl(this._self, this._then);

  final LiveCatchUp _self;
  final $Res Function(LiveCatchUp) _then;

/// Create a copy of LiveCatchUp
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? active = null,Object? url = freezed,Object? start = freezed,Object? end = freezed,Object? mode = freezed,Object? source = freezed,Object? days = freezed,Object? correctionHours = freezed,}) {
  return _then(LiveCatchUp(
active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,url: freezed == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String?,start: freezed == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as int?,end: freezed == end ? _self.end : end // ignore: cast_nullable_to_non_nullable
as int?,mode: freezed == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as String?,source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String?,days: freezed == days ? _self.days : days // ignore: cast_nullable_to_non_nullable
as double?,correctionHours: freezed == correctionHours ? _self.correctionHours : correctionHours // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

}


/// Adds pattern-matching-related methods to [LiveCatchUp].
extension LiveCatchUpPatterns on LiveCatchUp {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveCatchUp value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveCatchUp() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveCatchUp value)  $default,){
final _that = this;
switch (_that) {
case _LiveCatchUp():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveCatchUp value)?  $default,){
final _that = this;
switch (_that) {
case _LiveCatchUp() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool active, @JsonKey(fromJson: _text)  String? url, @JsonKey(fromJson: _seconds, toJson: _seconds)  int? start, @JsonKey(fromJson: _seconds, toJson: _seconds)  int? end, @JsonKey(fromJson: _text)  String? mode, @JsonKey(fromJson: _text)  String? source, @JsonKey(fromJson: _number, toJson: _number)  double? days, @JsonKey(fromJson: _number, toJson: _number)  double? correctionHours)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveCatchUp() when $default != null:
return $default(_that.active,_that.url,_that.start,_that.end,_that.mode,_that.source,_that.days,_that.correctionHours);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool active, @JsonKey(fromJson: _text)  String? url, @JsonKey(fromJson: _seconds, toJson: _seconds)  int? start, @JsonKey(fromJson: _seconds, toJson: _seconds)  int? end, @JsonKey(fromJson: _text)  String? mode, @JsonKey(fromJson: _text)  String? source, @JsonKey(fromJson: _number, toJson: _number)  double? days, @JsonKey(fromJson: _number, toJson: _number)  double? correctionHours)  $default,) {final _that = this;
switch (_that) {
case _LiveCatchUp():
return $default(_that.active,_that.url,_that.start,_that.end,_that.mode,_that.source,_that.days,_that.correctionHours);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool active, @JsonKey(fromJson: _text)  String? url, @JsonKey(fromJson: _seconds, toJson: _seconds)  int? start, @JsonKey(fromJson: _seconds, toJson: _seconds)  int? end, @JsonKey(fromJson: _text)  String? mode, @JsonKey(fromJson: _text)  String? source, @JsonKey(fromJson: _number, toJson: _number)  double? days, @JsonKey(fromJson: _number, toJson: _number)  double? correctionHours)?  $default,) {final _that = this;
switch (_that) {
case _LiveCatchUp() when $default != null:
return $default(_that.active,_that.url,_that.start,_that.end,_that.mode,_that.source,_that.days,_that.correctionHours);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveCatchUp extends LiveCatchUp {
  const _LiveCatchUp({this.active = false, @JsonKey(fromJson: _text) this.url, @JsonKey(fromJson: _seconds, toJson: _seconds) this.start, @JsonKey(fromJson: _seconds, toJson: _seconds) this.end, @JsonKey(fromJson: _text) this.mode, @JsonKey(fromJson: _text) this.source, @JsonKey(fromJson: _number, toJson: _number) this.days, @JsonKey(fromJson: _number, toJson: _number) this.correctionHours}): super._();
  factory _LiveCatchUp.fromJson(Map<String, dynamic> json) => _$LiveCatchUpFromJson(json);

/// Whether this room has time-shift at all. False is an answer, not missing data.
@override@JsonKey() final  bool active;
/// The template or address the site hands out for a rewound stream, when it gives one separately.
@override@JsonKey(fromJson: _text) final  String? url;
/// The earliest offset the site keeps, in seconds within the available window.
@override@JsonKey(fromJson: _seconds, toJson: _seconds) final  int? start;
/// The latest offset it will serve, in the same frame as [start].
@override@JsonKey(fromJson: _seconds, toJson: _seconds) final  int? end;
/// The site's own mode word (`catchup`, `seek`, `timeshift`, `playlist`), kept verbatim because the player
/// has to build the url the way that mode expects.
@override@JsonKey(fromJson: _text) final  String? mode;
/// Which endpoint described this window, so a failure traces to one site field instead of to "the room said
/// something about replay".
@override@JsonKey(fromJson: _text) final  String? source;
/// How many days back the archive reaches, when the site states it as days.
@override@JsonKey(fromJson: _number, toJson: _number) final  double? days;
/// The offset between the site's published clock and wall time, in hours. Null means the site never said,
/// which is not 0: 0 claims the two agree.
@override@JsonKey(fromJson: _number, toJson: _number) final  double? correctionHours;

/// Create a copy of LiveCatchUp
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveCatchUpCopyWith<_LiveCatchUp> get copyWith => __$LiveCatchUpCopyWithImpl<_LiveCatchUp>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LiveCatchUpToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveCatchUp&&(identical(other.active, active) || other.active == active)&&(identical(other.url, url) || other.url == url)&&(identical(other.start, start) || other.start == start)&&(identical(other.end, end) || other.end == end)&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.source, source) || other.source == source)&&(identical(other.days, days) || other.days == days)&&(identical(other.correctionHours, correctionHours) || other.correctionHours == correctionHours));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,active,url,start,end,mode,source,days,correctionHours);
}

@override
String toString() {
    return 'LiveCatchUp(active: $active, url: $url, start: $start, end: $end, mode: $mode, source: $source, days: $days, correctionHours: $correctionHours)';
}


}

/// @nodoc
abstract mixin class _$LiveCatchUpCopyWith<$Res> implements $LiveCatchUpCopyWith<$Res> {
  factory _$LiveCatchUpCopyWith(_LiveCatchUp value, $Res Function(_LiveCatchUp) _then) = __$LiveCatchUpCopyWithImpl;
@override @useResult
$Res call({
 bool active,@JsonKey(fromJson: _text) String? url,@JsonKey(fromJson: _seconds, toJson: _seconds) int? start,@JsonKey(fromJson: _seconds, toJson: _seconds) int? end,@JsonKey(fromJson: _text) String? mode,@JsonKey(fromJson: _text) String? source,@JsonKey(fromJson: _number, toJson: _number) double? days,@JsonKey(fromJson: _number, toJson: _number) double? correctionHours
});




}
/// @nodoc
class __$LiveCatchUpCopyWithImpl<$Res>
    implements _$LiveCatchUpCopyWith<$Res> {
  __$LiveCatchUpCopyWithImpl(this._self, this._then);

  final _LiveCatchUp _self;
  final $Res Function(_LiveCatchUp) _then;

/// Create a copy of LiveCatchUp
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? active = null,Object? url = freezed,Object? start = freezed,Object? end = freezed,Object? mode = freezed,Object? source = freezed,Object? days = freezed,Object? correctionHours = freezed,}) {
  return _then(_LiveCatchUp(
active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,url: freezed == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String?,start: freezed == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as int?,end: freezed == end ? _self.end : end // ignore: cast_nullable_to_non_nullable
as int?,mode: freezed == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as String?,source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String?,days: freezed == days ? _self.days : days // ignore: cast_nullable_to_non_nullable
as double?,correctionHours: freezed == correctionHours ? _self.correctionHours : correctionHours // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}

// dart format on
