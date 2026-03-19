import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/http/client.dart';
import '../../data/http/path.dart';
import '../../extensions/extensions.dart';
import '../../model/pref_train_station_model.dart';
import '../../model/station_model.dart';
import '../../model/train_model.dart';
import '../../utility/data_repair.dart';
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

    /// 現在地から半径X km圏内の全駅リスト
    @Default(<PrefStationModel>[]) List<PrefStationModel> nearbyStations,
  }) = _PrefTrainStationState;
}

@Riverpod(keepAlive: true)
class PrefTrainStation extends _$PrefTrainStation {
  final Utility utility = Utility();

  DataRepair dataRepair = DataRepair();

  ///
  @override
  PrefTrainStationState build() => const PrefTrainStationState();

  //============================================== api

  /// 指定された都道府県の全路線・駅データを取得して補正する
  ///
  /// 【処理の流れ】
  /// 1. getTrain API       : 路線番号 → 路線名 の対応表を作成
  /// 2. getAllStation API   : 全国駅データを取得し、路線名・路線番号でインデックス化
  /// 3. getPrefTrainStation API : 対象都道府県の路線・駅データを取得し、以下の補正を適用
  ///    ① stationMap補正   : 路線名が stationMap に存在する場合、駅名セットが異なれば駅順を補正
  ///    ② repairTrainNumber補正 : stationMap にない路線（JR八高線等）は複数の路線番号をマージして補正
  ///    ③ patchMap適用     : utility の手動パッチデータが存在する路線はそれを正として駅リストを完全置換
  ///                         （APIが返さない駅の追加・誤座標の修正・駅順の確定に使用）
  Future<PrefTrainStationState> fetchPrefTrainStationData({required String prefName}) async {
    final HttpClient client = ref.read(httpClientProvider);

    try {
      // -----------------------------------------------
      // ① getTrain: 路線番号 → 路線名 の対応表を作成
      // -----------------------------------------------
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

      // -----------------------------------------------
      // ② getAllStation: 全駅データを取得
      //    stationMap          : 路線名 → 駅リスト（駅順補正の参照元）
      //    lineNumberToStationsMap : 路線番号 → 駅リスト（repairTrainNumber補正用）
      // -----------------------------------------------
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

      // -----------------------------------------------
      // ③ getPrefTrainStation: 都道府県の路線・駅データを取得して補正
      // -----------------------------------------------
      final List<PrefTrainModel> list = <PrefTrainModel>[];
      final Map<String, PrefTrainModel> map = <String, PrefTrainModel>{};
      final Map<String, List<PrefTrainModel>> map2 = <String, List<PrefTrainModel>>{};

      // 手動パッチデータ（utility に定義）: 都道府県 → 路線名 → 駅名 → 補正済み PrefStationModel
      // APIの誤座標・欠落駅・誤った駅順を修正するために使用
      final Map<String, Map<String, Map<String, PrefStationModel>>> patchMap = dataRepair
          .getStationDataRepairPrefStationModel();

      // ignore: always_specify_types
      await client.post(path: APIPath.getPrefTrainStation, body: {'pref': prefName}).then((value) {
        // ignore: avoid_dynamic_calls
        for (int i = 0; i < value['data'].length.toString().toInt(); i++) {
          // ignore: avoid_dynamic_calls
          PrefTrainModel val = PrefTrainModel.fromJson(value['data'][i] as Map<String, dynamic>);

          final Set<String> apiStationNames = val.station.map((PrefStationModel s) => s.stationName).toSet();

          // --- 補正① stationMap補正 ---
          // getPrefTrainStation の駅順が getAllStation と異なる場合に駅順を揃える
          // 例: JR千歳線・JR宗谷本線・JR釧網本線 など
          if (stationMap.containsKey(val.trainName)) {
            final List<StationModel> smStations = stationMap[val.trainName]!;
            final Set<String> smStationNames = smStations.map((StationModel s) => s.stationName).toSet();
            // 駅名セットが一致する場合のみ補正（異なる場合は駅構成が違う路線扱いでスキップ）
            if (apiStationNames != smStationNames) {
              val = _correctByStationMap(val: val, smStations: smStations);
            }
          } else {
            // --- 補正② repairTrainNumber補正 ---
            // stationMap に路線名が存在しない路線（getAllStation と路線名が異なるケース）
            // utility.getRepairTrainNumber で対応する路線番号を取得してマージ
            // 例: JR八高線（2路線番号をマージ）、わたらせ渓谷鐵道線、上信電鉄上信線
            final List<String> repairNumbers = dataRepair.getRepairTrainNumber(trainName: val.trainName);
            if (repairNumbers.isNotEmpty) {
              // 複数の路線番号の駅を結合（重複駅名は先着優先で除去）
              final List<StationModel> merged = <StationModel>[];
              final Set<String> seen = <String>{};
              for (final String lineNum in repairNumbers) {
                for (final StationModel s in lineNumberToStationsMap[lineNum] ?? <StationModel>[]) {
                  if (seen.add(s.stationName)) {
                    merged.add(s);
                  }
                }
              }
              final Set<String> mergedNames = merged.map((StationModel s) => s.stationName).toSet();
              if (apiStationNames != mergedNames) {
                val = _correctByStationMap(val: val, smStations: merged);
              }
            }
            // repairNumbers が空の路線はどちらの補正も行わず getPrefTrainStation のデータをそのまま使用
            // 例: 上毛電鉄・上越新幹線・北陸新幹線
          }

          // --- 補正③ patchMap適用 ---
          // utility.getStationDataRepairPrefStationModel に定義された手動パッチが存在する場合、
          // パッチデータを正として駅リストを完全再構築する
          // ・APIが返さない駅の補完（例: 京王新線の新宿）
          // ・誤った緯度経度の修正（例: JR宗谷本線の石北本線混入）
          // ・駅順の確定（パッチの並び順がそのまま採用される）
          // ※ API側の id / address は名前一致でマージ、存在しない場合は空文字
          final Map<String, PrefStationModel>? trainPatch = patchMap[prefName]?[val.trainName];
          if (trainPatch != null) {
            final Map<String, PrefStationModel> apiStationMap = <String, PrefStationModel>{
              for (final PrefStationModel s in val.station) s.stationName: s,
            };
            final List<PrefStationModel> patched = trainPatch.values.map((PrefStationModel patch) {
              final PrefStationModel? api = apiStationMap[patch.stationName];
              return PrefStationModel(
                id: api?.id ?? '',
                stationName: patch.stationName,
                address: api?.address ?? '',
                lat: patch.lat,
                lng: patch.lng,
                order: patch.order,
              );
            }).toList();
            patched.sort((PrefStationModel a, PrefStationModel b) => a.order.compareTo(b.order));
            val = PrefTrainModel(trainNumber: val.trainNumber, trainName: val.trainName, station: patched);
          }

          //残しておく（駅順検証用デバッグコード）
          // getStationDataRepairValue の期待順序と API の実際の順序を照合する
          // 不一致の路線を特定するために使用した。現在は patchMap で対処済み
          /*
          final List<String>? repairStations = repairMap[prefName]?[val.trainName];
          if (repairStations != null) {
            if (originalApiNames.join(',') == repairStations.join(',')) {
              print('✅ API一致（getStationDataRepairValueから削除可）: $prefName | ${val.trainName}');
            } else {
              print('❌ API不一致 → getStationDataRepairValue で補正: $prefName | ${val.trainName}');
              val = _correctByNameOrder(val: val, nameOrder: repairStations);
            }
          }
          */

          list.add(val);

          map[val.trainName] = val;

          // 駅名 → その駅が属する路線リスト（駅タップ時の路線表示用）
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

  /// 複数県の全駅を取得して nearbyStations にまとめて保存する
  Future<void> fetchNearbyStations({required List<String> prefNames}) async {
    final List<PrefStationModel> allStations = <PrefStationModel>[];

    for (final String prefName in prefNames) {
      try {
        final PrefTrainStationState prefState = await fetchPrefTrainStationData(prefName: prefName);
        for (final PrefTrainModel train in prefState.prefTrainList) {
          allStations.addAll(train.station);
        }
      } catch (_) {}
    }

    state = state.copyWith(nearbyStations: allStations);
  }

  //============================================== api

  //残しておく
  // /// getStationDataRepairValue の駅名順リストを使って駅順を補正する
  // PrefTrainModel _correctByNameOrder({required PrefTrainModel val, required List<String> nameOrder}) {
  //   final Map<String, int> orderMap = <String, int>{};
  //   for (int i = 0; i < nameOrder.length; i++) {
  //     orderMap[nameOrder[i]] = i;
  //   }
  //
  //   final List<PrefStationModel> sorted = List<PrefStationModel>.from(val.station);
  //   sorted.sort((PrefStationModel a, PrefStationModel b) {
  //     final int idxA = orderMap[a.stationName] ?? nameOrder.length;
  //     final int idxB = orderMap[b.stationName] ?? nameOrder.length;
  //     return idxA.compareTo(idxB);
  //   });
  //
  //   final List<PrefStationModel> corrected = <PrefStationModel>[];
  //   for (int i = 0; i < sorted.length; i++) {
  //     final PrefStationModel s = sorted[i];
  //     corrected.add(
  //       PrefStationModel(id: s.id, stationName: s.stationName, address: s.address, lat: s.lat, lng: s.lng, order: i),
  //     );
  //   }
  //
  //   return PrefTrainModel(trainNumber: val.trainNumber, trainName: val.trainName, station: corrected);
  // }

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

    // print('★ 並び補正が発動: ${val.trainName}');
    // print('  getPrefTrainStation の駅順: ${val.station.map((PrefStationModel s) => s.stationName).join(' → ')}');

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
