// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'iptv_channel_source.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$IptvLine {

 String get url; Map<String, String> get headers; String? get lineLabel;
/// Create a copy of IptvLine
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$IptvLineCopyWith<IptvLine> get copyWith => _$IptvLineCopyWithImpl<IptvLine>(this as IptvLine, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as IptvLine;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is IptvLine&&(identical(other.url, _this.url) || other.url == _this.url)&&const DeepCollectionEquality().equals(other.headers, _this.headers)&&(identical(other.lineLabel, _this.lineLabel) || other.lineLabel == _this.lineLabel));
}


@override
int get hashCode {
  final _this = this as IptvLine;
  return Object.hash(runtimeType,_this.url,const DeepCollectionEquality().hash(_this.headers),_this.lineLabel);
}

@override
String toString() {
  final _this = this as IptvLine;
  return 'IptvLine(url: ${_this.url}, headers: ${_this.headers}, lineLabel: ${_this.lineLabel})';
}


}

/// @nodoc
abstract mixin class $IptvLineCopyWith<$Res>  {
  factory $IptvLineCopyWith(IptvLine value, $Res Function(IptvLine) _then) = _$IptvLineCopyWithImpl;
@useResult
$Res call({
 String url, Map<String, String> headers, String? lineLabel
});




}
/// @nodoc
class _$IptvLineCopyWithImpl<$Res>
    implements $IptvLineCopyWith<$Res> {
  _$IptvLineCopyWithImpl(this._self, this._then);

  final IptvLine _self;
  final $Res Function(IptvLine) _then;

/// Create a copy of IptvLine
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? url = null,Object? headers = null,Object? lineLabel = freezed,}) {
  return _then(IptvLine(
url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,headers: null == headers ? _self.headers : headers // ignore: cast_nullable_to_non_nullable
as Map<String, String>,lineLabel: freezed == lineLabel ? _self.lineLabel : lineLabel // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [IptvLine].
extension IptvLinePatterns on IptvLine {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _IptvLine value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _IptvLine() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _IptvLine value)  $default,){
final _that = this;
switch (_that) {
case _IptvLine():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _IptvLine value)?  $default,){
final _that = this;
switch (_that) {
case _IptvLine() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String url,  Map<String, String> headers,  String? lineLabel)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _IptvLine() when $default != null:
return $default(_that.url,_that.headers,_that.lineLabel);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String url,  Map<String, String> headers,  String? lineLabel)  $default,) {final _that = this;
switch (_that) {
case _IptvLine():
return $default(_that.url,_that.headers,_that.lineLabel);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String url,  Map<String, String> headers,  String? lineLabel)?  $default,) {final _that = this;
switch (_that) {
case _IptvLine() when $default != null:
return $default(_that.url,_that.headers,_that.lineLabel);case _:
  return null;

}
}

}

/// @nodoc


class _IptvLine implements IptvLine {
  const _IptvLine({required this.url,  Map<String, String> headers = const {}, this.lineLabel}): _headers = headers;
  

@override final  String url;
 final  Map<String, String> _headers;
@override@JsonKey() Map<String, String> get headers {
  if (_headers is EqualUnmodifiableMapView) return _headers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_headers);
}

@override final  String? lineLabel;

/// Create a copy of IptvLine
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$IptvLineCopyWith<_IptvLine> get copyWith => __$IptvLineCopyWithImpl<_IptvLine>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _IptvLine&&(identical(other.url, url) || other.url == url)&&const DeepCollectionEquality().equals(other.headers, _headers)&&(identical(other.lineLabel, lineLabel) || other.lineLabel == lineLabel));
}


@override
int get hashCode {
    return Object.hash(runtimeType,url,const DeepCollectionEquality().hash(_headers),lineLabel);
}

@override
String toString() {
    return 'IptvLine(url: $url, headers: $headers, lineLabel: $lineLabel)';
}


}

/// @nodoc
abstract mixin class _$IptvLineCopyWith<$Res> implements $IptvLineCopyWith<$Res> {
  factory _$IptvLineCopyWith(_IptvLine value, $Res Function(_IptvLine) _then) = __$IptvLineCopyWithImpl;
@override @useResult
$Res call({
 String url, Map<String, String> headers, String? lineLabel
});




}
/// @nodoc
class __$IptvLineCopyWithImpl<$Res>
    implements _$IptvLineCopyWith<$Res> {
  __$IptvLineCopyWithImpl(this._self, this._then);

  final _IptvLine _self;
  final $Res Function(_IptvLine) _then;

/// Create a copy of IptvLine
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? url = null,Object? headers = null,Object? lineLabel = freezed,}) {
  return _then(_IptvLine(
url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,headers: null == headers ? _self._headers : headers // ignore: cast_nullable_to_non_nullable
as Map<String, String>,lineLabel: freezed == lineLabel ? _self.lineLabel : lineLabel // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$IptvChannel {

 String get id; String get name; String get url; String? get group; Map<String, String> get headers; String? get epgChannelId; bool get favorite; int? get number; List<IptvLine> get lines;
/// Create a copy of IptvChannel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$IptvChannelCopyWith<IptvChannel> get copyWith => _$IptvChannelCopyWithImpl<IptvChannel>(this as IptvChannel, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as IptvChannel;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is IptvChannel&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.url, _this.url) || other.url == _this.url)&&(identical(other.group, _this.group) || other.group == _this.group)&&const DeepCollectionEquality().equals(other.headers, _this.headers)&&(identical(other.epgChannelId, _this.epgChannelId) || other.epgChannelId == _this.epgChannelId)&&(identical(other.favorite, _this.favorite) || other.favorite == _this.favorite)&&(identical(other.number, _this.number) || other.number == _this.number)&&const DeepCollectionEquality().equals(other.lines, _this.lines));
}


@override
int get hashCode {
  final _this = this as IptvChannel;
  return Object.hash(runtimeType,_this.id,_this.name,_this.url,_this.group,const DeepCollectionEquality().hash(_this.headers),_this.epgChannelId,_this.favorite,_this.number,const DeepCollectionEquality().hash(_this.lines));
}

@override
String toString() {
  final _this = this as IptvChannel;
  return 'IptvChannel(id: ${_this.id}, name: ${_this.name}, url: ${_this.url}, group: ${_this.group}, headers: ${_this.headers}, epgChannelId: ${_this.epgChannelId}, favorite: ${_this.favorite}, number: ${_this.number}, lines: ${_this.lines})';
}


}

/// @nodoc
abstract mixin class $IptvChannelCopyWith<$Res>  {
  factory $IptvChannelCopyWith(IptvChannel value, $Res Function(IptvChannel) _then) = _$IptvChannelCopyWithImpl;
@useResult
$Res call({
 String id, String name, String url, String? group, Map<String, String> headers, String? epgChannelId, bool favorite, int? number, List<IptvLine> lines
});




}
/// @nodoc
class _$IptvChannelCopyWithImpl<$Res>
    implements $IptvChannelCopyWith<$Res> {
  _$IptvChannelCopyWithImpl(this._self, this._then);

  final IptvChannel _self;
  final $Res Function(IptvChannel) _then;

/// Create a copy of IptvChannel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? url = null,Object? group = freezed,Object? headers = null,Object? epgChannelId = freezed,Object? favorite = null,Object? number = freezed,Object? lines = null,}) {
  return _then(IptvChannel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,group: freezed == group ? _self.group : group // ignore: cast_nullable_to_non_nullable
as String?,headers: null == headers ? _self.headers : headers // ignore: cast_nullable_to_non_nullable
as Map<String, String>,epgChannelId: freezed == epgChannelId ? _self.epgChannelId : epgChannelId // ignore: cast_nullable_to_non_nullable
as String?,favorite: null == favorite ? _self.favorite : favorite // ignore: cast_nullable_to_non_nullable
as bool,number: freezed == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as int?,lines: null == lines ? _self.lines : lines // ignore: cast_nullable_to_non_nullable
as List<IptvLine>,
  ));
}

}


/// Adds pattern-matching-related methods to [IptvChannel].
extension IptvChannelPatterns on IptvChannel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _IptvChannel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _IptvChannel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _IptvChannel value)  $default,){
final _that = this;
switch (_that) {
case _IptvChannel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _IptvChannel value)?  $default,){
final _that = this;
switch (_that) {
case _IptvChannel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String url,  String? group,  Map<String, String> headers,  String? epgChannelId,  bool favorite,  int? number,  List<IptvLine> lines)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _IptvChannel() when $default != null:
return $default(_that.id,_that.name,_that.url,_that.group,_that.headers,_that.epgChannelId,_that.favorite,_that.number,_that.lines);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String url,  String? group,  Map<String, String> headers,  String? epgChannelId,  bool favorite,  int? number,  List<IptvLine> lines)  $default,) {final _that = this;
switch (_that) {
case _IptvChannel():
return $default(_that.id,_that.name,_that.url,_that.group,_that.headers,_that.epgChannelId,_that.favorite,_that.number,_that.lines);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String url,  String? group,  Map<String, String> headers,  String? epgChannelId,  bool favorite,  int? number,  List<IptvLine> lines)?  $default,) {final _that = this;
switch (_that) {
case _IptvChannel() when $default != null:
return $default(_that.id,_that.name,_that.url,_that.group,_that.headers,_that.epgChannelId,_that.favorite,_that.number,_that.lines);case _:
  return null;

}
}

}

/// @nodoc


class _IptvChannel implements IptvChannel {
  const _IptvChannel({required this.id, required this.name, required this.url, this.group,  Map<String, String> headers = const {}, this.epgChannelId, this.favorite = false, this.number,  List<IptvLine> lines = const []}): _headers = headers,_lines = lines;
  

@override final  String id;
@override final  String name;
@override final  String url;
@override final  String? group;
 final  Map<String, String> _headers;
@override@JsonKey() Map<String, String> get headers {
  if (_headers is EqualUnmodifiableMapView) return _headers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_headers);
}

@override final  String? epgChannelId;
@override@JsonKey() final  bool favorite;
@override final  int? number;
 final  List<IptvLine> _lines;
@override@JsonKey() List<IptvLine> get lines {
  if (_lines is EqualUnmodifiableListView) return _lines;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_lines);
}


/// Create a copy of IptvChannel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$IptvChannelCopyWith<_IptvChannel> get copyWith => __$IptvChannelCopyWithImpl<_IptvChannel>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _IptvChannel&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.url, url) || other.url == url)&&(identical(other.group, group) || other.group == group)&&const DeepCollectionEquality().equals(other.headers, _headers)&&(identical(other.epgChannelId, epgChannelId) || other.epgChannelId == epgChannelId)&&(identical(other.favorite, favorite) || other.favorite == favorite)&&(identical(other.number, number) || other.number == number)&&const DeepCollectionEquality().equals(other.lines, _lines));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,name,url,group,const DeepCollectionEquality().hash(_headers),epgChannelId,favorite,number,const DeepCollectionEquality().hash(_lines));
}

@override
String toString() {
    return 'IptvChannel(id: $id, name: $name, url: $url, group: $group, headers: $headers, epgChannelId: $epgChannelId, favorite: $favorite, number: $number, lines: $lines)';
}


}

/// @nodoc
abstract mixin class _$IptvChannelCopyWith<$Res> implements $IptvChannelCopyWith<$Res> {
  factory _$IptvChannelCopyWith(_IptvChannel value, $Res Function(_IptvChannel) _then) = __$IptvChannelCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String url, String? group, Map<String, String> headers, String? epgChannelId, bool favorite, int? number, List<IptvLine> lines
});




}
/// @nodoc
class __$IptvChannelCopyWithImpl<$Res>
    implements _$IptvChannelCopyWith<$Res> {
  __$IptvChannelCopyWithImpl(this._self, this._then);

  final _IptvChannel _self;
  final $Res Function(_IptvChannel) _then;

/// Create a copy of IptvChannel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? url = null,Object? group = freezed,Object? headers = null,Object? epgChannelId = freezed,Object? favorite = null,Object? number = freezed,Object? lines = null,}) {
  return _then(_IptvChannel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,group: freezed == group ? _self.group : group // ignore: cast_nullable_to_non_nullable
as String?,headers: null == headers ? _self._headers : headers // ignore: cast_nullable_to_non_nullable
as Map<String, String>,epgChannelId: freezed == epgChannelId ? _self.epgChannelId : epgChannelId // ignore: cast_nullable_to_non_nullable
as String?,favorite: null == favorite ? _self.favorite : favorite // ignore: cast_nullable_to_non_nullable
as bool,number: freezed == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as int?,lines: null == lines ? _self._lines : lines // ignore: cast_nullable_to_non_nullable
as List<IptvLine>,
  ));
}


}

// dart format on
