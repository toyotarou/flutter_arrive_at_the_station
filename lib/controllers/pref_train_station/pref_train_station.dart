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
      final Map<String, List<StationModel>> lineNumberToStationsMap = <String, List<StationModel>>{};

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

          (lineNumberToStationsMap[val.lineNumber] ??= <StationModel>[]).add(val);
        }
      });

      //================================================//

      final List<PrefTrainModel> list = <PrefTrainModel>[];
      final Map<String, PrefTrainModel> map = <String, PrefTrainModel>{};
      final Map<String, List<PrefTrainModel>> map2 = <String, List<PrefTrainModel>>{};

      // ignore: always_specify_types
      await client.post(path: APIPath.getPrefTrainStation, body: {'pref': prefName}).then((value) {
        // ignore: avoid_dynamic_calls
        for (int i = 0; i < value['data'].length.toString().toInt(); i++) {
          // ignore: avoid_dynamic_calls
          PrefTrainModel val = PrefTrainModel.fromJson(value['data'][i] as Map<String, dynamic>);

          // APIの駅名セット
          final Set<String> apiStationNames = val.station.map((PrefStationModel s) => s.stationName).toSet();

          if (stationMap.containsKey(val.trainName)) {
            // stationMapと駅名セットが異なる場合のみ補正（APIデータ優先）
            final List<StationModel> smStations = stationMap[val.trainName]!;
            final Set<String> smStationNames = smStations.map((StationModel s) => s.stationName).toSet();
            if (apiStationNames != smStationNames) {
              val = _correctByStationMap(val: val, smStations: smStations);
            }
          } else {
            // stationMapにない路線はrepairTrainNumberで補正
            final List<String> repairNumbers = utility.getRepairTrainNumber(trainName: val.trainName);
            if (repairNumbers.isNotEmpty) {
              // 複数路線番号をマージ（重複駅名は先着優先で除去）
              final List<StationModel> merged = <StationModel>[];
              final Set<String> seen = <String>{};
              for (final String lineNum in repairNumbers) {
                for (final StationModel s in lineNumberToStationsMap[lineNum] ?? <StationModel>[]) {
                  if (seen.add(s.stationName)) {
                    merged.add(s);
                  }
                }
              }
              // repairでも駅名セットが異なる場合のみ補正
              final Set<String> mergedNames = merged.map((StationModel s) => s.stationName).toSet();
              if (apiStationNames != mergedNames) {
                val = _correctByStationMap(val: val, smStations: merged);
              }
            }
            // repairNumbersが空の路線（上毛電鉄・上越新幹線・北陸新幹線）はprefAPIをそのまま使用
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

  /// stationMapまたはrepairの駅リストを使ってPrefTrainModelの駅順を補正する
  /// APIデータを主とし、並び順が異なる場合のみstationMapの順序でソートする
  PrefTrainModel _correctByStationMap({required PrefTrainModel val, required List<StationModel> smStations}) {
    // stationMapの駅名→順序インデックスを作成
    final Map<String, int> smOrderMap = <String, int>{};
    for (int i = 0; i < smStations.length; i++) {
      smOrderMap[smStations[i].stationName] = i;
    }

    // APIの駅リスト（内容はAPIデータをそのまま保持）
    final List<PrefStationModel> apiStations = List<PrefStationModel>.from(val.station);

    // 並び順が異なるか確認（共通駅のstationMap上のインデックスが単調増加かチェック）
    bool orderDiffers = false;
    int lastSmIndex = -1;
    for (final PrefStationModel s in apiStations) {
      final int? smIdx = smOrderMap[s.stationName];
      if (smIdx != null) {
        if (smIdx < lastSmIndex) {
          orderDiffers = true;
          break;
        }
        lastSmIndex = smIdx;
      }
    }

    // 並び順が同じ場合はAPIデータをそのまま返す
    if (!orderDiffers) {
      return val;
    }

    // 並び順が異なる場合のみstationMapの順序でAPIの駅をソート
    // stationMapにない駅はsmStations.lengthを割り当て、元のAPI順序を維持して末尾に配置
    final Map<String, int> apiOriginalOrder = <String, int>{};
    for (int i = 0; i < apiStations.length; i++) {
      apiOriginalOrder[apiStations[i].stationName] = i;
    }

    apiStations.sort((PrefStationModel a, PrefStationModel b) {
      final int idxA = smOrderMap[a.stationName] ?? (smStations.length + (apiOriginalOrder[a.stationName] ?? 0));
      final int idxB = smOrderMap[b.stationName] ?? (smStations.length + (apiOriginalOrder[b.stationName] ?? 0));
      return idxA.compareTo(idxB);
    });

    // orderフィールドを振り直す（内容はAPIデータをそのまま使用）
    final List<PrefStationModel> corrected = <PrefStationModel>[];
    for (int idx = 0; idx < apiStations.length; idx++) {
      final PrefStationModel s = apiStations[idx];
      corrected.add(
        PrefStationModel(id: s.id, stationName: s.stationName, address: s.address, lat: s.lat, lng: s.lng, order: idx),
      );
    }

    return PrefTrainModel(trainNumber: val.trainNumber, trainName: val.trainName, station: corrected);
  }
}
