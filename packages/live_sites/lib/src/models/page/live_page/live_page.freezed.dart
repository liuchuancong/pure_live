// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'live_page.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$LivePage<T> {

 List<T> get items; int? get totalCount; String? get nextCursor; bool? get hasMore;
/// Create a copy of LivePage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LivePageCopyWith<T, LivePage<T>> get copyWith => _$LivePageCopyWithImpl<T, LivePage<T>>(this as LivePage<T>, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as LivePage<T>;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LivePage<T>&&const DeepCollectionEquality().equals(other.items, _this.items)&&(identical(other.totalCount, _this.totalCount) || other.totalCount == _this.totalCount)&&(identical(other.nextCursor, _this.nextCursor) || other.nextCursor == _this.nextCursor)&&(identical(other.hasMore, _this.hasMore) || other.hasMore == _this.hasMore));
}


@override
int get hashCode {
  final _this = this as LivePage<T>;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.items),_this.totalCount,_this.nextCursor,_this.hasMore);
}

@override
String toString() {
  final _this = this as LivePage<T>;
  return 'LivePage<$T>(items: ${_this.items}, totalCount: ${_this.totalCount}, nextCursor: ${_this.nextCursor}, hasMore: ${_this.hasMore})';
}


}

/// @nodoc
abstract mixin class $LivePageCopyWith<T,$Res>  {
  factory $LivePageCopyWith(LivePage<T> value, $Res Function(LivePage<T>) _then) = _$LivePageCopyWithImpl;
@useResult
$Res call({
 List<T> items, int? totalCount, String? nextCursor, bool? hasMore
});




}
/// @nodoc
class _$LivePageCopyWithImpl<T,$Res>
    implements $LivePageCopyWith<T, $Res> {
  _$LivePageCopyWithImpl(this._self, this._then);

  final LivePage<T> _self;
  final $Res Function(LivePage<T>) _then;

/// Create a copy of LivePage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? items = null,Object? totalCount = freezed,Object? nextCursor = freezed,Object? hasMore = freezed,}) {
  return _then(LivePage(
items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<T>,totalCount: freezed == totalCount ? _self.totalCount : totalCount // ignore: cast_nullable_to_non_nullable
as int?,nextCursor: freezed == nextCursor ? _self.nextCursor : nextCursor // ignore: cast_nullable_to_non_nullable
as String?,hasMore: freezed == hasMore ? _self.hasMore : hasMore // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}

}


/// Adds pattern-matching-related methods to [LivePage].
extension LivePagePatterns<T> on LivePage<T> {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LivePage<T> value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LivePage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LivePage<T> value)  $default,){
final _that = this;
switch (_that) {
case _LivePage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LivePage<T> value)?  $default,){
final _that = this;
switch (_that) {
case _LivePage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<T> items,  int? totalCount,  String? nextCursor,  bool? hasMore)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LivePage() when $default != null:
return $default(_that.items,_that.totalCount,_that.nextCursor,_that.hasMore);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<T> items,  int? totalCount,  String? nextCursor,  bool? hasMore)  $default,) {final _that = this;
switch (_that) {
case _LivePage():
return $default(_that.items,_that.totalCount,_that.nextCursor,_that.hasMore);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<T> items,  int? totalCount,  String? nextCursor,  bool? hasMore)?  $default,) {final _that = this;
switch (_that) {
case _LivePage() when $default != null:
return $default(_that.items,_that.totalCount,_that.nextCursor,_that.hasMore);case _:
  return null;

}
}

}

/// @nodoc


class _LivePage<T> implements LivePage<T> {
  const _LivePage({required  List<T> items, this.totalCount, this.nextCursor, this.hasMore}): _items = items;
  

 final  List<T> _items;
@override List<T> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

@override final  int? totalCount;
@override final  String? nextCursor;
@override final  bool? hasMore;

/// Create a copy of LivePage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LivePageCopyWith<T, _LivePage<T>> get copyWith => __$LivePageCopyWithImpl<T, _LivePage<T>>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LivePage<T>&&const DeepCollectionEquality().equals(other.items, _items)&&(identical(other.totalCount, totalCount) || other.totalCount == totalCount)&&(identical(other.nextCursor, nextCursor) || other.nextCursor == nextCursor)&&(identical(other.hasMore, hasMore) || other.hasMore == hasMore));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_items),totalCount,nextCursor,hasMore);
}

@override
String toString() {
    return 'LivePage<$T>(items: $items, totalCount: $totalCount, nextCursor: $nextCursor, hasMore: $hasMore)';
}


}

/// @nodoc
abstract mixin class _$LivePageCopyWith<T,$Res> implements $LivePageCopyWith<T, $Res> {
  factory _$LivePageCopyWith(_LivePage<T> value, $Res Function(_LivePage<T>) _then) = __$LivePageCopyWithImpl;
@override @useResult
$Res call({
 List<T> items, int? totalCount, String? nextCursor, bool? hasMore
});




}
/// @nodoc
class __$LivePageCopyWithImpl<T,$Res>
    implements _$LivePageCopyWith<T, $Res> {
  __$LivePageCopyWithImpl(this._self, this._then);

  final _LivePage<T> _self;
  final $Res Function(_LivePage<T>) _then;

/// Create a copy of LivePage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? items = null,Object? totalCount = freezed,Object? nextCursor = freezed,Object? hasMore = freezed,}) {
  return _then(_LivePage<T>(
items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<T>,totalCount: freezed == totalCount ? _self.totalCount : totalCount // ignore: cast_nullable_to_non_nullable
as int?,nextCursor: freezed == nextCursor ? _self.nextCursor : nextCursor // ignore: cast_nullable_to_non_nullable
as String?,hasMore: freezed == hasMore ? _self.hasMore : hasMore // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}


}

// dart format on
