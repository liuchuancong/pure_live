// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'live_page_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$LivePageRequest {

 int get page; int get pageSize; int? get offset; String? get cursor;
/// Create a copy of LivePageRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LivePageRequestCopyWith<LivePageRequest> get copyWith => _$LivePageRequestCopyWithImpl<LivePageRequest>(this as LivePageRequest, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as LivePageRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LivePageRequest&&(identical(other.page, _this.page) || other.page == _this.page)&&(identical(other.pageSize, _this.pageSize) || other.pageSize == _this.pageSize)&&(identical(other.offset, _this.offset) || other.offset == _this.offset)&&(identical(other.cursor, _this.cursor) || other.cursor == _this.cursor));
}


@override
int get hashCode {
  final _this = this as LivePageRequest;
  return Object.hash(runtimeType,_this.page,_this.pageSize,_this.offset,_this.cursor);
}

@override
String toString() {
  final _this = this as LivePageRequest;
  return 'LivePageRequest(page: ${_this.page}, pageSize: ${_this.pageSize}, offset: ${_this.offset}, cursor: ${_this.cursor})';
}


}

/// @nodoc
abstract mixin class $LivePageRequestCopyWith<$Res>  {
  factory $LivePageRequestCopyWith(LivePageRequest value, $Res Function(LivePageRequest) _then) = _$LivePageRequestCopyWithImpl;
@useResult
$Res call({
 int page, int pageSize, int? offset, String? cursor
});




}
/// @nodoc
class _$LivePageRequestCopyWithImpl<$Res>
    implements $LivePageRequestCopyWith<$Res> {
  _$LivePageRequestCopyWithImpl(this._self, this._then);

  final LivePageRequest _self;
  final $Res Function(LivePageRequest) _then;

/// Create a copy of LivePageRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? page = null,Object? pageSize = null,Object? offset = freezed,Object? cursor = freezed,}) {
  return _then(LivePageRequest(
page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,pageSize: null == pageSize ? _self.pageSize : pageSize // ignore: cast_nullable_to_non_nullable
as int,offset: freezed == offset ? _self.offset : offset // ignore: cast_nullable_to_non_nullable
as int?,cursor: freezed == cursor ? _self.cursor : cursor // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [LivePageRequest].
extension LivePageRequestPatterns on LivePageRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LivePageRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LivePageRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LivePageRequest value)  $default,){
final _that = this;
switch (_that) {
case _LivePageRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LivePageRequest value)?  $default,){
final _that = this;
switch (_that) {
case _LivePageRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int page,  int pageSize,  int? offset,  String? cursor)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LivePageRequest() when $default != null:
return $default(_that.page,_that.pageSize,_that.offset,_that.cursor);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int page,  int pageSize,  int? offset,  String? cursor)  $default,) {final _that = this;
switch (_that) {
case _LivePageRequest():
return $default(_that.page,_that.pageSize,_that.offset,_that.cursor);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int page,  int pageSize,  int? offset,  String? cursor)?  $default,) {final _that = this;
switch (_that) {
case _LivePageRequest() when $default != null:
return $default(_that.page,_that.pageSize,_that.offset,_that.cursor);case _:
  return null;

}
}

}

/// @nodoc


class _LivePageRequest implements LivePageRequest {
  const _LivePageRequest({this.page = 1, this.pageSize = 20, this.offset, this.cursor});
  

@override@JsonKey() final  int page;
@override@JsonKey() final  int pageSize;
@override final  int? offset;
@override final  String? cursor;

/// Create a copy of LivePageRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LivePageRequestCopyWith<_LivePageRequest> get copyWith => __$LivePageRequestCopyWithImpl<_LivePageRequest>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LivePageRequest&&(identical(other.page, page) || other.page == page)&&(identical(other.pageSize, pageSize) || other.pageSize == pageSize)&&(identical(other.offset, offset) || other.offset == offset)&&(identical(other.cursor, cursor) || other.cursor == cursor));
}


@override
int get hashCode {
    return Object.hash(runtimeType,page,pageSize,offset,cursor);
}

@override
String toString() {
    return 'LivePageRequest(page: $page, pageSize: $pageSize, offset: $offset, cursor: $cursor)';
}


}

/// @nodoc
abstract mixin class _$LivePageRequestCopyWith<$Res> implements $LivePageRequestCopyWith<$Res> {
  factory _$LivePageRequestCopyWith(_LivePageRequest value, $Res Function(_LivePageRequest) _then) = __$LivePageRequestCopyWithImpl;
@override @useResult
$Res call({
 int page, int pageSize, int? offset, String? cursor
});




}
/// @nodoc
class __$LivePageRequestCopyWithImpl<$Res>
    implements _$LivePageRequestCopyWith<$Res> {
  __$LivePageRequestCopyWithImpl(this._self, this._then);

  final _LivePageRequest _self;
  final $Res Function(_LivePageRequest) _then;

/// Create a copy of LivePageRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? page = null,Object? pageSize = null,Object? offset = freezed,Object? cursor = freezed,}) {
  return _then(_LivePageRequest(
page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,pageSize: null == pageSize ? _self.pageSize : pageSize // ignore: cast_nullable_to_non_nullable
as int,offset: freezed == offset ? _self.offset : offset // ignore: cast_nullable_to_non_nullable
as int?,cursor: freezed == cursor ? _self.cursor : cursor // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
