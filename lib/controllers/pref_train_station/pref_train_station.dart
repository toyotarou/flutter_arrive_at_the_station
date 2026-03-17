import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/http/client.dart';
import '../../data/http/path.dart';
import '../../extensions/extensions.dart';
import '../../model/pref_train_station_model.dart';
import '../../utility/utility.dart';

part 'pref_train_station.freezed.dart';

part 'pref_train_station.g.dart';

@freezed
class PrefTrainStationState with _$PrefTrainStationState {
  const factory PrefTrainStationState({
    @Default('') String selectedPrefName,

    @Default(<PrefTrainModel>[]) List<PrefTrainModel> prefTrainList,
    @Default(<String, PrefTrainModel>{}) Map<String, PrefTrainModel> prefTrainMap,
    @Default(<String, List<PrefTrainModel>>{}) Map<String, List<PrefTrainModel>> prefStationTokyoTrainModelListMap,
  }) = _PrefTrainStationState;
}

@Riverpod(keepAlive: true)
class PrefTrainStation extends _$PrefTrainStation {
  final Utility utility = Utility();

  ///
  @override
  PrefTrainStationState build() => const PrefTrainStationState();

  //============================================== api

  ///
  Future<PrefTrainStationState> fetchPrefTrainStationData({required String prefName}) async {
    final HttpClient client = ref.read(httpClientProvider);

    try {
      final List<PrefTrainModel> list = <PrefTrainModel>[];
      final Map<String, PrefTrainModel> map = <String, PrefTrainModel>{};
      final Map<String, List<PrefTrainModel>> map2 = <String, List<PrefTrainModel>>{};

      // ignore: always_specify_types
      await client.post(path: APIPath.getPrefTrainStation, body: {'pref': prefName}).then((value) {
        // ignore: avoid_dynamic_calls
        for (int i = 0; i < value['data'].length.toString().toInt(); i++) {
          // ignore: avoid_dynamic_calls
          final PrefTrainModel val = PrefTrainModel.fromJson(value['data'][i] as Map<String, dynamic>);

          list.add(val);

          map[val.trainName] = val;

          for (final PrefStationModel element in val.station) {
            (map2[element.stationName] ??= <PrefTrainModel>[]).add(
              PrefTrainModel(trainNumber: val.trainNumber, trainName: val.trainName, station: <PrefStationModel>[]),
            );
          }
        }
      });

      return state.copyWith(
        selectedPrefName: prefName,
        prefTrainList: list,
        prefTrainMap: map,
        prefStationTokyoTrainModelListMap: map2,
      );
    } catch (e) {
      utility.showError('予期せぬエラーが発生しました');
      rethrow;
    }
  }

  ///
  Future<void> getPrefTrainStation({required String prefName}) async {
    try {
      final PrefTrainStationState newState = await fetchPrefTrainStationData(prefName: prefName);

      state = newState;
    } catch (_) {}
  }

  //============================================== api
}
