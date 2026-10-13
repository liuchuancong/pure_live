// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'live_play_line.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$LivePlayLine {

 String get url; LiveStreamFormat get format; LivePlayFormatSource get formatSource; Map<String, String> get headers; LiveStreamCodec? get codec; String? get lineLabel; LivePlayLease? get lease; PlayGeometry get geometry;/// Whether this URL starts playback only once: re-opening the same
/// address fails even before its lease expires, and the player must
/// re-resolve instead of replaying it. Long-lived, re-openable lines
/// stay false.
 bool get singleUse;
/// Create a copy of LivePlayLine
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LivePlayLineCopyWith<LivePlayLine> get copyWith => _$LivePlayLineCopyWithImpl<LivePlayLine>(this as LivePlayLine, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as LivePlayLine;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LivePlayLine&&(identical(other.url, _this.url) || other.url == _this.url)&&(identical(other.format, _this.format) || other.format == _this.format)&&(identical(other.formatSource, _this.formatSource) || other.formatSource == _this.formatSource)&&const DeepCollectionEquality().equals(other.headers, _this.headers)&&(identical(other.codec, _this.codec) || other.codec == _this.codec)&&(identical(other.lineLabel, _this.lineLabel) || other.lineLabel == _this.lineLabel)&&(identical(other.lease, _this.lease) || other.lease == _this.lease)&&(identical(other.geometry, _this.geometry) || other.geometry == _this.geometry)&&(identical(other.singleUse, _this.singleUse) || other.singleUse == _this.singleUse));
}


@override
int get hashCode {
  final _this = this as LivePlayLine;
  return Object.hash(runtimeType,_this.url,_this.format,_this.formatSource,const DeepCollectionEquality().hash(_this.headers),_this.codec,_this.lineLabel,_this.lease,_this.geometry,_this.singleUse);
}

@override
String toString() {
  final _this = this as LivePlayLine;
  return 'LivePlayLine(url: ${_this.url}, format: ${_this.format}, formatSource: ${_this.formatSource}, headers: ${_this.headers}, codec: ${_this.codec}, lineLabel: ${_this.lineLabel}, lease: ${_this.lease}, geometry: ${_this.geometry}, singleUse: ${_this.singleUse})';
}


}

/// @nodoc
abstract mixin class $LivePlayLineCopyWith<$Res>  {
  factory $LivePlayLineCopyWith(LivePlayLine value, $Res Function(LivePlayLine) _then) = _$LivePlayLineCopyWithImpl;
@useResult
$Res call({
 String url, LiveStreamFormat format, LivePlayFormatSource formatSource, Map<String, String> headers, LiveStreamCodec? codec, String? lineLabel, LivePlayLease? lease, PlayGeometry geometry, bool singleUse
});


$LivePlayLeaseCopyWith<$Res>? get lease;$PlayGeometryCopyWith<$Res> get geometry;

}
/// @nodoc
class _$LivePlayLineCopyWithImpl<$Res>
    implements $LivePlayLineCopyWith<$Res> {
  _$LivePlayLineCopyWithImpl(this._self, this._then);

  final LivePlayLine _self;
  final $Res Function(LivePlayLine) _then;

/// Create a copy of LivePlayLine
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? url = null,Object? format = null,Object? formatSource = null,Object? headers = null,Object? codec = freezed,Object? lineLabel = freezed,Object? lease = freezed,Object? geometry = null,Object? singleUse = null,}) {
  return _then(LivePlayLine(
url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,format: null == format ? _self.format : format // ignore: cast_nullable_to_non_nullable
as LiveStreamFormat,formatSource: null == formatSource ? _self.formatSource : formatSource // ignore: cast_nullable_to_non_nullable
as LivePlayFormatSource,headers: null == headers ? _self.headers : headers // ignore: cast_nullable_to_non_nullable
as Map<String, String>,codec: freezed == codec ? _self.codec : codec // ignore: cast_nullable_to_non_nullable
as LiveStreamCodec?,lineLabel: freezed == lineLabel ? _self.lineLabel : lineLabel // ignore: cast_nullable_to_non_nullable
as String?,lease: freezed == lease ? _self.lease : lease // ignore: cast_nullable_to_non_nullable
as LivePlayLease?,geometry: null == geometry ? _self.geometry : geometry // ignore: cast_nullable_to_non_nullable
as PlayGeometry,singleUse: null == singleUse ? _self.singleUse : singleUse // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of LivePlayLine
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LivePlayLeaseCopyWith<$Res>? get lease {
    if (_self.lease == null) {
    return null;
  }

  return $LivePlayLeaseCopyWith<$Res>(_self.lease!, (value) {
    return _then(_self.copyWith(lease: value));
  });
}/// Create a copy of LivePlayLine
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PlayGeometryCopyWith<$Res> get geometry {
  
  return $PlayGeometryCopyWith<$Res>(_self.geometry, (value) {
    return _then(_self.copyWith(geometry: value));
  });
}
}


/// Adds pattern-matching-related methods to [LivePlayLine].
extension LivePlayLinePatterns on LivePlayLine {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LivePlayLine value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LivePlayLine() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LivePlayLine value)  $default,){
final _that = this;
switch (_that) {
case _LivePlayLine():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LivePlayLine value)?  $default,){
final _that = this;
switch (_that) {
case _LivePlayLine() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String url,  LiveStreamFormat format,  LivePlayFormatSource formatSource,  Map<String, String> headers,  LiveStreamCodec? codec,  String? lineLabel,  LivePlayLease? lease,  PlayGeometry geometry,  bool singleUse)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LivePlayLine() when $default != null:
return $default(_that.url,_that.format,_that.formatSource,_that.headers,_that.codec,_that.lineLabel,_that.lease,_that.geometry,_that.singleUse);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String url,  LiveStreamFormat format,  LivePlayFormatSource formatSource,  Map<String, String> headers,  LiveStreamCodec? codec,  String? lineLabel,  LivePlayLease? lease,  PlayGeometry geometry,  bool singleUse)  $default,) {final _that = this;
switch (_that) {
case _LivePlayLine():
return $default(_that.url,_that.format,_that.formatSource,_that.headers,_that.codec,_that.lineLabel,_that.lease,_that.geometry,_that.singleUse);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String url,  LiveStreamFormat format,  LivePlayFormatSource formatSource,  Map<String, String> headers,  LiveStreamCodec? codec,  String? lineLabel,  LivePlayLease? lease,  PlayGeometry geometry,  bool singleUse)?  $default,) {final _that = this;
switch (_that) {
case _LivePlayLine() when $default != null:
return $default(_that.url,_that.format,_that.formatSource,_that.headers,_that.codec,_that.lineLabel,_that.lease,_that.geometry,_that.singleUse);case _:
  return null;

}
}

}

/// @nodoc


class _LivePlayLine implements LivePlayLine {
  const _LivePlayLine({required this.url, required this.format, required this.formatSource,  Map<String, String> headers = const {}, this.codec, this.lineLabel, this.lease, this.geometry = const PlayGeometry(), this.singleUse = false}): _headers = headers;
  

@override final  String url;
@override final  LiveStreamFormat format;
@override final  LivePlayFormatSource formatSource;
 final  Map<String, String> _headers;
@override@JsonKey() Map<String, String> get headers {
  if (_headers is EqualUnmodifiableMapView) return _headers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_headers);
}

@override final  LiveStreamCodec? codec;
@override final  String? lineLabel;
@override final  LivePlayLease? lease;
@override@JsonKey() final  PlayGeometry geometry;
/// Whether this URL starts playback only once: re-opening the same
/// address fails even before its lease expires, and the player must
/// re-resolve instead of replaying it. Long-lived, re-openable lines
/// stay false.
@override@JsonKey() final  bool singleUse;

/// Create a copy of LivePlayLine
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LivePlayLineCopyWith<_LivePlayLine> get copyWith => __$LivePlayLineCopyWithImpl<_LivePlayLine>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LivePlayLine&&(identical(other.url, url) || other.url == url)&&(identical(other.format, format) || other.format == format)&&(identical(other.formatSource, formatSource) || other.formatSource == formatSource)&&const DeepCollectionEquality().equals(other.headers, _headers)&&(identical(other.codec, codec) || other.codec == codec)&&(identical(other.lineLabel, lineLabel) || other.lineLabel == lineLabel)&&(identical(other.lease, lease) || other.lease == lease)&&(identical(other.geometry, geometry) || other.geometry == geometry)&&(identical(other.singleUse, singleUse) || other.singleUse == singleUse));
}


@override
int get hashCode {
    return Object.hash(runtimeType,url,format,formatSource,const DeepCollectionEquality().hash(_headers),codec,lineLabel,lease,geometry,singleUse);
}

@override
String toString() {
    return 'LivePlayLine(url: $url, format: $format, formatSource: $formatSource, headers: $headers, codec: $codec, lineLabel: $lineLabel, lease: $lease, geometry: $geometry, singleUse: $singleUse)';
}


}

/// @nodoc
abstract mixin class _$LivePlayLineCopyWith<$Res> implements $LivePlayLineCopyWith<$Res> {
  factory _$LivePlayLineCopyWith(_LivePlayLine value, $Res Function(_LivePlayLine) _then) = __$LivePlayLineCopyWithImpl;
@override @useResult
$Res call({
 String url, LiveStreamFormat format, LivePlayFormatSource formatSource, Map<String, String> headers, LiveStreamCodec? codec, String? lineLabel, LivePlayLease? lease, PlayGeometry geometry, bool singleUse
});


@override $LivePlayLeaseCopyWith<$Res>? get lease;@override $PlayGeometryCopyWith<$Res> get geometry;

}
/// @nodoc
class __$LivePlayLineCopyWithImpl<$Res>
    implements _$LivePlayLineCopyWith<$Res> {
  __$LivePlayLineCopyWithImpl(this._self, this._then);

  final _LivePlayLine _self;
  final $Res Function(_LivePlayLine) _then;

/// Create a copy of LivePlayLine
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? url = null,Object? format = null,Object? formatSource = null,Object? headers = null,Object? codec = freezed,Object? lineLabel = freezed,Object? lease = freezed,Object? geometry = null,Object? singleUse = null,}) {
  return _then(_LivePlayLine(
url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,format: null == format ? _self.format : format // ignore: cast_nullable_to_non_nullable
as LiveStreamFormat,formatSource: null == formatSource ? _self.formatSource : formatSource // ignore: cast_nullable_to_non_nullable
as LivePlayFormatSource,headers: null == headers ? _self._headers : headers // ignore: cast_nullable_to_non_nullable
as Map<String, String>,codec: freezed == codec ? _self.codec : codec // ignore: cast_nullable_to_non_nullable
as LiveStreamCodec?,lineLabel: freezed == lineLabel ? _self.lineLabel : lineLabel // ignore: cast_nullable_to_non_nullable
as String?,lease: freezed == lease ? _self.lease : lease // ignore: cast_nullable_to_non_nullable
as LivePlayLease?,geometry: null == geometry ? _self.geometry : geometry // ignore: cast_nullable_to_non_nullable
as PlayGeometry,singleUse: null == singleUse ? _self.singleUse : singleUse // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of LivePlayLine
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LivePlayLeaseCopyWith<$Res>? get lease {
    if (_self.lease == null) {
    return null;
  }

  return $LivePlayLeaseCopyWith<$Res>(_self.lease!, (value) {
    return _then(_self.copyWith(lease: value));
  });
}/// Create a copy of LivePlayLine
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PlayGeometryCopyWith<$Res> get geometry {
  
  return $PlayGeometryCopyWith<$Res>(_self.geometry, (value) {
    return _then(_self.copyWith(geometry: value));
  });
}
}

// dart format on
