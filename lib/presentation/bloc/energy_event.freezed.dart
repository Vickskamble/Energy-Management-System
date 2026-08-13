// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'energy_event.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$EnergyEvent {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EnergyEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'EnergyEvent()';
}


}

/// @nodoc
class $EnergyEventCopyWith<$Res>  {
$EnergyEventCopyWith(EnergyEvent _, $Res Function(EnergyEvent) __);
}


/// Adds pattern-matching-related methods to [EnergyEvent].
extension EnergyEventPatterns on EnergyEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( LoadInitialDashboardData value)?  loadInitialDashboardData,TResult Function( SubmitManualReadingForm value)?  submitManualReadingForm,required TResult orElse(),}){
final _that = this;
switch (_that) {
case LoadInitialDashboardData() when loadInitialDashboardData != null:
return loadInitialDashboardData(_that);case SubmitManualReadingForm() when submitManualReadingForm != null:
return submitManualReadingForm(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( LoadInitialDashboardData value)  loadInitialDashboardData,required TResult Function( SubmitManualReadingForm value)  submitManualReadingForm,}){
final _that = this;
switch (_that) {
case LoadInitialDashboardData():
return loadInitialDashboardData(_that);case SubmitManualReadingForm():
return submitManualReadingForm(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( LoadInitialDashboardData value)?  loadInitialDashboardData,TResult? Function( SubmitManualReadingForm value)?  submitManualReadingForm,}){
final _that = this;
switch (_that) {
case LoadInitialDashboardData() when loadInitialDashboardData != null:
return loadInitialDashboardData(_that);case SubmitManualReadingForm() when submitManualReadingForm != null:
return submitManualReadingForm(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  loadInitialDashboardData,TResult Function( String meterName,  double currentKwh,  double previousKwh,  double currentKvah,  double previousKvah,  double rkvarhLag,  double rkvarhLead,  double mdRecorded,  DateTime loggedAt,  double? powerFactor)?  submitManualReadingForm,required TResult orElse(),}) {final _that = this;
switch (_that) {
case LoadInitialDashboardData() when loadInitialDashboardData != null:
return loadInitialDashboardData();case SubmitManualReadingForm() when submitManualReadingForm != null:
return submitManualReadingForm(_that.meterName,_that.currentKwh,_that.previousKwh,_that.currentKvah,_that.previousKvah,_that.rkvarhLag,_that.rkvarhLead,_that.mdRecorded,_that.loggedAt,_that.powerFactor);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  loadInitialDashboardData,required TResult Function( String meterName,  double currentKwh,  double previousKwh,  double currentKvah,  double previousKvah,  double rkvarhLag,  double rkvarhLead,  double mdRecorded,  DateTime loggedAt,  double? powerFactor)  submitManualReadingForm,}) {final _that = this;
switch (_that) {
case LoadInitialDashboardData():
return loadInitialDashboardData();case SubmitManualReadingForm():
return submitManualReadingForm(_that.meterName,_that.currentKwh,_that.previousKwh,_that.currentKvah,_that.previousKvah,_that.rkvarhLag,_that.rkvarhLead,_that.mdRecorded,_that.loggedAt,_that.powerFactor);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  loadInitialDashboardData,TResult? Function( String meterName,  double currentKwh,  double previousKwh,  double currentKvah,  double previousKvah,  double rkvarhLag,  double rkvarhLead,  double mdRecorded,  DateTime loggedAt,  double? powerFactor)?  submitManualReadingForm,}) {final _that = this;
switch (_that) {
case LoadInitialDashboardData() when loadInitialDashboardData != null:
return loadInitialDashboardData();case SubmitManualReadingForm() when submitManualReadingForm != null:
return submitManualReadingForm(_that.meterName,_that.currentKwh,_that.previousKwh,_that.currentKvah,_that.previousKvah,_that.rkvarhLag,_that.rkvarhLead,_that.mdRecorded,_that.loggedAt,_that.powerFactor);case _:
  return null;

}
}

}

/// @nodoc


class LoadInitialDashboardData implements EnergyEvent {
  const LoadInitialDashboardData();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LoadInitialDashboardData);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'EnergyEvent.loadInitialDashboardData()';
}


}




/// @nodoc


class SubmitManualReadingForm implements EnergyEvent {
  const SubmitManualReadingForm({required this.meterName, required this.currentKwh, required this.previousKwh, required this.currentKvah, required this.previousKvah, required this.rkvarhLag, required this.rkvarhLead, required this.mdRecorded, required this.loggedAt, this.powerFactor});
  

 final  String meterName;
 final  double currentKwh;
 final  double previousKwh;
 final  double currentKvah;
 final  double previousKvah;
 final  double rkvarhLag;
 final  double rkvarhLead;
 final  double mdRecorded;
 final  DateTime loggedAt;
 final  double? powerFactor;

/// Create a copy of EnergyEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SubmitManualReadingFormCopyWith<SubmitManualReadingForm> get copyWith => _$SubmitManualReadingFormCopyWithImpl<SubmitManualReadingForm>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SubmitManualReadingForm&&(identical(other.meterName, meterName) || other.meterName == meterName)&&(identical(other.currentKwh, currentKwh) || other.currentKwh == currentKwh)&&(identical(other.previousKwh, previousKwh) || other.previousKwh == previousKwh)&&(identical(other.currentKvah, currentKvah) || other.currentKvah == currentKvah)&&(identical(other.previousKvah, previousKvah) || other.previousKvah == previousKvah)&&(identical(other.rkvarhLag, rkvarhLag) || other.rkvarhLag == rkvarhLag)&&(identical(other.rkvarhLead, rkvarhLead) || other.rkvarhLead == rkvarhLead)&&(identical(other.mdRecorded, mdRecorded) || other.mdRecorded == mdRecorded)&&(identical(other.loggedAt, loggedAt) || other.loggedAt == loggedAt)&&(identical(other.powerFactor, powerFactor) || other.powerFactor == powerFactor));
}


@override
int get hashCode => Object.hash(runtimeType,meterName,currentKwh,previousKwh,currentKvah,previousKvah,rkvarhLag,rkvarhLead,mdRecorded,loggedAt,powerFactor);

@override
String toString() {
  return 'EnergyEvent.submitManualReadingForm(meterName: $meterName, currentKwh: $currentKwh, previousKwh: $previousKwh, currentKvah: $currentKvah, previousKvah: $previousKvah, rkvarhLag: $rkvarhLag, rkvarhLead: $rkvarhLead, mdRecorded: $mdRecorded, loggedAt: $loggedAt, powerFactor: $powerFactor)';
}


}

/// @nodoc
abstract mixin class $SubmitManualReadingFormCopyWith<$Res> implements $EnergyEventCopyWith<$Res> {
  factory $SubmitManualReadingFormCopyWith(SubmitManualReadingForm value, $Res Function(SubmitManualReadingForm) _then) = _$SubmitManualReadingFormCopyWithImpl;
@useResult
$Res call({
 String meterName, double currentKwh, double previousKwh, double currentKvah, double previousKvah, double rkvarhLag, double rkvarhLead, double mdRecorded, DateTime loggedAt, double? powerFactor
});




}
/// @nodoc
class _$SubmitManualReadingFormCopyWithImpl<$Res>
    implements $SubmitManualReadingFormCopyWith<$Res> {
  _$SubmitManualReadingFormCopyWithImpl(this._self, this._then);

  final SubmitManualReadingForm _self;
  final $Res Function(SubmitManualReadingForm) _then;

/// Create a copy of EnergyEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? meterName = null,Object? currentKwh = null,Object? previousKwh = null,Object? currentKvah = null,Object? previousKvah = null,Object? rkvarhLag = null,Object? rkvarhLead = null,Object? mdRecorded = null,Object? loggedAt = null,Object? powerFactor = freezed,}) {
  return _then(SubmitManualReadingForm(
meterName: null == meterName ? _self.meterName : meterName // ignore: cast_nullable_to_non_nullable
as String,currentKwh: null == currentKwh ? _self.currentKwh : currentKwh // ignore: cast_nullable_to_non_nullable
as double,previousKwh: null == previousKwh ? _self.previousKwh : previousKwh // ignore: cast_nullable_to_non_nullable
as double,currentKvah: null == currentKvah ? _self.currentKvah : currentKvah // ignore: cast_nullable_to_non_nullable
as double,previousKvah: null == previousKvah ? _self.previousKvah : previousKvah // ignore: cast_nullable_to_non_nullable
as double,rkvarhLag: null == rkvarhLag ? _self.rkvarhLag : rkvarhLag // ignore: cast_nullable_to_non_nullable
as double,rkvarhLead: null == rkvarhLead ? _self.rkvarhLead : rkvarhLead // ignore: cast_nullable_to_non_nullable
as double,mdRecorded: null == mdRecorded ? _self.mdRecorded : mdRecorded // ignore: cast_nullable_to_non_nullable
as double,loggedAt: null == loggedAt ? _self.loggedAt : loggedAt // ignore: cast_nullable_to_non_nullable
as DateTime,powerFactor: freezed == powerFactor ? _self.powerFactor : powerFactor // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}

// dart format on
