// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'playback_preferences.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PlaybackPreferences {

/// The preferred quality label, as the site names it; empty means the
/// highest quality the site offers.
 String get quality;/// The preferred engine id from the playback registry; empty means the
/// platform's default engine.
 String get engineId;/// Whether the user pinned a line.
 LinePreference get linePreference;/// The pinned line's id (the play line's `lineId`), when the user
/// pinned one and the site labels its lines.
 String get preferredLineId;/// Whether a failed line advances the recovery ladder (other lines,
/// then other qualities) instead of stopping at the first failure.
 bool get autoRecover;/// How many ladder steps a session may take before it gives up,
/// matching the playback session's default.
 int get maxRecoveryAttempts;
/// Create a copy of PlaybackPreferences
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlaybackPreferencesCopyWith<PlaybackPreferences> get copyWith => _$PlaybackPreferencesCopyWithImpl<PlaybackPreferences>(this as PlaybackPreferences, _$identity);

  /// Serializes this PlaybackPreferences to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PlaybackPreferences;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlaybackPreferences&&(identical(other.quality, _this.quality) || other.quality == _this.quality)&&(identical(other.engineId, _this.engineId) || other.engineId == _this.engineId)&&(identical(other.linePreference, _this.linePreference) || other.linePreference == _this.linePreference)&&(identical(other.preferredLineId, _this.preferredLineId) || other.preferredLineId == _this.preferredLineId)&&(identical(other.autoRecover, _this.autoRecover) || other.autoRecover == _this.autoRecover)&&(identical(other.maxRecoveryAttempts, _this.maxRecoveryAttempts) || other.maxRecoveryAttempts == _this.maxRecoveryAttempts));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PlaybackPreferences;
  return Object.hash(runtimeType,_this.quality,_this.engineId,_this.linePreference,_this.preferredLineId,_this.autoRecover,_this.maxRecoveryAttempts);
}

@override
String toString() {
  final _this = this as PlaybackPreferences;
  return 'PlaybackPreferences(quality: ${_this.quality}, engineId: ${_this.engineId}, linePreference: ${_this.linePreference}, preferredLineId: ${_this.preferredLineId}, autoRecover: ${_this.autoRecover}, maxRecoveryAttempts: ${_this.maxRecoveryAttempts})';
}


}

/// @nodoc
abstract mixin class $PlaybackPreferencesCopyWith<$Res>  {
  factory $PlaybackPreferencesCopyWith(PlaybackPreferences value, $Res Function(PlaybackPreferences) _then) = _$PlaybackPreferencesCopyWithImpl;
@useResult
$Res call({
 String quality, String engineId, LinePreference linePreference, String preferredLineId, bool autoRecover, int maxRecoveryAttempts
});




}
/// @nodoc
class _$PlaybackPreferencesCopyWithImpl<$Res>
    implements $PlaybackPreferencesCopyWith<$Res> {
  _$PlaybackPreferencesCopyWithImpl(this._self, this._then);

  final PlaybackPreferences _self;
  final $Res Function(PlaybackPreferences) _then;

/// Create a copy of PlaybackPreferences
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? quality = null,Object? engineId = null,Object? linePreference = null,Object? preferredLineId = null,Object? autoRecover = null,Object? maxRecoveryAttempts = null,}) {
  return _then(PlaybackPreferences(
quality: null == quality ? _self.quality : quality // ignore: cast_nullable_to_non_nullable
as String,engineId: null == engineId ? _self.engineId : engineId // ignore: cast_nullable_to_non_nullable
as String,linePreference: null == linePreference ? _self.linePreference : linePreference // ignore: cast_nullable_to_non_nullable
as LinePreference,preferredLineId: null == preferredLineId ? _self.preferredLineId : preferredLineId // ignore: cast_nullable_to_non_nullable
as String,autoRecover: null == autoRecover ? _self.autoRecover : autoRecover // ignore: cast_nullable_to_non_nullable
as bool,maxRecoveryAttempts: null == maxRecoveryAttempts ? _self.maxRecoveryAttempts : maxRecoveryAttempts // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [PlaybackPreferences].
extension PlaybackPreferencesPatterns on PlaybackPreferences {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PlaybackPreferences value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PlaybackPreferences() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PlaybackPreferences value)  $default,){
final _that = this;
switch (_that) {
case _PlaybackPreferences():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PlaybackPreferences value)?  $default,){
final _that = this;
switch (_that) {
case _PlaybackPreferences() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String quality,  String engineId,  LinePreference linePreference,  String preferredLineId,  bool autoRecover,  int maxRecoveryAttempts)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PlaybackPreferences() when $default != null:
return $default(_that.quality,_that.engineId,_that.linePreference,_that.preferredLineId,_that.autoRecover,_that.maxRecoveryAttempts);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String quality,  String engineId,  LinePreference linePreference,  String preferredLineId,  bool autoRecover,  int maxRecoveryAttempts)  $default,) {final _that = this;
switch (_that) {
case _PlaybackPreferences():
return $default(_that.quality,_that.engineId,_that.linePreference,_that.preferredLineId,_that.autoRecover,_that.maxRecoveryAttempts);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String quality,  String engineId,  LinePreference linePreference,  String preferredLineId,  bool autoRecover,  int maxRecoveryAttempts)?  $default,) {final _that = this;
switch (_that) {
case _PlaybackPreferences() when $default != null:
return $default(_that.quality,_that.engineId,_that.linePreference,_that.preferredLineId,_that.autoRecover,_that.maxRecoveryAttempts);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PlaybackPreferences implements PlaybackPreferences {
  const _PlaybackPreferences({this.quality = '', this.engineId = '', this.linePreference = LinePreference.automatic, this.preferredLineId = '', this.autoRecover = true, this.maxRecoveryAttempts = 3});
  factory _PlaybackPreferences.fromJson(Map<String, dynamic> json) => _$PlaybackPreferencesFromJson(json);

/// The preferred quality label, as the site names it; empty means the
/// highest quality the site offers.
@override@JsonKey() final  String quality;
/// The preferred engine id from the playback registry; empty means the
/// platform's default engine.
@override@JsonKey() final  String engineId;
/// Whether the user pinned a line.
@override@JsonKey() final  LinePreference linePreference;
/// The pinned line's id (the play line's `lineId`), when the user
/// pinned one and the site labels its lines.
@override@JsonKey() final  String preferredLineId;
/// Whether a failed line advances the recovery ladder (other lines,
/// then other qualities) instead of stopping at the first failure.
@override@JsonKey() final  bool autoRecover;
/// How many ladder steps a session may take before it gives up,
/// matching the playback session's default.
@override@JsonKey() final  int maxRecoveryAttempts;

/// Create a copy of PlaybackPreferences
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PlaybackPreferencesCopyWith<_PlaybackPreferences> get copyWith => __$PlaybackPreferencesCopyWithImpl<_PlaybackPreferences>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PlaybackPreferencesToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PlaybackPreferences&&(identical(other.quality, quality) || other.quality == quality)&&(identical(other.engineId, engineId) || other.engineId == engineId)&&(identical(other.linePreference, linePreference) || other.linePreference == linePreference)&&(identical(other.preferredLineId, preferredLineId) || other.preferredLineId == preferredLineId)&&(identical(other.autoRecover, autoRecover) || other.autoRecover == autoRecover)&&(identical(other.maxRecoveryAttempts, maxRecoveryAttempts) || other.maxRecoveryAttempts == maxRecoveryAttempts));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,quality,engineId,linePreference,preferredLineId,autoRecover,maxRecoveryAttempts);
}

@override
String toString() {
    return 'PlaybackPreferences(quality: $quality, engineId: $engineId, linePreference: $linePreference, preferredLineId: $preferredLineId, autoRecover: $autoRecover, maxRecoveryAttempts: $maxRecoveryAttempts)';
}


}

/// @nodoc
abstract mixin class _$PlaybackPreferencesCopyWith<$Res> implements $PlaybackPreferencesCopyWith<$Res> {
  factory _$PlaybackPreferencesCopyWith(_PlaybackPreferences value, $Res Function(_PlaybackPreferences) _then) = __$PlaybackPreferencesCopyWithImpl;
@override @useResult
$Res call({
 String quality, String engineId, LinePreference linePreference, String preferredLineId, bool autoRecover, int maxRecoveryAttempts
});




}
/// @nodoc
class __$PlaybackPreferencesCopyWithImpl<$Res>
    implements _$PlaybackPreferencesCopyWith<$Res> {
  __$PlaybackPreferencesCopyWithImpl(this._self, this._then);

  final _PlaybackPreferences _self;
  final $Res Function(_PlaybackPreferences) _then;

/// Create a copy of PlaybackPreferences
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? quality = null,Object? engineId = null,Object? linePreference = null,Object? preferredLineId = null,Object? autoRecover = null,Object? maxRecoveryAttempts = null,}) {
  return _then(_PlaybackPreferences(
quality: null == quality ? _self.quality : quality // ignore: cast_nullable_to_non_nullable
as String,engineId: null == engineId ? _self.engineId : engineId // ignore: cast_nullable_to_non_nullable
as String,linePreference: null == linePreference ? _self.linePreference : linePreference // ignore: cast_nullable_to_non_nullable
as LinePreference,preferredLineId: null == preferredLineId ? _self.preferredLineId : preferredLineId // ignore: cast_nullable_to_non_nullable
as String,autoRecover: null == autoRecover ? _self.autoRecover : autoRecover // ignore: cast_nullable_to_non_nullable
as bool,maxRecoveryAttempts: null == maxRecoveryAttempts ? _self.maxRecoveryAttempts : maxRecoveryAttempts // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
