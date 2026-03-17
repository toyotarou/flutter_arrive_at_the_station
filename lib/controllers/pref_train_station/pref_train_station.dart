import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/http/client.dart';
import '../../data/http/path.dart';
import '../../extensions/extensions.dart';
import '../../model/pref_train_station_model.dart';
import '../../model/station_model.dart';
import '../../model/train_model.dart';
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
      //================================================//

      final Map<String, String> trainMap = <String, String>{};

      // ignore: always_specify_types
      await client.post(path: APIPath.getTrain).then((value) {
        // ignore: avoid_dynamic_calls
        for (int i = 0; i < value['data'].length.toString().toInt(); i++) {
          // ignore: avoid_dynamic_calls
          final TrainModel val = TrainModel.fromJson(value['data'][i] as Map<String, dynamic>);

          trainMap[val.trainNumber] = val.trainName;
        }
      });

      //================================================//

      //================================================//

      final Map<String, List<StationModel>> stationMap = <String, List<StationModel>>{};

      // ignore: always_specify_types
      await client.post(path: APIPath.getAllStation).then((value) {
        // ignore: avoid_dynamic_calls
        for (int i = 0; i < value['data'].length.toString().toInt(); i++) {
          // ignore: avoid_dynamic_calls
          final StationModel val = StationModel.fromJson(value['data'][i] as Map<String, dynamic>);

          final String? trainName = trainMap[val.lineNumber];

          if (trainName != null) {
            (stationMap[trainName] ??= <StationModel>[]).add(val);
          }
        }
      });

      //================================================//

      final List<PrefTrainModel> list = <PrefTrainModel>[];
      final Map<String, PrefTrainModel> map = <String, PrefTrainModel>{};
      final Map<String, List<PrefTrainModel>> map2 = <String, List<PrefTrainModel>>{};

      // 駅単位の修正データをパース: "prefName;trainName;order;stationName;lat;lng"
      final List<List<String>> repairStationEntries = utility
          .mapWrongInfoRepairStationValue()
          .map((String s) => s.split(';'))
          .where((List<String> parts) => parts.length == 6 && parts[0] == prefName)
          .toList();

      // 路線丸ごと入れ替えデータをパース & trainNameでグループ化
      final Map<String, List<PrefStationModel>> repairLineMap = <String, List<PrefStationModel>>{};
      for (final String raw in utility.mapWrongInfoRepairLineValue()) {
        final List<String> p = raw.split(';');
        if (p.length != 6 || p[0] != prefName) {
          continue;
        }
        final String trainName = p[1];
        (repairLineMap[trainName] ??= <PrefStationModel>[]).add(
          PrefStationModel(
            id: 'repair-line-${p[2]}',
            stationName: p[3],
            address: '',
            lat: double.parse(p[4]),
            lng: double.parse(p[5]),
            order: int.parse(p[2]),
          ),
        );
      }

      // ignore: always_specify_types
      await client.post(path: APIPath.getPrefTrainStation, body: {'pref': prefName}).then((value) {
        // ignore: avoid_dynamic_calls
        for (int i = 0; i < value['data'].length.toString().toInt(); i++) {
          // ignore: avoid_dynamic_calls
          PrefTrainModel val = PrefTrainModel.fromJson(value['data'][i] as Map<String, dynamic>);

          // 路線丸ごと入れ替え（repairLineMapが優先）
          if (repairLineMap.containsKey(val.trainName)) {
            final List<PrefStationModel> stations = List<PrefStationModel>.from(repairLineMap[val.trainName]!)
              ..sort((PrefStationModel a, PrefStationModel b) => a.order.compareTo(b.order));
            val = PrefTrainModel(trainNumber: val.trainNumber, trainName: val.trainName, station: stations);
          } else {
            // 駅単位の修正を適用
            final List<List<String>> matched = repairStationEntries
                .where((List<String> p) => p[1] == val.trainName)
                .toList();
            if (matched.isNotEmpty) {
              final List<PrefStationModel> stations = List<PrefStationModel>.from(val.station);
              for (final List<String> p in matched) {
                final int repairOrder = int.parse(p[2]);
                final PrefStationModel repairStation = PrefStationModel(
                  id: 'repair-$repairOrder',
                  stationName: p[3],
                  address: '',
                  lat: double.parse(p[4]),
                  lng: double.parse(p[5]),
                  order: repairOrder,
                );
                final int existingIndex = stations.indexWhere((PrefStationModel s) => s.order == repairOrder);
                if (existingIndex >= 0) {
                  stations[existingIndex] = repairStation;
                } else {
                  stations.add(repairStation);
                }
              }
              stations.sort((PrefStationModel a, PrefStationModel b) => a.order.compareTo(b.order));
              val = PrefTrainModel(trainNumber: val.trainNumber, trainName: val.trainName, station: stations);
            }
          }

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
