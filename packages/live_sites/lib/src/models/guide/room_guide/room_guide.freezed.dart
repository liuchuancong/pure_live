// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'room_guide.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RoomGuide {

 String? get epgId; String get currentProgramme; String? get currentProgrammeDescription; GuideCatchUp get catchUp; Map<String, String> get httpHeaders;
/// Create a copy of RoomGuide
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RoomGuideCopyWith<RoomGuide> get copyWith => _$RoomGuideCopyWithImpl<RoomGuide>(this as RoomGuide, _$identity);

  /// Serializes this RoomGuide to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RoomGuide;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RoomGuide&&(identical(other.epgId, _this.epgId) || other.epgId == _this.epgId)&&(identical(other.currentProgramme, _this.currentProgramme) || other.currentProgramme == _this.currentProgramme)&&(identical(other.currentProgrammeDescription, _this.currentProgrammeDescription) || other.currentProgrammeDescription == _this.currentProgrammeDescription)&&(identical(other.catchUp, _this.catchUp) || other.catchUp == _this.catchUp)&&const DeepCollectionEquality().equals(other.httpHeaders, _this.httpHeaders));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RoomGuide;
  return Object.hash(runtimeType,_this.epgId,_this.currentProgramme,_this.currentProgrammeDescription,_this.catchUp,const DeepCollectionEquality().hash(_this.httpHeaders));
}

@override
String toString() {
  final _this = this as RoomGuide;
  return 'RoomGuide(epgId: ${_this.epgId}, currentProgramme: ${_this.currentProgramme}, currentProgrammeDescription: ${_this.currentProgrammeDescription}, catchUp: ${_this.catchUp}, httpHeaders: ${_this.httpHeaders})';
}


}

/// @nodoc
abstract mixin class $RoomGuideCopyWith<$Res>  {
  factory $RoomGuideCopyWith(RoomGuide value, $Res Function(RoomGuide) _then) = _$RoomGuideCopyWithImpl;
@useResult
$Res call({
 String? epgId, String currentProgramme, String? currentProgrammeDescription, GuideCatchUp catchUp, Map<String, String> httpHeaders
});


$GuideCatchUpCopyWith<$Res> get catchUp;

}
/// @nodoc
class _$RoomGuideCopyWithImpl<$Res>
    implements $RoomGuideCopyWith<$Res> {
  _$RoomGuideCopyWithImpl(this._self, this._then);

  final RoomGuide _self;
  final $Res Function(RoomGuide) _then;

/// Create a copy of RoomGuide
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? epgId = freezed,Object? currentProgramme = null,Object? currentProgrammeDescription = freezed,Object? catchUp = null,Object? httpHeaders = null,}) {
  return _then(RoomGuide(
epgId: freezed == epgId ? _self.epgId : epgId // ignore: cast_nullable_to_non_nullable
as String?,currentProgramme: null == currentProgramme ? _self.currentProgramme : currentProgramme // ignore: cast_nullable_to_non_nullable
as String,currentProgrammeDescription: freezed == currentProgrammeDescription ? _self.currentProgrammeDescription : currentProgrammeDescription // ignore: cast_nullable_to_non_nullable
as String?,catchUp: null == catchUp ? _self.catchUp : catchUp // ignore: cast_nullable_to_non_nullable
as GuideCatchUp,httpHeaders: null == httpHeaders ? _self.httpHeaders : httpHeaders // ignore: cast_nullable_to_non_nullable
as Map<String, String>,
  ));
}
/// Create a copy of RoomGuide
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GuideCatchUpCopyWith<$Res> get catchUp {
  
  return $GuideCatchUpCopyWith<$Res>(_self.catchUp, (value) {
    return _then(_self.copyWith(catchUp: value));
  });
}
}


/// Adds pattern-matching-related methods to [RoomGuide].
extension RoomGuidePatterns on RoomGuide {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RoomGuide value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RoomGuide() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RoomGuide value)  $default,){
final _that = this;
switch (_that) {
case _RoomGuide():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RoomGuide value)?  $default,){
final _that = this;
switch (_that) {
case _RoomGuide() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? epgId,  String currentProgramme,  String? currentProgrammeDescription,  GuideCatchUp catchUp,  Map<String, String> httpHeaders)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RoomGuide() when $default != null:
return $default(_that.epgId,_that.currentProgramme,_that.currentProgrammeDescription,_that.catchUp,_that.httpHeaders);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? epgId,  String currentProgramme,  String? currentProgrammeDescription,  GuideCatchUp catchUp,  Map<String, String> httpHeaders)  $default,) {final _that = this;
switch (_that) {
case _RoomGuide():
return $default(_that.epgId,_that.currentProgramme,_that.currentProgrammeDescription,_that.catchUp,_that.httpHeaders);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? epgId,  String currentProgramme,  String? currentProgrammeDescription,  GuideCatchUp catchUp,  Map<String, String> httpHeaders)?  $default,) {final _that = this;
switch (_that) {
case _RoomGuide() when $default != null:
return $default(_that.epgId,_that.currentProgramme,_that.currentProgrammeDescription,_that.catchUp,_that.httpHeaders);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RoomGuide extends RoomGuide {
  const _RoomGuide({this.epgId, this.currentProgramme = '', this.currentProgrammeDescription, this.catchUp = const GuideCatchUp(),  Map<String, String> httpHeaders = const {}}): _httpHeaders = httpHeaders,super._();
  factory _RoomGuide.fromJson(Map<String, dynamic> json) => _$RoomGuideFromJson(json);

@override final  String? epgId;
@override@JsonKey() final  String currentProgramme;
@override final  String? currentProgrammeDescription;
@override@JsonKey() final  GuideCatchUp catchUp;
 final  Map<String, String> _httpHeaders;
@override@JsonKey() Map<String, String> get httpHeaders {
  if (_httpHeaders is EqualUnmodifiableMapView) return _httpHeaders;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_httpHeaders);
}


/// Create a copy of RoomGuide
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RoomGuideCopyWith<_RoomGuide> get copyWith => __$RoomGuideCopyWithImpl<_RoomGuide>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RoomGuideToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RoomGuide&&(identical(other.epgId, epgId) || other.epgId == epgId)&&(identical(other.currentProgramme, currentProgramme) || other.currentProgramme == currentProgramme)&&(identical(other.currentProgrammeDescription, currentProgrammeDescription) || other.currentProgrammeDescription == currentProgrammeDescription)&&(identical(other.catchUp, catchUp) || other.catchUp == catchUp)&&const DeepCollectionEquality().equals(other.httpHeaders, _httpHeaders));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,epgId,currentProgramme,currentProgrammeDescription,catchUp,const DeepCollectionEquality().hash(_httpHeaders));
}

@override
String toString() {
    return 'RoomGuide(epgId: $epgId, currentProgramme: $currentProgramme, currentProgrammeDescription: $currentProgrammeDescription, catchUp: $catchUp, httpHeaders: $httpHeaders)';
}


}

/// @nodoc
abstract mixin class _$RoomGuideCopyWith<$Res> implements $RoomGuideCopyWith<$Res> {
  factory _$RoomGuideCopyWith(_RoomGuide value, $Res Function(_RoomGuide) _then) = __$RoomGuideCopyWithImpl;
@override @useResult
$Res call({
 String? epgId, String currentProgramme, String? currentProgrammeDescription, GuideCatchUp catchUp, Map<String, String> httpHeaders
});


@override $GuideCatchUpCopyWith<$Res> get catchUp;

}
/// @nodoc
class __$RoomGuideCopyWithImpl<$Res>
    implements _$RoomGuideCopyWith<$Res> {
  __$RoomGuideCopyWithImpl(this._self, this._then);

  final _RoomGuide _self;
  final $Res Function(_RoomGuide) _then;

/// Create a copy of RoomGuide
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? epgId = freezed,Object? currentProgramme = null,Object? currentProgrammeDescription = freezed,Object? catchUp = null,Object? httpHeaders = null,}) {
  return _then(_RoomGuide(
epgId: freezed == epgId ? _self.epgId : epgId // ignore: cast_nullable_to_non_nullable
as String?,currentProgramme: null == currentProgramme ? _self.currentProgramme : currentProgramme // ignore: cast_nullable_to_non_nullable
as String,currentProgrammeDescription: freezed == currentProgrammeDescription ? _self.currentProgrammeDescription : currentProgrammeDescription // ignore: cast_nullable_to_non_nullable
as String?,catchUp: null == catchUp ? _self.catchUp : catchUp // ignore: cast_nullable_to_non_nullable
as GuideCatchUp,httpHeaders: null == httpHeaders ? _self._httpHeaders : httpHeaders // ignore: cast_nullable_to_non_nullable
as Map<String, String>,
  ));
}

/// Create a copy of RoomGuide
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GuideCatchUpCopyWith<$Res> get catchUp {
  
  return $GuideCatchUpCopyWith<$Res>(_self.catchUp, (value) {
    return _then(_self.copyWith(catchUp: value));
  });
}
}

// dart format on
