// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'iptv_channel.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$IptvChannel {

 String get id; IptvEntry get entry; bool get favorite; bool get hidden; bool get pinned; int get position; int? get number;
/// Create a copy of IptvChannel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$IptvChannelCopyWith<IptvChannel> get copyWith => _$IptvChannelCopyWithImpl<IptvChannel>(this as IptvChannel, _$identity);

  /// Serializes this IptvChannel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as IptvChannel;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is IptvChannel&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.entry, _this.entry) || other.entry == _this.entry)&&(identical(other.favorite, _this.favorite) || other.favorite == _this.favorite)&&(identical(other.hidden, _this.hidden) || other.hidden == _this.hidden)&&(identical(other.pinned, _this.pinned) || other.pinned == _this.pinned)&&(identical(other.position, _this.position) || other.position == _this.position)&&(identical(other.number, _this.number) || other.number == _this.number));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as IptvChannel;
  return Object.hash(runtimeType,_this.id,_this.entry,_this.favorite,_this.hidden,_this.pinned,_this.position,_this.number);
}

@override
String toString() {
  final _this = this as IptvChannel;
  return 'IptvChannel(id: ${_this.id}, entry: ${_this.entry}, favorite: ${_this.favorite}, hidden: ${_this.hidden}, pinned: ${_this.pinned}, position: ${_this.position}, number: ${_this.number})';
}


}

/// @nodoc
abstract mixin class $IptvChannelCopyWith<$Res>  {
  factory $IptvChannelCopyWith(IptvChannel value, $Res Function(IptvChannel) _then) = _$IptvChannelCopyWithImpl;
@useResult
$Res call({
 String id, IptvEntry entry, bool favorite, bool hidden, bool pinned, int position, int? number
});


$IptvEntryCopyWith<$Res> get entry;

}
/// @nodoc
class _$IptvChannelCopyWithImpl<$Res>
    implements $IptvChannelCopyWith<$Res> {
  _$IptvChannelCopyWithImpl(this._self, this._then);

  final IptvChannel _self;
  final $Res Function(IptvChannel) _then;

/// Create a copy of IptvChannel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? entry = null,Object? favorite = null,Object? hidden = null,Object? pinned = null,Object? position = null,Object? number = freezed,}) {
  return _then(IptvChannel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,entry: null == entry ? _self.entry : entry // ignore: cast_nullable_to_non_nullable
as IptvEntry,favorite: null == favorite ? _self.favorite : favorite // ignore: cast_nullable_to_non_nullable
as bool,hidden: null == hidden ? _self.hidden : hidden // ignore: cast_nullable_to_non_nullable
as bool,pinned: null == pinned ? _self.pinned : pinned // ignore: cast_nullable_to_non_nullable
as bool,position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as int,number: freezed == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}
/// Create a copy of IptvChannel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$IptvEntryCopyWith<$Res> get entry {
  
  return $IptvEntryCopyWith<$Res>(_self.entry, (value) {
    return _then(_self.copyWith(entry: value));
  });
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  IptvEntry entry,  bool favorite,  bool hidden,  bool pinned,  int position,  int? number)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _IptvChannel() when $default != null:
return $default(_that.id,_that.entry,_that.favorite,_that.hidden,_that.pinned,_that.position,_that.number);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  IptvEntry entry,  bool favorite,  bool hidden,  bool pinned,  int position,  int? number)  $default,) {final _that = this;
switch (_that) {
case _IptvChannel():
return $default(_that.id,_that.entry,_that.favorite,_that.hidden,_that.pinned,_that.position,_that.number);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  IptvEntry entry,  bool favorite,  bool hidden,  bool pinned,  int position,  int? number)?  $default,) {final _that = this;
switch (_that) {
case _IptvChannel() when $default != null:
return $default(_that.id,_that.entry,_that.favorite,_that.hidden,_that.pinned,_that.position,_that.number);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _IptvChannel implements IptvChannel {
  const _IptvChannel({required this.id, required this.entry, this.favorite = false, this.hidden = false, this.pinned = false, this.position = 0, this.number});
  factory _IptvChannel.fromJson(Map<String, dynamic> json) => _$IptvChannelFromJson(json);

@override final  String id;
@override final  IptvEntry entry;
@override@JsonKey() final  bool favorite;
@override@JsonKey() final  bool hidden;
@override@JsonKey() final  bool pinned;
@override@JsonKey() final  int position;
@override final  int? number;

/// Create a copy of IptvChannel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$IptvChannelCopyWith<_IptvChannel> get copyWith => __$IptvChannelCopyWithImpl<_IptvChannel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$IptvChannelToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _IptvChannel&&(identical(other.id, id) || other.id == id)&&(identical(other.entry, entry) || other.entry == entry)&&(identical(other.favorite, favorite) || other.favorite == favorite)&&(identical(other.hidden, hidden) || other.hidden == hidden)&&(identical(other.pinned, pinned) || other.pinned == pinned)&&(identical(other.position, position) || other.position == position)&&(identical(other.number, number) || other.number == number));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,entry,favorite,hidden,pinned,position,number);
}

@override
String toString() {
    return 'IptvChannel(id: $id, entry: $entry, favorite: $favorite, hidden: $hidden, pinned: $pinned, position: $position, number: $number)';
}


}

/// @nodoc
abstract mixin class _$IptvChannelCopyWith<$Res> implements $IptvChannelCopyWith<$Res> {
  factory _$IptvChannelCopyWith(_IptvChannel value, $Res Function(_IptvChannel) _then) = __$IptvChannelCopyWithImpl;
@override @useResult
$Res call({
 String id, IptvEntry entry, bool favorite, bool hidden, bool pinned, int position, int? number
});


@override $IptvEntryCopyWith<$Res> get entry;

}
/// @nodoc
class __$IptvChannelCopyWithImpl<$Res>
    implements _$IptvChannelCopyWith<$Res> {
  __$IptvChannelCopyWithImpl(this._self, this._then);

  final _IptvChannel _self;
  final $Res Function(_IptvChannel) _then;

/// Create a copy of IptvChannel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? entry = null,Object? favorite = null,Object? hidden = null,Object? pinned = null,Object? position = null,Object? number = freezed,}) {
  return _then(_IptvChannel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,entry: null == entry ? _self.entry : entry // ignore: cast_nullable_to_non_nullable
as IptvEntry,favorite: null == favorite ? _self.favorite : favorite // ignore: cast_nullable_to_non_nullable
as bool,hidden: null == hidden ? _self.hidden : hidden // ignore: cast_nullable_to_non_nullable
as bool,pinned: null == pinned ? _self.pinned : pinned // ignore: cast_nullable_to_non_nullable
as bool,position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as int,number: freezed == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

/// Create a copy of IptvChannel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$IptvEntryCopyWith<$Res> get entry {
  
  return $IptvEntryCopyWith<$Res>(_self.entry, (value) {
    return _then(_self.copyWith(entry: value));
  });
}
}

// dart format on
