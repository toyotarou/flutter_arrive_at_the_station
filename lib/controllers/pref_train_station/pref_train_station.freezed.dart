// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'pref_train_station.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$PrefTrainStationState {
  String get selectedPrefName => throw _privateConstructorUsedError;
  List<PrefTrainModel> get prefTrainList => throw _privateConstructorUsedError;
  Map<String, PrefTrainModel> get prefTrainMap =>
      throw _privateConstructorUsedError;
  Map<String, List<PrefTrainModel>> get prefStationTokyoTrainModelListMap =>
      throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $PrefTrainStationStateCopyWith<PrefTrainStationState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PrefTrainStationStateCopyWith<$Res> {
  factory $PrefTrainStationStateCopyWith(PrefTrainStationState value,
          $Res Function(PrefTrainStationState) then) =
      _$PrefTrainStationStateCopyWithImpl<$Res, PrefTrainStationState>;
  @useResult
  $Res call(
      {String selectedPrefName,
      List<PrefTrainModel> prefTrainList,
      Map<String, PrefTrainModel> prefTrainMap,
      Map<String, List<PrefTrainModel>> prefStationTokyoTrainModelListMap});
}

/// @nodoc
class _$PrefTrainStationStateCopyWithImpl<$Res,
        $Val extends PrefTrainStationState>
    implements $PrefTrainStationStateCopyWith<$Res> {
  _$PrefTrainStationStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? selectedPrefName = null,
    Object? prefTrainList = null,
    Object? prefTrainMap = null,
    Object? prefStationTokyoTrainModelListMap = null,
  }) {
    return _then(_value.copyWith(
      selectedPrefName: null == selectedPrefName
          ? _value.selectedPrefName
          : selectedPrefName // ignore: cast_nullable_to_non_nullable
              as String,
      prefTrainList: null == prefTrainList
          ? _value.prefTrainList
          : prefTrainList // ignore: cast_nullable_to_non_nullable
              as List<PrefTrainModel>,
      prefTrainMap: null == prefTrainMap
          ? _value.prefTrainMap
          : prefTrainMap // ignore: cast_nullable_to_non_nullable
              as Map<String, PrefTrainModel>,
      prefStationTokyoTrainModelListMap: null ==
              prefStationTokyoTrainModelListMap
          ? _value.prefStationTokyoTrainModelListMap
          : prefStationTokyoTrainModelListMap // ignore: cast_nullable_to_non_nullable
              as Map<String, List<PrefTrainModel>>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PrefTrainStationStateImplCopyWith<$Res>
    implements $PrefTrainStationStateCopyWith<$Res> {
  factory _$$PrefTrainStationStateImplCopyWith(
          _$PrefTrainStationStateImpl value,
          $Res Function(_$PrefTrainStationStateImpl) then) =
      __$$PrefTrainStationStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String selectedPrefName,
      List<PrefTrainModel> prefTrainList,
      Map<String, PrefTrainModel> prefTrainMap,
      Map<String, List<PrefTrainModel>> prefStationTokyoTrainModelListMap});
}

/// @nodoc
class __$$PrefTrainStationStateImplCopyWithImpl<$Res>
    extends _$PrefTrainStationStateCopyWithImpl<$Res,
        _$PrefTrainStationStateImpl>
    implements _$$PrefTrainStationStateImplCopyWith<$Res> {
  __$$PrefTrainStationStateImplCopyWithImpl(_$PrefTrainStationStateImpl _value,
      $Res Function(_$PrefTrainStationStateImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? selectedPrefName = null,
    Object? prefTrainList = null,
    Object? prefTrainMap = null,
    Object? prefStationTokyoTrainModelListMap = null,
  }) {
    return _then(_$PrefTrainStationStateImpl(
      selectedPrefName: null == selectedPrefName
          ? _value.selectedPrefName
          : selectedPrefName // ignore: cast_nullable_to_non_nullable
              as String,
      prefTrainList: null == prefTrainList
          ? _value._prefTrainList
          : prefTrainList // ignore: cast_nullable_to_non_nullable
              as List<PrefTrainModel>,
      prefTrainMap: null == prefTrainMap
          ? _value._prefTrainMap
          : prefTrainMap // ignore: cast_nullable_to_non_nullable
              as Map<String, PrefTrainModel>,
      prefStationTokyoTrainModelListMap: null ==
              prefStationTokyoTrainModelListMap
          ? _value._prefStationTokyoTrainModelListMap
          : prefStationTokyoTrainModelListMap // ignore: cast_nullable_to_non_nullable
              as Map<String, List<PrefTrainModel>>,
    ));
  }
}

/// @nodoc

class _$PrefTrainStationStateImpl implements _PrefTrainStationState {
  const _$PrefTrainStationStateImpl(
      {this.selectedPrefName = '',
      final List<PrefTrainModel> prefTrainList = const <PrefTrainModel>[],
      final Map<String, PrefTrainModel> prefTrainMap =
          const <String, PrefTrainModel>{},
      final Map<String, List<PrefTrainModel>> prefStationTokyoTrainModelListMap =
          const <String, List<PrefTrainModel>>{}})
      : _prefTrainList = prefTrainList,
        _prefTrainMap = prefTrainMap,
        _prefStationTokyoTrainModelListMap = prefStationTokyoTrainModelListMap;

  @override
  @JsonKey()
  final String selectedPrefName;
  final List<PrefTrainModel> _prefTrainList;
  @override
  @JsonKey()
  List<PrefTrainModel> get prefTrainList {
    if (_prefTrainList is EqualUnmodifiableListView) return _prefTrainList;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_prefTrainList);
  }

  final Map<String, PrefTrainModel> _prefTrainMap;
  @override
  @JsonKey()
  Map<String, PrefTrainModel> get prefTrainMap {
    if (_prefTrainMap is EqualUnmodifiableMapView) return _prefTrainMap;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_prefTrainMap);
  }

  final Map<String, List<PrefTrainModel>> _prefStationTokyoTrainModelListMap;
  @override
  @JsonKey()
  Map<String, List<PrefTrainModel>> get prefStationTokyoTrainModelListMap {
    if (_prefStationTokyoTrainModelListMap is EqualUnmodifiableMapView)
      return _prefStationTokyoTrainModelListMap;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_prefStationTokyoTrainModelListMap);
  }

  @override
  String toString() {
    return 'PrefTrainStationState(selectedPrefName: $selectedPrefName, prefTrainList: $prefTrainList, prefTrainMap: $prefTrainMap, prefStationTokyoTrainModelListMap: $prefStationTokyoTrainModelListMap)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PrefTrainStationStateImpl &&
            (identical(other.selectedPrefName, selectedPrefName) ||
                other.selectedPrefName == selectedPrefName) &&
            const DeepCollectionEquality()
                .equals(other._prefTrainList, _prefTrainList) &&
            const DeepCollectionEquality()
                .equals(other._prefTrainMap, _prefTrainMap) &&
            const DeepCollectionEquality().equals(
                other._prefStationTokyoTrainModelListMap,
                _prefStationTokyoTrainModelListMap));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      selectedPrefName,
      const DeepCollectionEquality().hash(_prefTrainList),
      const DeepCollectionEquality().hash(_prefTrainMap),
      const DeepCollectionEquality().hash(_prefStationTokyoTrainModelListMap));

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$PrefTrainStationStateImplCopyWith<_$PrefTrainStationStateImpl>
      get copyWith => __$$PrefTrainStationStateImplCopyWithImpl<
          _$PrefTrainStationStateImpl>(this, _$identity);
}

abstract class _PrefTrainStationState implements PrefTrainStationState {
  const factory _PrefTrainStationState(
      {final String selectedPrefName,
      final List<PrefTrainModel> prefTrainList,
      final Map<String, PrefTrainModel> prefTrainMap,
      final Map<String, List<PrefTrainModel>>
          prefStationTokyoTrainModelListMap}) = _$PrefTrainStationStateImpl;

  @override
  String get selectedPrefName;
  @override
  List<PrefTrainModel> get prefTrainList;
  @override
  Map<String, PrefTrainModel> get prefTrainMap;
  @override
  Map<String, List<PrefTrainModel>> get prefStationTokyoTrainModelListMap;
  @override
  @JsonKey(ignore: true)
  _$$PrefTrainStationStateImplCopyWith<_$PrefTrainStationStateImpl>
      get copyWith => throw _privateConstructorUsedError;
}
