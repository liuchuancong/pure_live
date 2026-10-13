// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'live_search_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$LiveSearchRequest {

 String get query; LiveSearchTarget get target; int get page; int get pageSize;
/// Create a copy of LiveSearchRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveSearchRequestCopyWith<LiveSearchRequest> get copyWith => _$LiveSearchRequestCopyWithImpl<LiveSearchRequest>(this as LiveSearchRequest, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as LiveSearchRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveSearchRequest&&(identical(other.query, _this.query) || other.query == _this.query)&&(identical(other.target, _this.target) || other.target == _this.target)&&(identical(other.page, _this.page) || other.page == _this.page)&&(identical(other.pageSize, _this.pageSize) || other.pageSize == _this.pageSize));
}


@override
int get hashCode {
  final _this = this as LiveSearchRequest;
  return Object.hash(runtimeType,_this.query,_this.target,_this.page,_this.pageSize);
}

@override
String toString() {
  final _this = this as LiveSearchRequest;
  return 'LiveSearchRequest(query: ${_this.query}, target: ${_this.target}, page: ${_this.page}, pageSize: ${_this.pageSize})';
}


}

/// @nodoc
abstract mixin class $LiveSearchRequestCopyWith<$Res>  {
  factory $LiveSearchRequestCopyWith(LiveSearchRequest value, $Res Function(LiveSearchRequest) _then) = _$LiveSearchRequestCopyWithImpl;
@useResult
$Res call({
 String query, LiveSearchTarget target, int page, int pageSize
});




}
/// @nodoc
class _$LiveSearchRequestCopyWithImpl<$Res>
    implements $LiveSearchRequestCopyWith<$Res> {
  _$LiveSearchRequestCopyWithImpl(this._self, this._then);

  final LiveSearchRequest _self;
  final $Res Function(LiveSearchRequest) _then;

/// Create a copy of LiveSearchRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? query = null,Object? target = null,Object? page = null,Object? pageSize = null,}) {
  return _then(LiveSearchRequest(
query: null == query ? _self.query : query // ignore: cast_nullable_to_non_nullable
as String,target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as LiveSearchTarget,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,pageSize: null == pageSize ? _self.pageSize : pageSize // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [LiveSearchRequest].
extension LiveSearchRequestPatterns on LiveSearchRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveSearchRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveSearchRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveSearchRequest value)  $default,){
final _that = this;
switch (_that) {
case _LiveSearchRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveSearchRequest value)?  $default,){
final _that = this;
switch (_that) {
case _LiveSearchRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String query,  LiveSearchTarget target,  int page,  int pageSize)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveSearchRequest() when $default != null:
return $default(_that.query,_that.target,_that.page,_that.pageSize);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String query,  LiveSearchTarget target,  int page,  int pageSize)  $default,) {final _that = this;
switch (_that) {
case _LiveSearchRequest():
return $default(_that.query,_that.target,_that.page,_that.pageSize);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String query,  LiveSearchTarget target,  int page,  int pageSize)?  $default,) {final _that = this;
switch (_that) {
case _LiveSearchRequest() when $default != null:
return $default(_that.query,_that.target,_that.page,_that.pageSize);case _:
  return null;

}
}

}

/// @nodoc


class _LiveSearchRequest implements LiveSearchRequest {
  const _LiveSearchRequest({required this.query, required this.target, this.page = 1, this.pageSize = 20});
  

@override final  String query;
@override final  LiveSearchTarget target;
@override@JsonKey() final  int page;
@override@JsonKey() final  int pageSize;

/// Create a copy of LiveSearchRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveSearchRequestCopyWith<_LiveSearchRequest> get copyWith => __$LiveSearchRequestCopyWithImpl<_LiveSearchRequest>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveSearchRequest&&(identical(other.query, query) || other.query == query)&&(identical(other.target, target) || other.target == target)&&(identical(other.page, page) || other.page == page)&&(identical(other.pageSize, pageSize) || other.pageSize == pageSize));
}


@override
int get hashCode {
    return Object.hash(runtimeType,query,target,page,pageSize);
}

@override
String toString() {
    return 'LiveSearchRequest(query: $query, target: $target, page: $page, pageSize: $pageSize)';
}


}

/// @nodoc
abstract mixin class _$LiveSearchRequestCopyWith<$Res> implements $LiveSearchRequestCopyWith<$Res> {
  factory _$LiveSearchRequestCopyWith(_LiveSearchRequest value, $Res Function(_LiveSearchRequest) _then) = __$LiveSearchRequestCopyWithImpl;
@override @useResult
$Res call({
 String query, LiveSearchTarget target, int page, int pageSize
});




}
/// @nodoc
class __$LiveSearchRequestCopyWithImpl<$Res>
    implements _$LiveSearchRequestCopyWith<$Res> {
  __$LiveSearchRequestCopyWithImpl(this._self, this._then);

  final _LiveSearchRequest _self;
  final $Res Function(_LiveSearchRequest) _then;

/// Create a copy of LiveSearchRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? query = null,Object? target = null,Object? page = null,Object? pageSize = null,}) {
  return _then(_LiveSearchRequest(
query: null == query ? _self.query : query // ignore: cast_nullable_to_non_nullable
as String,target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as LiveSearchTarget,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,pageSize: null == pageSize ? _self.pageSize : pageSize // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
