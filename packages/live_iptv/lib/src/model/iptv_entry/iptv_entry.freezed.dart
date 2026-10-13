// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'iptv_entry.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$IptvEntry {

 String get name; String get url; String? get group; String? get tvgId; String? get tvgLogo; int? get channelNumber; Map<String, String> get headers; List<String> get alternatives; String? get catchupSource; String? get catchupMode; String? get catchupDays;
/// Create a copy of IptvEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$IptvEntryCopyWith<IptvEntry> get copyWith => _$IptvEntryCopyWithImpl<IptvEntry>(this as IptvEntry, _$identity);

  /// Serializes this IptvEntry to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as IptvEntry;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is IptvEntry&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.url, _this.url) || other.url == _this.url)&&(identical(other.group, _this.group) || other.group == _this.group)&&(identical(other.tvgId, _this.tvgId) || other.tvgId == _this.tvgId)&&(identical(other.tvgLogo, _this.tvgLogo) || other.tvgLogo == _this.tvgLogo)&&(identical(other.channelNumber, _this.channelNumber) || other.channelNumber == _this.channelNumber)&&const DeepCollectionEquality().equals(other.headers, _this.headers)&&const DeepCollectionEquality().equals(other.alternatives, _this.alternatives)&&(identical(other.catchupSource, _this.catchupSource) || other.catchupSource == _this.catchupSource)&&(identical(other.catchupMode, _this.catchupMode) || other.catchupMode == _this.catchupMode)&&(identical(other.catchupDays, _this.catchupDays) || other.catchupDays == _this.catchupDays));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as IptvEntry;
  return Object.hash(runtimeType,_this.name,_this.url,_this.group,_this.tvgId,_this.tvgLogo,_this.channelNumber,const DeepCollectionEquality().hash(_this.headers),const DeepCollectionEquality().hash(_this.alternatives),_this.catchupSource,_this.catchupMode,_this.catchupDays);
}

@override
String toString() {
  final _this = this as IptvEntry;
  return 'IptvEntry(name: ${_this.name}, url: ${_this.url}, group: ${_this.group}, tvgId: ${_this.tvgId}, tvgLogo: ${_this.tvgLogo}, channelNumber: ${_this.channelNumber}, headers: ${_this.headers}, alternatives: ${_this.alternatives}, catchupSource: ${_this.catchupSource}, catchupMode: ${_this.catchupMode}, catchupDays: ${_this.catchupDays})';
}


}

/// @nodoc
abstract mixin class $IptvEntryCopyWith<$Res>  {
  factory $IptvEntryCopyWith(IptvEntry value, $Res Function(IptvEntry) _then) = _$IptvEntryCopyWithImpl;
@useResult
$Res call({
 String name, String url, String? group, String? tvgId, String? tvgLogo, int? channelNumber, Map<String, String> headers, List<String> alternatives, String? catchupSource, String? catchupMode, String? catchupDays
});




}
/// @nodoc
class _$IptvEntryCopyWithImpl<$Res>
    implements $IptvEntryCopyWith<$Res> {
  _$IptvEntryCopyWithImpl(this._self, this._then);

  final IptvEntry _self;
  final $Res Function(IptvEntry) _then;

/// Create a copy of IptvEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? url = null,Object? group = freezed,Object? tvgId = freezed,Object? tvgLogo = freezed,Object? channelNumber = freezed,Object? headers = null,Object? alternatives = null,Object? catchupSource = freezed,Object? catchupMode = freezed,Object? catchupDays = freezed,}) {
  return _then(IptvEntry(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,group: freezed == group ? _self.group : group // ignore: cast_nullable_to_non_nullable
as String?,tvgId: freezed == tvgId ? _self.tvgId : tvgId // ignore: cast_nullable_to_non_nullable
as String?,tvgLogo: freezed == tvgLogo ? _self.tvgLogo : tvgLogo // ignore: cast_nullable_to_non_nullable
as String?,channelNumber: freezed == channelNumber ? _self.channelNumber : channelNumber // ignore: cast_nullable_to_non_nullable
as int?,headers: null == headers ? _self.headers : headers // ignore: cast_nullable_to_non_nullable
as Map<String, String>,alternatives: null == alternatives ? _self.alternatives : alternatives // ignore: cast_nullable_to_non_nullable
as List<String>,catchupSource: freezed == catchupSource ? _self.catchupSource : catchupSource // ignore: cast_nullable_to_non_nullable
as String?,catchupMode: freezed == catchupMode ? _self.catchupMode : catchupMode // ignore: cast_nullable_to_non_nullable
as String?,catchupDays: freezed == catchupDays ? _self.catchupDays : catchupDays // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [IptvEntry].
extension IptvEntryPatterns on IptvEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _IptvEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _IptvEntry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _IptvEntry value)  $default,){
final _that = this;
switch (_that) {
case _IptvEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _IptvEntry value)?  $default,){
final _that = this;
switch (_that) {
case _IptvEntry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String url,  String? group,  String? tvgId,  String? tvgLogo,  int? channelNumber,  Map<String, String> headers,  List<String> alternatives,  String? catchupSource,  String? catchupMode,  String? catchupDays)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _IptvEntry() when $default != null:
return $default(_that.name,_that.url,_that.group,_that.tvgId,_that.tvgLogo,_that.channelNumber,_that.headers,_that.alternatives,_that.catchupSource,_that.catchupMode,_that.catchupDays);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String url,  String? group,  String? tvgId,  String? tvgLogo,  int? channelNumber,  Map<String, String> headers,  List<String> alternatives,  String? catchupSource,  String? catchupMode,  String? catchupDays)  $default,) {final _that = this;
switch (_that) {
case _IptvEntry():
return $default(_that.name,_that.url,_that.group,_that.tvgId,_that.tvgLogo,_that.channelNumber,_that.headers,_that.alternatives,_that.catchupSource,_that.catchupMode,_that.catchupDays);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String url,  String? group,  String? tvgId,  String? tvgLogo,  int? channelNumber,  Map<String, String> headers,  List<String> alternatives,  String? catchupSource,  String? catchupMode,  String? catchupDays)?  $default,) {final _that = this;
switch (_that) {
case _IptvEntry() when $default != null:
return $default(_that.name,_that.url,_that.group,_that.tvgId,_that.tvgLogo,_that.channelNumber,_that.headers,_that.alternatives,_that.catchupSource,_that.catchupMode,_that.catchupDays);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _IptvEntry implements IptvEntry {
  const _IptvEntry({required this.name, required this.url, this.group, this.tvgId, this.tvgLogo, this.channelNumber,  Map<String, String> headers = const <String, String>{},  List<String> alternatives = const <String>[], this.catchupSource, this.catchupMode, this.catchupDays}): _headers = headers,_alternatives = alternatives;
  factory _IptvEntry.fromJson(Map<String, dynamic> json) => _$IptvEntryFromJson(json);

@override final  String name;
@override final  String url;
@override final  String? group;
@override final  String? tvgId;
@override final  String? tvgLogo;
@override final  int? channelNumber;
 final  Map<String, String> _headers;
@override@JsonKey() Map<String, String> get headers {
  if (_headers is EqualUnmodifiableMapView) return _headers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_headers);
}

 final  List<String> _alternatives;
@override@JsonKey() List<String> get alternatives {
  if (_alternatives is EqualUnmodifiableListView) return _alternatives;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_alternatives);
}

@override final  String? catchupSource;
@override final  String? catchupMode;
@override final  String? catchupDays;

/// Create a copy of IptvEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$IptvEntryCopyWith<_IptvEntry> get copyWith => __$IptvEntryCopyWithImpl<_IptvEntry>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$IptvEntryToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _IptvEntry&&(identical(other.name, name) || other.name == name)&&(identical(other.url, url) || other.url == url)&&(identical(other.group, group) || other.group == group)&&(identical(other.tvgId, tvgId) || other.tvgId == tvgId)&&(identical(other.tvgLogo, tvgLogo) || other.tvgLogo == tvgLogo)&&(identical(other.channelNumber, channelNumber) || other.channelNumber == channelNumber)&&const DeepCollectionEquality().equals(other.headers, _headers)&&const DeepCollectionEquality().equals(other.alternatives, _alternatives)&&(identical(other.catchupSource, catchupSource) || other.catchupSource == catchupSource)&&(identical(other.catchupMode, catchupMode) || other.catchupMode == catchupMode)&&(identical(other.catchupDays, catchupDays) || other.catchupDays == catchupDays));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,name,url,group,tvgId,tvgLogo,channelNumber,const DeepCollectionEquality().hash(_headers),const DeepCollectionEquality().hash(_alternatives),catchupSource,catchupMode,catchupDays);
}

@override
String toString() {
    return 'IptvEntry(name: $name, url: $url, group: $group, tvgId: $tvgId, tvgLogo: $tvgLogo, channelNumber: $channelNumber, headers: $headers, alternatives: $alternatives, catchupSource: $catchupSource, catchupMode: $catchupMode, catchupDays: $catchupDays)';
}


}

/// @nodoc
abstract mixin class _$IptvEntryCopyWith<$Res> implements $IptvEntryCopyWith<$Res> {
  factory _$IptvEntryCopyWith(_IptvEntry value, $Res Function(_IptvEntry) _then) = __$IptvEntryCopyWithImpl;
@override @useResult
$Res call({
 String name, String url, String? group, String? tvgId, String? tvgLogo, int? channelNumber, Map<String, String> headers, List<String> alternatives, String? catchupSource, String? catchupMode, String? catchupDays
});




}
/// @nodoc
class __$IptvEntryCopyWithImpl<$Res>
    implements _$IptvEntryCopyWith<$Res> {
  __$IptvEntryCopyWithImpl(this._self, this._then);

  final _IptvEntry _self;
  final $Res Function(_IptvEntry) _then;

/// Create a copy of IptvEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? url = null,Object? group = freezed,Object? tvgId = freezed,Object? tvgLogo = freezed,Object? channelNumber = freezed,Object? headers = null,Object? alternatives = null,Object? catchupSource = freezed,Object? catchupMode = freezed,Object? catchupDays = freezed,}) {
  return _then(_IptvEntry(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,group: freezed == group ? _self.group : group // ignore: cast_nullable_to_non_nullable
as String?,tvgId: freezed == tvgId ? _self.tvgId : tvgId // ignore: cast_nullable_to_non_nullable
as String?,tvgLogo: freezed == tvgLogo ? _self.tvgLogo : tvgLogo // ignore: cast_nullable_to_non_nullable
as String?,channelNumber: freezed == channelNumber ? _self.channelNumber : channelNumber // ignore: cast_nullable_to_non_nullable
as int?,headers: null == headers ? _self._headers : headers // ignore: cast_nullable_to_non_nullable
as Map<String, String>,alternatives: null == alternatives ? _self._alternatives : alternatives // ignore: cast_nullable_to_non_nullable
as List<String>,catchupSource: freezed == catchupSource ? _self.catchupSource : catchupSource // ignore: cast_nullable_to_non_nullable
as String?,catchupMode: freezed == catchupMode ? _self.catchupMode : catchupMode // ignore: cast_nullable_to_non_nullable
as String?,catchupDays: freezed == catchupDays ? _self.catchupDays : catchupDays // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
