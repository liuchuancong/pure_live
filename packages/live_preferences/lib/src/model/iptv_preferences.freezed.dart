// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'iptv_preferences.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$IptvPreferences {

/// Whether imported playlists with a recorded address are re-downloaded
/// when they have gone stale.
 bool get autoSyncPlaylists;/// How old a playlist import must be before it is refreshed.
 Duration get playlistSyncInterval;/// Whether guide sources are re-downloaded when they have gone stale.
 bool get autoSyncGuides;/// How old a guide refresh must be before it is re-downloaded. Shorter
/// than the playlists': a programme list covers the next day or two.
 Duration get guideSyncInterval;/// How long a line-probe verdict is believed before it is treated as
/// "nobody knows" again. Yesterday's dead mirror is tonight's unknown.
 Duration get lineHealthFreshness;
/// Create a copy of IptvPreferences
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$IptvPreferencesCopyWith<IptvPreferences> get copyWith => _$IptvPreferencesCopyWithImpl<IptvPreferences>(this as IptvPreferences, _$identity);

  /// Serializes this IptvPreferences to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as IptvPreferences;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is IptvPreferences&&(identical(other.autoSyncPlaylists, _this.autoSyncPlaylists) || other.autoSyncPlaylists == _this.autoSyncPlaylists)&&(identical(other.playlistSyncInterval, _this.playlistSyncInterval) || other.playlistSyncInterval == _this.playlistSyncInterval)&&(identical(other.autoSyncGuides, _this.autoSyncGuides) || other.autoSyncGuides == _this.autoSyncGuides)&&(identical(other.guideSyncInterval, _this.guideSyncInterval) || other.guideSyncInterval == _this.guideSyncInterval)&&(identical(other.lineHealthFreshness, _this.lineHealthFreshness) || other.lineHealthFreshness == _this.lineHealthFreshness));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as IptvPreferences;
  return Object.hash(runtimeType,_this.autoSyncPlaylists,_this.playlistSyncInterval,_this.autoSyncGuides,_this.guideSyncInterval,_this.lineHealthFreshness);
}

@override
String toString() {
  final _this = this as IptvPreferences;
  return 'IptvPreferences(autoSyncPlaylists: ${_this.autoSyncPlaylists}, playlistSyncInterval: ${_this.playlistSyncInterval}, autoSyncGuides: ${_this.autoSyncGuides}, guideSyncInterval: ${_this.guideSyncInterval}, lineHealthFreshness: ${_this.lineHealthFreshness})';
}


}

/// @nodoc
abstract mixin class $IptvPreferencesCopyWith<$Res>  {
  factory $IptvPreferencesCopyWith(IptvPreferences value, $Res Function(IptvPreferences) _then) = _$IptvPreferencesCopyWithImpl;
@useResult
$Res call({
 bool autoSyncPlaylists, Duration playlistSyncInterval, bool autoSyncGuides, Duration guideSyncInterval, Duration lineHealthFreshness
});




}
/// @nodoc
class _$IptvPreferencesCopyWithImpl<$Res>
    implements $IptvPreferencesCopyWith<$Res> {
  _$IptvPreferencesCopyWithImpl(this._self, this._then);

  final IptvPreferences _self;
  final $Res Function(IptvPreferences) _then;

/// Create a copy of IptvPreferences
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? autoSyncPlaylists = null,Object? playlistSyncInterval = null,Object? autoSyncGuides = null,Object? guideSyncInterval = null,Object? lineHealthFreshness = null,}) {
  return _then(IptvPreferences(
autoSyncPlaylists: null == autoSyncPlaylists ? _self.autoSyncPlaylists : autoSyncPlaylists // ignore: cast_nullable_to_non_nullable
as bool,playlistSyncInterval: null == playlistSyncInterval ? _self.playlistSyncInterval : playlistSyncInterval // ignore: cast_nullable_to_non_nullable
as Duration,autoSyncGuides: null == autoSyncGuides ? _self.autoSyncGuides : autoSyncGuides // ignore: cast_nullable_to_non_nullable
as bool,guideSyncInterval: null == guideSyncInterval ? _self.guideSyncInterval : guideSyncInterval // ignore: cast_nullable_to_non_nullable
as Duration,lineHealthFreshness: null == lineHealthFreshness ? _self.lineHealthFreshness : lineHealthFreshness // ignore: cast_nullable_to_non_nullable
as Duration,
  ));
}

}


/// Adds pattern-matching-related methods to [IptvPreferences].
extension IptvPreferencesPatterns on IptvPreferences {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _IptvPreferences value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _IptvPreferences() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _IptvPreferences value)  $default,){
final _that = this;
switch (_that) {
case _IptvPreferences():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _IptvPreferences value)?  $default,){
final _that = this;
switch (_that) {
case _IptvPreferences() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool autoSyncPlaylists,  Duration playlistSyncInterval,  bool autoSyncGuides,  Duration guideSyncInterval,  Duration lineHealthFreshness)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _IptvPreferences() when $default != null:
return $default(_that.autoSyncPlaylists,_that.playlistSyncInterval,_that.autoSyncGuides,_that.guideSyncInterval,_that.lineHealthFreshness);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool autoSyncPlaylists,  Duration playlistSyncInterval,  bool autoSyncGuides,  Duration guideSyncInterval,  Duration lineHealthFreshness)  $default,) {final _that = this;
switch (_that) {
case _IptvPreferences():
return $default(_that.autoSyncPlaylists,_that.playlistSyncInterval,_that.autoSyncGuides,_that.guideSyncInterval,_that.lineHealthFreshness);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool autoSyncPlaylists,  Duration playlistSyncInterval,  bool autoSyncGuides,  Duration guideSyncInterval,  Duration lineHealthFreshness)?  $default,) {final _that = this;
switch (_that) {
case _IptvPreferences() when $default != null:
return $default(_that.autoSyncPlaylists,_that.playlistSyncInterval,_that.autoSyncGuides,_that.guideSyncInterval,_that.lineHealthFreshness);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _IptvPreferences implements IptvPreferences {
  const _IptvPreferences({this.autoSyncPlaylists = true, this.playlistSyncInterval = const Duration(hours: 24), this.autoSyncGuides = true, this.guideSyncInterval = const Duration(hours: 6), this.lineHealthFreshness = const Duration(hours: 12)});
  factory _IptvPreferences.fromJson(Map<String, dynamic> json) => _$IptvPreferencesFromJson(json);

/// Whether imported playlists with a recorded address are re-downloaded
/// when they have gone stale.
@override@JsonKey() final  bool autoSyncPlaylists;
/// How old a playlist import must be before it is refreshed.
@override@JsonKey() final  Duration playlistSyncInterval;
/// Whether guide sources are re-downloaded when they have gone stale.
@override@JsonKey() final  bool autoSyncGuides;
/// How old a guide refresh must be before it is re-downloaded. Shorter
/// than the playlists': a programme list covers the next day or two.
@override@JsonKey() final  Duration guideSyncInterval;
/// How long a line-probe verdict is believed before it is treated as
/// "nobody knows" again. Yesterday's dead mirror is tonight's unknown.
@override@JsonKey() final  Duration lineHealthFreshness;

/// Create a copy of IptvPreferences
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$IptvPreferencesCopyWith<_IptvPreferences> get copyWith => __$IptvPreferencesCopyWithImpl<_IptvPreferences>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$IptvPreferencesToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _IptvPreferences&&(identical(other.autoSyncPlaylists, autoSyncPlaylists) || other.autoSyncPlaylists == autoSyncPlaylists)&&(identical(other.playlistSyncInterval, playlistSyncInterval) || other.playlistSyncInterval == playlistSyncInterval)&&(identical(other.autoSyncGuides, autoSyncGuides) || other.autoSyncGuides == autoSyncGuides)&&(identical(other.guideSyncInterval, guideSyncInterval) || other.guideSyncInterval == guideSyncInterval)&&(identical(other.lineHealthFreshness, lineHealthFreshness) || other.lineHealthFreshness == lineHealthFreshness));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,autoSyncPlaylists,playlistSyncInterval,autoSyncGuides,guideSyncInterval,lineHealthFreshness);
}

@override
String toString() {
    return 'IptvPreferences(autoSyncPlaylists: $autoSyncPlaylists, playlistSyncInterval: $playlistSyncInterval, autoSyncGuides: $autoSyncGuides, guideSyncInterval: $guideSyncInterval, lineHealthFreshness: $lineHealthFreshness)';
}


}

/// @nodoc
abstract mixin class _$IptvPreferencesCopyWith<$Res> implements $IptvPreferencesCopyWith<$Res> {
  factory _$IptvPreferencesCopyWith(_IptvPreferences value, $Res Function(_IptvPreferences) _then) = __$IptvPreferencesCopyWithImpl;
@override @useResult
$Res call({
 bool autoSyncPlaylists, Duration playlistSyncInterval, bool autoSyncGuides, Duration guideSyncInterval, Duration lineHealthFreshness
});




}
/// @nodoc
class __$IptvPreferencesCopyWithImpl<$Res>
    implements _$IptvPreferencesCopyWith<$Res> {
  __$IptvPreferencesCopyWithImpl(this._self, this._then);

  final _IptvPreferences _self;
  final $Res Function(_IptvPreferences) _then;

/// Create a copy of IptvPreferences
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? autoSyncPlaylists = null,Object? playlistSyncInterval = null,Object? autoSyncGuides = null,Object? guideSyncInterval = null,Object? lineHealthFreshness = null,}) {
  return _then(_IptvPreferences(
autoSyncPlaylists: null == autoSyncPlaylists ? _self.autoSyncPlaylists : autoSyncPlaylists // ignore: cast_nullable_to_non_nullable
as bool,playlistSyncInterval: null == playlistSyncInterval ? _self.playlistSyncInterval : playlistSyncInterval // ignore: cast_nullable_to_non_nullable
as Duration,autoSyncGuides: null == autoSyncGuides ? _self.autoSyncGuides : autoSyncGuides // ignore: cast_nullable_to_non_nullable
as bool,guideSyncInterval: null == guideSyncInterval ? _self.guideSyncInterval : guideSyncInterval // ignore: cast_nullable_to_non_nullable
as Duration,lineHealthFreshness: null == lineHealthFreshness ? _self.lineHealthFreshness : lineHealthFreshness // ignore: cast_nullable_to_non_nullable
as Duration,
  ));
}


}

// dart format on
