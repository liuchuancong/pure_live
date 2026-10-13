// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'interaction_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$InteractionState {

 InteractionPhase get phase;/// The ids of the sources currently connected.
 List<String> get activeSources;/// How many reconnects have been spent.
 int get reconnectAttempts;/// The error that led to the current reconnect, if any.
 Object? get lastError;
/// Create a copy of InteractionState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InteractionStateCopyWith<InteractionState> get copyWith => _$InteractionStateCopyWithImpl<InteractionState>(this as InteractionState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as InteractionState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InteractionState&&(identical(other.phase, _this.phase) || other.phase == _this.phase)&&const DeepCollectionEquality().equals(other.activeSources, _this.activeSources)&&(identical(other.reconnectAttempts, _this.reconnectAttempts) || other.reconnectAttempts == _this.reconnectAttempts)&&const DeepCollectionEquality().equals(other.lastError, _this.lastError));
}


@override
int get hashCode {
  final _this = this as InteractionState;
  return Object.hash(runtimeType,_this.phase,const DeepCollectionEquality().hash(_this.activeSources),_this.reconnectAttempts,const DeepCollectionEquality().hash(_this.lastError));
}

@override
String toString() {
  final _this = this as InteractionState;
  return 'InteractionState(phase: ${_this.phase}, activeSources: ${_this.activeSources}, reconnectAttempts: ${_this.reconnectAttempts}, lastError: ${_this.lastError})';
}


}

/// @nodoc
abstract mixin class $InteractionStateCopyWith<$Res>  {
  factory $InteractionStateCopyWith(InteractionState value, $Res Function(InteractionState) _then) = _$InteractionStateCopyWithImpl;
@useResult
$Res call({
 InteractionPhase phase, List<String> activeSources, int reconnectAttempts, Object? lastError
});




}
/// @nodoc
class _$InteractionStateCopyWithImpl<$Res>
    implements $InteractionStateCopyWith<$Res> {
  _$InteractionStateCopyWithImpl(this._self, this._then);

  final InteractionState _self;
  final $Res Function(InteractionState) _then;

/// Create a copy of InteractionState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? phase = null,Object? activeSources = null,Object? reconnectAttempts = null,Object? lastError = freezed,}) {
  return _then(InteractionState(
phase: null == phase ? _self.phase : phase // ignore: cast_nullable_to_non_nullable
as InteractionPhase,activeSources: null == activeSources ? _self.activeSources : activeSources // ignore: cast_nullable_to_non_nullable
as List<String>,reconnectAttempts: null == reconnectAttempts ? _self.reconnectAttempts : reconnectAttempts // ignore: cast_nullable_to_non_nullable
as int,lastError: freezed == lastError ? _self.lastError : lastError ,
  ));
}

}


/// Adds pattern-matching-related methods to [InteractionState].
extension InteractionStatePatterns on InteractionState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InteractionState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InteractionState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InteractionState value)  $default,){
final _that = this;
switch (_that) {
case _InteractionState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InteractionState value)?  $default,){
final _that = this;
switch (_that) {
case _InteractionState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( InteractionPhase phase,  List<String> activeSources,  int reconnectAttempts,  Object? lastError)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InteractionState() when $default != null:
return $default(_that.phase,_that.activeSources,_that.reconnectAttempts,_that.lastError);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( InteractionPhase phase,  List<String> activeSources,  int reconnectAttempts,  Object? lastError)  $default,) {final _that = this;
switch (_that) {
case _InteractionState():
return $default(_that.phase,_that.activeSources,_that.reconnectAttempts,_that.lastError);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( InteractionPhase phase,  List<String> activeSources,  int reconnectAttempts,  Object? lastError)?  $default,) {final _that = this;
switch (_that) {
case _InteractionState() when $default != null:
return $default(_that.phase,_that.activeSources,_that.reconnectAttempts,_that.lastError);case _:
  return null;

}
}

}

/// @nodoc


class _InteractionState extends InteractionState {
  const _InteractionState({this.phase = InteractionPhase.idle,  List<String> activeSources = const <String>[], this.reconnectAttempts = 0, this.lastError}): _activeSources = activeSources,super._();
  

@override@JsonKey() final  InteractionPhase phase;
/// The ids of the sources currently connected.
 final  List<String> _activeSources;
/// The ids of the sources currently connected.
@override@JsonKey() List<String> get activeSources {
  if (_activeSources is EqualUnmodifiableListView) return _activeSources;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_activeSources);
}

/// How many reconnects have been spent.
@override@JsonKey() final  int reconnectAttempts;
/// The error that led to the current reconnect, if any.
@override final  Object? lastError;

/// Create a copy of InteractionState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InteractionStateCopyWith<_InteractionState> get copyWith => __$InteractionStateCopyWithImpl<_InteractionState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _InteractionState&&(identical(other.phase, phase) || other.phase == phase)&&const DeepCollectionEquality().equals(other.activeSources, _activeSources)&&(identical(other.reconnectAttempts, reconnectAttempts) || other.reconnectAttempts == reconnectAttempts)&&const DeepCollectionEquality().equals(other.lastError, lastError));
}


@override
int get hashCode {
    return Object.hash(runtimeType,phase,const DeepCollectionEquality().hash(_activeSources),reconnectAttempts,const DeepCollectionEquality().hash(lastError));
}

@override
String toString() {
    return 'InteractionState(phase: $phase, activeSources: $activeSources, reconnectAttempts: $reconnectAttempts, lastError: $lastError)';
}


}

/// @nodoc
abstract mixin class _$InteractionStateCopyWith<$Res> implements $InteractionStateCopyWith<$Res> {
  factory _$InteractionStateCopyWith(_InteractionState value, $Res Function(_InteractionState) _then) = __$InteractionStateCopyWithImpl;
@override @useResult
$Res call({
 InteractionPhase phase, List<String> activeSources, int reconnectAttempts, Object? lastError
});




}
/// @nodoc
class __$InteractionStateCopyWithImpl<$Res>
    implements _$InteractionStateCopyWith<$Res> {
  __$InteractionStateCopyWithImpl(this._self, this._then);

  final _InteractionState _self;
  final $Res Function(_InteractionState) _then;

/// Create a copy of InteractionState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? phase = null,Object? activeSources = null,Object? reconnectAttempts = null,Object? lastError = freezed,}) {
  return _then(_InteractionState(
phase: null == phase ? _self.phase : phase // ignore: cast_nullable_to_non_nullable
as InteractionPhase,activeSources: null == activeSources ? _self._activeSources : activeSources // ignore: cast_nullable_to_non_nullable
as List<String>,reconnectAttempts: null == reconnectAttempts ? _self.reconnectAttempts : reconnectAttempts // ignore: cast_nullable_to_non_nullable
as int,lastError: freezed == lastError ? _self.lastError : lastError ,
  ));
}


}

// dart format on
