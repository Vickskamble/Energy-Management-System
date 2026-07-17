// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'energy_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$EnergyState {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EnergyState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'EnergyState()';
}


}

/// @nodoc
class $EnergyStateCopyWith<$Res>  {
$EnergyStateCopyWith(EnergyState _, $Res Function(EnergyState) __);
}


/// Adds pattern-matching-related methods to [EnergyState].
extension EnergyStatePatterns on EnergyState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( EnergyInitial value)?  initial,TResult Function( EnergyLoading value)?  loading,TResult Function( EnergySuccess value)?  success,TResult Function( EnergyValidationError value)?  validationError,TResult Function( EnergyOperationFailure value)?  operationFailure,required TResult orElse(),}){
final _that = this;
switch (_that) {
case EnergyInitial() when initial != null:
return initial(_that);case EnergyLoading() when loading != null:
return loading(_that);case EnergySuccess() when success != null:
return success(_that);case EnergyValidationError() when validationError != null:
return validationError(_that);case EnergyOperationFailure() when operationFailure != null:
return operationFailure(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( EnergyInitial value)  initial,required TResult Function( EnergyLoading value)  loading,required TResult Function( EnergySuccess value)  success,required TResult Function( EnergyValidationError value)  validationError,required TResult Function( EnergyOperationFailure value)  operationFailure,}){
final _that = this;
switch (_that) {
case EnergyInitial():
return initial(_that);case EnergyLoading():
return loading(_that);case EnergySuccess():
return success(_that);case EnergyValidationError():
return validationError(_that);case EnergyOperationFailure():
return operationFailure(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( EnergyInitial value)?  initial,TResult? Function( EnergyLoading value)?  loading,TResult? Function( EnergySuccess value)?  success,TResult? Function( EnergyValidationError value)?  validationError,TResult? Function( EnergyOperationFailure value)?  operationFailure,}){
final _that = this;
switch (_that) {
case EnergyInitial() when initial != null:
return initial(_that);case EnergyLoading() when loading != null:
return loading(_that);case EnergySuccess() when success != null:
return success(_that);case EnergyValidationError() when validationError != null:
return validationError(_that);case EnergyOperationFailure() when operationFailure != null:
return operationFailure(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  initial,TResult Function()?  loading,TResult Function( List<dynamic> logs,  double estimatedBill,  double totalConsumption,  double activeConsumptionToday,  double currentPowerFactor,  double maxDemandPeak)?  success,TResult Function( String message)?  validationError,TResult Function( String message)?  operationFailure,required TResult orElse(),}) {final _that = this;
switch (_that) {
case EnergyInitial() when initial != null:
return initial();case EnergyLoading() when loading != null:
return loading();case EnergySuccess() when success != null:
return success(_that.logs,_that.estimatedBill,_that.totalConsumption,_that.activeConsumptionToday,_that.currentPowerFactor,_that.maxDemandPeak);case EnergyValidationError() when validationError != null:
return validationError(_that.message);case EnergyOperationFailure() when operationFailure != null:
return operationFailure(_that.message);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  initial,required TResult Function()  loading,required TResult Function( List<dynamic> logs,  double estimatedBill,  double totalConsumption,  double activeConsumptionToday,  double currentPowerFactor,  double maxDemandPeak)  success,required TResult Function( String message)  validationError,required TResult Function( String message)  operationFailure,}) {final _that = this;
switch (_that) {
case EnergyInitial():
return initial();case EnergyLoading():
return loading();case EnergySuccess():
return success(_that.logs,_that.estimatedBill,_that.totalConsumption,_that.activeConsumptionToday,_that.currentPowerFactor,_that.maxDemandPeak);case EnergyValidationError():
return validationError(_that.message);case EnergyOperationFailure():
return operationFailure(_that.message);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  initial,TResult? Function()?  loading,TResult? Function( List<dynamic> logs,  double estimatedBill,  double totalConsumption,  double activeConsumptionToday,  double currentPowerFactor,  double maxDemandPeak)?  success,TResult? Function( String message)?  validationError,TResult? Function( String message)?  operationFailure,}) {final _that = this;
switch (_that) {
case EnergyInitial() when initial != null:
return initial();case EnergyLoading() when loading != null:
return loading();case EnergySuccess() when success != null:
return success(_that.logs,_that.estimatedBill,_that.totalConsumption,_that.activeConsumptionToday,_that.currentPowerFactor,_that.maxDemandPeak);case EnergyValidationError() when validationError != null:
return validationError(_that.message);case EnergyOperationFailure() when operationFailure != null:
return operationFailure(_that.message);case _:
  return null;

}
}

}

/// @nodoc


class EnergyInitial implements EnergyState {
  const EnergyInitial();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EnergyInitial);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'EnergyState.initial()';
}


}




/// @nodoc


class EnergyLoading implements EnergyState {
  const EnergyLoading();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EnergyLoading);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'EnergyState.loading()';
}


}




/// @nodoc


class EnergySuccess implements EnergyState {
  const EnergySuccess({required final  List<dynamic> logs, required this.estimatedBill, required this.totalConsumption, required this.activeConsumptionToday, required this.currentPowerFactor, required this.maxDemandPeak}): _logs = logs;
  

/// All energy logs for the current view
 final  List<dynamic> _logs;
/// All energy logs for the current view
 List<dynamic> get logs {
  if (_logs is EqualUnmodifiableListView) return _logs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_logs);
}

/// Current month estimated bill in INR (calculated)
 final  double estimatedBill;
/// Total consumption in units (kWh × multiplying factor 5)
 final  double totalConsumption;
/// Today's cumulative active energy consumption in kWh
 final  double activeConsumptionToday;
/// Average power factor across current period (0.000 – 1.000)
 final  double currentPowerFactor;
/// Maximum demand peak recorded in the current period (kW)
 final  double maxDemandPeak;

/// Create a copy of EnergyState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EnergySuccessCopyWith<EnergySuccess> get copyWith => _$EnergySuccessCopyWithImpl<EnergySuccess>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EnergySuccess&&const DeepCollectionEquality().equals(other._logs, _logs)&&(identical(other.estimatedBill, estimatedBill) || other.estimatedBill == estimatedBill)&&(identical(other.totalConsumption, totalConsumption) || other.totalConsumption == totalConsumption)&&(identical(other.activeConsumptionToday, activeConsumptionToday) || other.activeConsumptionToday == activeConsumptionToday)&&(identical(other.currentPowerFactor, currentPowerFactor) || other.currentPowerFactor == currentPowerFactor)&&(identical(other.maxDemandPeak, maxDemandPeak) || other.maxDemandPeak == maxDemandPeak));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_logs),estimatedBill,totalConsumption,activeConsumptionToday,currentPowerFactor,maxDemandPeak);

@override
String toString() {
  return 'EnergyState.success(logs: $logs, estimatedBill: $estimatedBill, totalConsumption: $totalConsumption, activeConsumptionToday: $activeConsumptionToday, currentPowerFactor: $currentPowerFactor, maxDemandPeak: $maxDemandPeak)';
}


}

/// @nodoc
abstract mixin class $EnergySuccessCopyWith<$Res> implements $EnergyStateCopyWith<$Res> {
  factory $EnergySuccessCopyWith(EnergySuccess value, $Res Function(EnergySuccess) _then) = _$EnergySuccessCopyWithImpl;
@useResult
$Res call({
 List<dynamic> logs, double estimatedBill, double totalConsumption, double activeConsumptionToday, double currentPowerFactor, double maxDemandPeak
});




}
/// @nodoc
class _$EnergySuccessCopyWithImpl<$Res>
    implements $EnergySuccessCopyWith<$Res> {
  _$EnergySuccessCopyWithImpl(this._self, this._then);

  final EnergySuccess _self;
  final $Res Function(EnergySuccess) _then;

/// Create a copy of EnergyState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? logs = null,Object? estimatedBill = null,Object? totalConsumption = null,Object? activeConsumptionToday = null,Object? currentPowerFactor = null,Object? maxDemandPeak = null,}) {
  return _then(EnergySuccess(
logs: null == logs ? _self._logs : logs // ignore: cast_nullable_to_non_nullable
as List<dynamic>,estimatedBill: null == estimatedBill ? _self.estimatedBill : estimatedBill // ignore: cast_nullable_to_non_nullable
as double,totalConsumption: null == totalConsumption ? _self.totalConsumption : totalConsumption // ignore: cast_nullable_to_non_nullable
as double,activeConsumptionToday: null == activeConsumptionToday ? _self.activeConsumptionToday : activeConsumptionToday // ignore: cast_nullable_to_non_nullable
as double,currentPowerFactor: null == currentPowerFactor ? _self.currentPowerFactor : currentPowerFactor // ignore: cast_nullable_to_non_nullable
as double,maxDemandPeak: null == maxDemandPeak ? _self.maxDemandPeak : maxDemandPeak // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc


class EnergyValidationError implements EnergyState {
  const EnergyValidationError(this.message);
  

 final  String message;

/// Create a copy of EnergyState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EnergyValidationErrorCopyWith<EnergyValidationError> get copyWith => _$EnergyValidationErrorCopyWithImpl<EnergyValidationError>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EnergyValidationError&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,message);

@override
String toString() {
  return 'EnergyState.validationError(message: $message)';
}


}

/// @nodoc
abstract mixin class $EnergyValidationErrorCopyWith<$Res> implements $EnergyStateCopyWith<$Res> {
  factory $EnergyValidationErrorCopyWith(EnergyValidationError value, $Res Function(EnergyValidationError) _then) = _$EnergyValidationErrorCopyWithImpl;
@useResult
$Res call({
 String message
});




}
/// @nodoc
class _$EnergyValidationErrorCopyWithImpl<$Res>
    implements $EnergyValidationErrorCopyWith<$Res> {
  _$EnergyValidationErrorCopyWithImpl(this._self, this._then);

  final EnergyValidationError _self;
  final $Res Function(EnergyValidationError) _then;

/// Create a copy of EnergyState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(EnergyValidationError(
null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class EnergyOperationFailure implements EnergyState {
  const EnergyOperationFailure(this.message);
  

 final  String message;

/// Create a copy of EnergyState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EnergyOperationFailureCopyWith<EnergyOperationFailure> get copyWith => _$EnergyOperationFailureCopyWithImpl<EnergyOperationFailure>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EnergyOperationFailure&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,message);

@override
String toString() {
  return 'EnergyState.operationFailure(message: $message)';
}


}

/// @nodoc
abstract mixin class $EnergyOperationFailureCopyWith<$Res> implements $EnergyStateCopyWith<$Res> {
  factory $EnergyOperationFailureCopyWith(EnergyOperationFailure value, $Res Function(EnergyOperationFailure) _then) = _$EnergyOperationFailureCopyWithImpl;
@useResult
$Res call({
 String message
});




}
/// @nodoc
class _$EnergyOperationFailureCopyWithImpl<$Res>
    implements $EnergyOperationFailureCopyWith<$Res> {
  _$EnergyOperationFailureCopyWithImpl(this._self, this._then);

  final EnergyOperationFailure _self;
  final $Res Function(EnergyOperationFailure) _then;

/// Create a copy of EnergyState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(EnergyOperationFailure(
null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
