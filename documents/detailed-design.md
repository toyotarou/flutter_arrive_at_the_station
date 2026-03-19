# あの駅に着いたら (EKI NI TSUITARA) 詳細設計書

> **この設計書について**
>
> 詳細設計書とは「プログラムをどう作るか」を書いたドキュメントです。
> 基本設計書（何を作るか）の次のステップにあたり、
> 開発者がコードを書くために必要な情報をすべて記載します。
>
> | セクション | 書く内容 | なぜ必要か |
> |---|---|---|
> | 1. システム概要 | アプリ全体の目的と構成 | 新メンバーが全体像を把握するため |
> | 2. アーキテクチャ | 技術選定と設計方針 | 「なぜこう作ったか」を残すため |
> | 3. ディレクトリ構成 | ファイルの配置ルール | どこに何があるか迷わないため |
> | 4. データモデル | データの型と構造 | APIとの整合性を保つため |
> | 5. 状態管理 | Providerの一覧と役割 | データの流れを明確にするため |
> | 6. 画面設計 | 各画面のUI構成と動作 | 実装の仕様を明確にするため |
> | 7. API連携 | エンドポイントと通信仕様 | サーバーとの契約を明文化するため |
> | 8. ジオフェンス仕様 | ジオフェンスの設定値と動作 | プラットフォーム差異を明確にするため |
> | 9. ビルド手順 | 開発環境のセットアップ | 「動かない」を防ぐため |

---

## 1. システム概要

### 1.1 アプリの目的

日本全国の任意の電車駅を選択し、その駅の半径1000m圏内に入ったときにプッシュ通知とループバイブレーション（ユーザーが停止するまで継続）で知らせる、乗り越し防止モバイルアプリケーション。都道府県ポリゴンの地図から直感的に駅を選択でき、GPS位置情報による近傍駅の自動表示にも対応する。

### 1.2 主な機能

| 機能 | 概要 |
|---|---|
| 都道府県マップ表示 | ローカルGeoJSONから都道府県ポリゴンを生成し、48色でカラーリングしてflutter_mapで表示 |
| 近傍都道府県の自動検出 | 10秒ごとにGPS位置を取得し、30km圏内の都道府県の駅データを自動取得 |
| 近傍駅マップ表示 | 現在地から指定半径（1〜20km）内の駅をマーカー表示。距離も表示する |
| 都道府県別路線・駅一覧 | 選択都道府県のAPIデータをDataRepairで補正後、路線別に表示 |
| 駅名検索 | BottomSheetで駅名を部分一致検索し、路線リストへスクロールジャンプ |
| 路線ポリライン表示 | 選択路線の全駅をポリラインで地図描画し、バウンズズームに対応 |
| 駅選択・ジオフェンス設定 | 一覧または近傍マップから駅を選択し、ワンタップでジオフェンスを登録 |
| 降車通知 | 圏内進入時にプッシュ通知とループバイブレーション（最大強度）で通知 |
| 選択駅の永続化 | SharedPreferencesに選択駅JSONを保存し、アプリ再起動後にジオフェンスを復元 |
| APIデータ補正 | stationMap補正・repairTrainNumber補正・patchMap適用の3段階でデータ品質を担保 |

### 1.3 動作環境

| 項目 | 値 |
|---|---|
| フレームワーク | Flutter 3.x (Dart 3.x) |
| 対応OS | Android / iOS |
| 画面方向 | 縦固定 |
| 外部APIサーバー | http://toyohide.work (POST通信) |
| 地図タイル | OpenStreetMap (https://tile.openstreetmap.org/{z}/{x}/{y}.png) |
| 都道府県ポリゴン | assets/json/japan_pref.json（GeoJSON形式・ローカル） |

---

## 2. アーキテクチャ（設計方針）

### 2.1 技術スタック

```
┌──────────────────────────────────────────────────────────────┐
│                         UI層                                  │
│  Widget (ConsumerStatefulWidget)                              │
│  flutter_map (地図・ポリゴン・マーカー・ポリライン表示)            │
├──────────────────────────────────────────────────────────────┤
│                       状態管理層                               │
│  Riverpod (@riverpod アノテーション方式)                        │
│  コード生成: riverpod_generator + build_runner                 │
├──────────────────────────────────────────────────────────────┤
│                      データモデル層                             │
│  手書きクラス (PrefStationModel / PrefTrainModel)              │
│  freezed (PrefTrainStationState のみ)                        │
├──────────────────────────────────────────────────────────────┤
│                       通信層                                   │
│  http パッケージ (REST API通信)                                │
│  HttpClient クラス（data/http/client.dart）                   │
├──────────────────────────────────────────────────────────────┤
│                    ジオフェンス・通知層                          │
│  native_geofence (OSネイティブジオフェンスの利用)               │
│  flutter_local_notifications (プッシュ通知)                    │
│  vibration (ループバイブレーション制御)                          │
│  flutter_volume_controller (音楽ストリーム音量制御)              │
│  permission_handler (パーミッション要求)                        │
│  geolocator (GPS位置情報取得)                                  │
├──────────────────────────────────────────────────────────────┤
│                      永続化層                                   │
│  shared_preferences (選択駅の端末保存・復元)                    │
│  SharedPreferencesService (永続化操作をまとめたユーティリティ)   │
├──────────────────────────────────────────────────────────────┤
│                     スクロール制御層                             │
│  scrollable_positioned_list (インデックス指定スクロール)          │
├──────────────────────────────────────────────────────────────┤
│                    データ補正層                                  │
│  DataRepair (APIデータ品質補正ロジック)                          │
└──────────────────────────────────────────────────────────────┘
              ↕ HTTP POST (JSON)
┌──────────────────────────────────────────────────────────────┐
│               外部APIサーバー (toyohide.work)                  │
└──────────────────────────────────────────────────────────────┘
```

### 2.2 設計ルール

| ルール | 説明 |
|---|---|
| Widgetの基底クラス | Providerを使う画面は `ConsumerStatefulWidget`（with ControllersMixin）を使う |
| 状態管理 | `@riverpod` アノテーション + コード生成。手書きProviderは使わない |
| API通信 | Provider内で `HttpClient.post()` を呼び出す。Widgetから直接APIを叩かない |
| ジオフェンスコールバック | トップレベル関数として定義する（Flutterのバックグラウンド実行の制約による） |
| テーマ | ダークテーマ統一。`ThemeData.dark(useMaterial3: false)` を使用 |
| データ補正 | `DataRepair` クラスに集約し、Provider内で使用する |

### 2.3 カラーパレット

| 用途 | 値 | 説明 |
|---|---|---|
| テーマ | `ThemeData.dark(useMaterial3: false)` | Flutter標準ダークテーマ |
| 都道府県（選択中） | `Colors.white.withOpacity(0.85)` | 選択中の都道府県ハイライト |
| 都道府県（未選択） | 48色パレット（`getFortyEightColor()`）| 各都道府県の識別色 |
| 選択状態（アクティブ） | `Colors.yellowAccent` | 選択中の駅インジケーター・パーミッション付与済みアイコン |
| 近傍駅（未選択） | `Colors.blueAccent.withValues(alpha: 0.85)` | 近傍駅マーカーの色 |
| 近傍駅（選択中） | `Colors.redAccent.withValues(alpha: 0.9)` | 選択中の近傍駅マーカーの色 |
| 路線ポリライン | `Colors.greenAccent.withOpacity(0.4)` | 路線図の線の色 |

---

## 3. ディレクトリ構成

```
lib/
├── main.dart                         … アプリのエントリーポイント
├── const/
│   └── const.dart                    … バイブレーションパターン定数
├── screens/
│   ├── home_screen.dart              … ホーム画面（都道府県マップ）
│   ├── components/
│   │   ├── near_by_tations_display_alert.dart  … 近傍駅マップダイアログ（S-03）
│   │   └── pref_train_station_display_alert.dart … 都道府県別路線・駅一覧ダイアログ（S-02）
│   └── parts/
│       ├── arsta_dialog.dart         … フルスクリーンダイアログ共通ラッパー
│       └── error_dialog.dart         … エラーダイアログ
├── model/
│   ├── pref_train_station_model.dart … PrefStationModel / PrefTrainModel（手書き）
│   ├── station_model.dart            … StationModel（getAllStation API用）
│   └── train_model.dart              … TrainModel（getTrain API用）
├── controllers/
│   ├── controllers_mixin.dart        … Provider参照をまとめたMixin
│   └── pref_train_station/
│       ├── pref_train_station.dart   … アプリ状態のProviderとNotifier（DataRepair使用）
│       ├── pref_train_station.freezed.dart … 自動生成: Freezedクラス
│       └── pref_train_station.g.dart … 自動生成: Riverpod Provider
├── data/
│   └── http/
│       ├── client.dart               … HttpClientクラス、Environment定数
│       └── path.dart                 … APIエンドポイントのEnum定義
├── extensions/
│   └── extensions.dart               … String, BuildContext 等の拡張関数
├── utility/
│   ├── utility.dart                  … Utilityクラス（距離計算・カラーパレット等）
│   ├── functions.dart                … トップレベル関数（geofenceCallback 等）
│   ├── data_repair.dart              … DataRepairクラス（APIデータ補正ロジック）
│   └── shared_preferences_service.dart  … SharedPreferences操作をまとめたユーティリティ
└── assets/
    ├── images/
    │   ├── ic_launcher.png           … アプリアイコン
    │   └── station.jpg               … スプラッシュ画面用画像
    └── json/
        └── japan_pref.json           … 都道府県ポリゴンGeoJSONデータ
```

### 配置ルール

| ディレクトリ | 置くもの | 置かないもの |
|---|---|---|
| `const/` | アプリ全体で共有する定数 | クラス定義、ロジック |
| `screens/` | ページ全体を構成するWidget | 再利用する部品Widget |
| `screens/components/` | フルスクリーンダイアログなどの画面コンポーネント | ページ全体の画面 |
| `screens/parts/` | ダイアログ共通ラッパーなどの小部品 | ページ全体の画面 |
| `model/` | データモデルクラス | UI関連コード、ビジネスロジック |
| `controllers/` | `@riverpod` Provider、API通信ロジック | Widget |
| `data/http/` | HTTPクライアント、APIパス定義 | ビジネスロジック |
| `utility/` | 汎用ユーティリティ（距離計算・補正・SharedPreferences等） | 特定画面専用のロジック |

---

## 4. データモデル定義

### 4.1 PrefStationModel（駅情報）

用途：都道府県内の各駅の情報を保持する。手書きクラス（freezed不使用）。

| フィールド名 | JSON キー | Dart型 | 必須 | 説明 |
|---|---|---|---|---|
| id | id | `String` | Yes | 駅の一意識別子 |
| stationName | station_name | `String` | Yes | 駅名（例: "渋谷"） |
| address | address | `String` | Yes | 駅の住所 |
| lat | lat | `double` | Yes | 緯度（例: 35.6580） |
| lng | lng | `double` | Yes | 経度（例: 139.7016） |
| order | order | `int` | Yes | 路線内の駅順（ソートキー） |

**クラス定義（概要）:**

```dart
class PrefStationModel {
  PrefStationModel({
    required this.id,
    required this.stationName,
    required this.address,
    required this.lat,
    required this.lng,
    required this.order,
  });

  factory PrefStationModel.fromJson(Map<String, dynamic> json) { ... }

  Map<String, dynamic> toJson() { ... }
}
```

> **補足：** `toJson()` / `fromJson()` はSharedPreferencesへの永続化と復元に使用する。

### 4.2 PrefTrainModel（路線情報）

用途：路線情報と、その路線に属する駅のリストを保持する。

| フィールド名 | JSON キー | Dart型 | 必須 | 説明 |
|---|---|---|---|---|
| trainNumber | train_number | `int` | Yes | 路線の識別番号 |
| trainName | train_name | `String` | Yes | 路線名（例: "山手線"） |
| station | station | `List<PrefStationModel>` | Yes | 路線に属する駅のリスト（order順にソート済み） |

### 4.3 StationModel（全国駅情報 - 補正用）

用途：getAllStation APIから取得する全国の駅情報。stationMap補正の参照元として使用。

| フィールド名 | Dart型 | 説明 |
|---|---|---|
| stationName | `String` | 駅名 |
| lineNumber | `String` | 路線番号（trainMapで路線名に変換） |

### 4.4 TrainModel（路線マスタ - 補正用）

用途：getTrain APIから取得する路線番号→路線名の対応表。

| フィールド名 | Dart型 | 説明 |
|---|---|---|
| trainNumber | `String` | 路線番号 |
| trainName | `String` | 路線名 |

### 4.5 PrefTrainStationState（アプリ状態）

用途：取得した路線・駅データと近傍駅リストを保持するfreeezdクラス。

| フィールド名 | Dart型 | 初期値 | 説明 |
|---|---|---|---|
| selectedPrefName | `String` | `''` | 現在データが取得済みの都道府県名 |
| prefTrainList | `List<PrefTrainModel>` | `[]` | 路線リスト（画面表示用） |
| prefTrainMap | `Map<String, PrefTrainModel>` | `{}` | 路線名→路線モデルのマップ（高速検索用） |
| prefStationTokyoTrainModelListMap | `Map<String, List<PrefTrainModel>>` | `{}` | 駅名→所属路線リストのマップ（高速検索用） |
| nearbyStations | `List<PrefStationModel>` | `[]` | GPS圏内の全駅リスト（近傍駅表示用） |

**SharedPreferencesキー（SharedPreferencesService 管理分）:**

| キー名 | 型 | 保存タイミング | 削除タイミング |
|---|---|---|---|
| `'selectedStation'` | `String`（JSON） | 駅タップ時 | 監視停止ボタン（stop）タップ時 |

> **補足：** 選択駅は `PrefStationModel.toJson()` でJSONに変換して保存し、復元時は `PrefStationModel.fromJson()` でパースする。

---

## 5. 状態管理設計（Provider一覧）

### 5.1 Provider一覧

```
┌─────────────────────────────────────────────────────────────────┐
│                          Provider一覧                            │
├────────────────────────┬──────────────────┬─────────────────────┤
│ Provider名              │ 種別             │ 返却型              │
├────────────────────────┼──────────────────┼─────────────────────┤
│ prefTrainStationProvider│ NotifierProvider  │ PrefTrainStationState│
│ httpClientProvider      │ Provider          │ HttpClient          │
└────────────────────────┴──────────────────┴─────────────────────┘
```

### 5.2 prefTrainStationProvider の詳細

```
種別:        NotifierProvider（keepAlive: true）
返却型:      PrefTrainStationState
初期値:      PrefTrainStationState() → 全フィールドが空

操作メソッド:
  fetchPrefTrainStationData({required String prefName}) → PrefTrainStationState
    → 3API（getTrain / getAllStation / getPrefTrainStation）を順次呼び出す
    → DataRepair の3段階補正を適用する
    → 補正済みの PrefTrainStationState を返す

  getPrefTrainStation({required String prefName}) → Future<void>
    → fetchPrefTrainStationData を呼び出し、stateを更新する
    → 都道府県選択→路線一覧ダイアログ表示時に呼び出す

  fetchNearbyStations({required List<String> prefNames}) → Future<void>
    → 複数都道府県の fetchPrefTrainStationData を順次呼び出す
    → 全都道府県の全駅を nearbyStations にまとめて保存する
    → 現在地近傍の都道府県リストが変化したとき自動的に呼び出す

使用箇所:    HomeScreen（nearbyStations取得・距離計算）
            PrefTrainStationDisplayAlert（路線・駅一覧表示）
            NearByStationsDisplayAlert（近傍駅リスト取得）
```

### 5.3 ControllersMixin

```dart
mixin ControllersMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  PrefTrainStationState get prefTrainStationState
    → ref.watch(prefTrainStationProvider)

  PrefTrainStation get prefTrainNotifier
    → ref.read(prefTrainStationProvider.notifier)
}
```

---

## 6. 画面設計

### 6.1 エントリーポイント (main.dart)

```
初期化処理（main()）:
  1. WidgetsFlutterBinding.ensureInitialized()
  2. 画面方向を縦固定（portraitUp）
  3. 画像キャッシュの設定
       - maximumSize = 150
       - maximumSizeBytes = 80MB
  4. ProviderScope でアプリ全体をラップ
  5. AppRoot を起動

AppRoot (StatefulWidget):
  - 再起動機能: restartApp() で _appKey を更新してMyAppを再構築

MyApp (ConsumerStatefulWidget):
  - MaterialApp の設定:
      - テーマ: ThemeData.dark(useMaterial3: false)
      - themeMode: ThemeMode.dark
      - title: 'EKI NI TSUITARA'
      - ホーム画面: HomeScreen（GestureDetectorでキーボードフォーカス解除）
      - デバッグバナー: 非表示
```

### 6.2 ホーム画面 (HomeScreen)

**Widgetの種別:** ConsumerStatefulWidget（with ControllersMixin）

**ローカル状態・コントローラー:**
- `Future<List<PrefecturePolygonData>> _future` — 都道府県ポリゴンデータ（initStateで取得）
- `LayerHitNotifier<String> _hitNotifier` — ポリゴンタップ検知
- `String? _selectedPrefectureName` — 選択中の都道府県名
- `bool _permissionsGranted` — パーミッション付与状態
- `String? _selectedStationName` — 選択中の駅名（SharedPreferencesから復元）
- `LatLng? _selectedStationLatLng` — 選択中の駅座標（距離計算用）
- `Position? _currentPosition` — GPS現在地（10秒ポーリング）
- `Timer? _positionTimer` — GPSポーリング用Timer
- `List<String> _lastNearbyPrefNames` — 前回の近傍都道府県リスト（変化検出用）
- `MapController _mapController` — flutter_mapのカメラ制御

**初期化処理（initState）:**
1. `_loadPrefecturePolygonData()` — assets/json/japan_pref.json をパースして `_future` に格納
2. `_initPlugins()` — 通知初期化・ジオフェンス初期化・パーミッション確認・選択駅復元・ジオフェンス復元
3. `_startPositionStream()` — GPS取得を開始（初回即時 + 10秒Timer）

**`_initPlugins()` の処理詳細:**

```
1. FlutterLocalNotificationsPlugin の初期化
2. NativeGeofenceManager の初期化
3. _checkPermissions() → _permissionsGranted を更新
4. _loadSelectedStation() → SharedPreferences から選択駅を復元
5. _restoreGeofence() → SharedPreferences からジオフェンスを復元・再登録
```

**`_restoreGeofence()` の処理詳細:**

```dart
Future<void> _restoreGeofence() async {
  final String? json = await SharedPreferencesService.loadSelectedStation();
  if (json == null) return;
  final Map<String, dynamic> map = jsonDecode(json);
  final double? lat = (map['lat'] as num?)?.toDouble();
  final double? lng = (map['lng'] as num?)?.toDouble();
  final String? stationName = map['station_name'] as String?;
  // nullチェック後、Geofence を構築して createGeofence() を呼び出す
  // geofenceId: 'station_$stationName'
}
```

**GPS位置取得と近傍都道府県の自動更新:**

```
_fetchCurrentPosition():
  1. Geolocator.getCurrentPosition() で現在地を取得
  2. _findNearbyPrefectures() で30km圏内の都道府県名リストを計算
  3. 前回と都道府県リストが変化した場合のみ:
     prefTrainNotifier.fetchNearbyStations(prefNames: nearby) を呼び出す
  4. _currentPosition を更新してsetState()
```

**距離表示の計算:**

```dart
// 1000m以上: "X.Xkm"、未満: "XXXm"
final double meters = utility.calculateDistance(
  LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
  _selectedStationLatLng!,
);
final String dist = meters >= 1000
    ? '${(meters / 1000).toStringAsFixed(1)}km'
    : '${meters.toStringAsFixed(0)}m';
```

**`_removeAllGeofences()` の処理:**

```dart
Future<void> _removeAllGeofences() async {
  await NativeGeofenceManager.instance.removeAllGeofences();
  if (Platform.isAndroid) await Vibration.cancel();
  await SharedPreferencesService.removeSelectedStation();
  if (mounted) {
    setState(() {
      _selectedStationName = null;
      _selectedStationLatLng = null;
    });
  }
}
```

**都道府県ポリゴンタップ処理:**

```dart
void _handleMapTap() {
  final LayerHitResult<String>? hit = _hitNotifier.value;
  final String? tappedPrefecture = hit?.hitValues.first;
  if (tappedPrefecture == null) return;
  setState(() => _selectedPrefectureName = tappedPrefecture);
}
```

**画面レイアウト（Scaffold body）:**

```
FutureBuilder（都道府県ポリゴンデータ待機）
  ├── 読み込み中: CircularProgressIndicator
  └── 完了後: Column
       ├── SizedBox(height: 16)
       ├── 目的地・距離テキスト（幅80%）
       │     「目的地：(未設定)」or「目的地：〇〇駅（X.Xkm）」
       ├── Divider（ピンク・太線）
       ├── Row: [GPSアイコンボタン][clearボタン]
       ├── flutter_mapコンテナ（高さ50%・角丸12）
       │     - TileLayer（OSM）
       │     - PolygonLayer（白マスク）
       │     - PolygonLayer（都道府県・hitNotifier付き）
       │     - MarkerLayer（選択都道府県名ラベル）
       └── 下部バー（選択都道府県名 + 電車アイコン）
             「都道府県を選択してください」or「選択中: 〇〇県」+ [電車アイコン]
```

### 6.3 都道府県別路線・駅一覧ダイアログ (PrefTrainStationDisplayAlert)

**ファイル:** `lib/screens/components/pref_train_station_display_alert.dart`
**Widgetの種別:** ConsumerStatefulWidget（with ControllersMixin）

**ローカル状態:**
- `List<LatLng> _polylinePoints` — 選択路線のポリライン座標
- `String? _selectedTrainName` — 選択中の路線名（路線図表示用）
- `List<List<LatLng>> _prefPolygons` — 都道府県ポリゴン（地図背景用）
- `bool _isBoundsActive` — 路線全域ズームの ON/OFF
- `PrefStationModel? _selectedStation` — 選択中の駅

**初期化処理（initState）:**
1. `prefTrainNotifier.getPrefTrainStation(prefName: widget.prefName)` — APIデータ取得
2. `_loadPrefPolygons()` — 都道府県ポリゴンを読み込み（地図背景用）
3. `_loadSelectedStation()` — SharedPreferencesから選択駅を復元

**画面レイアウト:**

```
Scaffold（透明背景）
└── SafeArea
    └── Padding(20)
        └── Column
             ├── Row: [都道府県名][SizedBox.shrink]
             ├── Divider
             └── Expanded
                 └── Stack
                      ├── Positioned.fill: PrefectureMapWidget（地図背景）
                      ├── Positioned(top=5): 操作エリア
                      │     「目的地の駅を選択してください。」
                      │     [路線図][路線全域] アイコン説明
                      │     [駅名検索ボタン]  [設定ボタン]
                      │     Divider
                      └── Positioned(top=110): displayPrefTrainList()
                                              路線・駅一覧
```

**「設定」ボタンの処理:**

```dart
onPressed: () async {
  if (station == null) {
    await error_dialog(context, title: '駅が選択されていません', content: '...');
    return;
  }
  await _registerGeofence(station);  // ジオフェンス登録
  Navigator.pop(context);
}
```

**`_registerGeofence()` の処理:**

```dart
final Geofence zone = Geofence(
  id: 'station_${station.stationName}',
  location: Location(latitude: station.lat, longitude: station.lng),
  radiusMeters: 1000,
  triggers: {GeofenceEvent.enter},
  iosSettings: IosGeofenceSettings(initialTrigger: true),
  androidSettings: AndroidGeofenceSettings(
    initialTriggers: {GeofenceEvent.enter},
    expiration: Duration(days: 7),
    loiteringDelay: Duration(minutes: 1),
    notificationResponsiveness: Duration(seconds: 10),
  ),
);
await NativeGeofenceManager.instance.createGeofence(zone, geofenceCallback);
```

**路線一覧の描画（displayPrefTrainList）:**

```
ScrollablePositionedList.builder（itemScrollController付き）
  └── 路線ごとに Stack
       ├── ExpansionTile
       │     title: 路線名
       │     children: 駅ごとに Row
       │       ├── CircleAvatar（選択中=黄色/非選択=黒）
       │       └── 駅名テキスト + 緯度経度（右下）
       └── Positioned(top=15, right=60)
             [路線図アイコン]（路線図表示中のみ） [路線全域アイコン]
```

**路線ポリライン表示の切り替え（路線図アイコン onPressed）:**

```
路線図アイコンをタップ（同じ路線の場合）→ 解除: _selectedTrainName = null, _polylinePoints = []
路線図アイコンをタップ（別の路線の場合）→ 表示: _selectedTrainName = trainName,
                                               _polylinePoints = 全駅LatLngリスト
どちらの場合も _isBoundsActive = false にリセットし、都道府県全体にカメラをリセット
```

**駅名検索BottomSheet（_showSearchBottomSheet）:**

- `showModalBottomSheet` で `_SearchSheet` ウィジェットを表示
- `_SearchSheet` は `TextEditingController` + `_search()` メソッドで部分一致フィルタリング
- 検索結果の `ListTile` タップ時:
  1. `Navigator.pop(context)` でBottomSheetを閉じる
  2. `itemScrollController.scrollTo(index: idx, ...)` で路線位置へスクロール

### 6.4 近傍駅マップダイアログ (NearByStationsDisplayAlert)

**ファイル:** `lib/screens/components/near_by_tations_display_alert.dart`
**Widgetの種別:** ConsumerStatefulWidget（with ControllersMixin）

**ローカル状態:**
- `int _selectedKm` — 選択中の半径（デフォルト: 1）
- `PrefStationModel? _selectedStation` — 選択中の駅

**現在地:**
- `_center` getter: `widget.currentPosition` が非nullなら `LatLng(lat, lng)`、nullなら `LatLng(35.6812, 139.7671)`（東京）

**近傍駅フィルタリング:**

```dart
// prefTrainStationState.nearbyStations から距離を計算してフィルタリング
final List<({PrefStationModel station, double distKm})> filteredStations =
    allStations
      .map((s) => (station: s, distKm: utility.calculateDistance(_center, LatLng(s.lat, s.lng)) / 1000))
      .where((e) => e.distKm <= _selectedKm)
      .toList();
```

**駅タップ処理（_onStationTap）:**

```
同じ駅を再タップ → 選択解除:
  1. NativeGeofenceManager.instance.removeAllGeofences()
  2. SharedPreferencesService.removeSelectedStation()
  3. setState(() => _selectedStation = null)

別の駅をタップ → 選択:
  1. SharedPreferencesService.saveSelectedStation(jsonEncode(station.toJson()))
  2. setState(() => _selectedStation = station)
```

**「設定」ボタン（_onSetGeofence）:**

```
1. NativeGeofenceManager.instance.removeAllGeofences() で既存ジオフェンス削除
2. Geofence を構築して createGeofence() を呼び出す（geofenceId: 'station_${stationName}'）
3. Navigator.of(context).pop() でダイアログを閉じる
```

### 6.5 ジオフェンスコールバック（トップレベル関数）

> **ファイル:** `lib/utility/functions.dart`
> **補足：** Flutterでバックグラウンドから関数を呼び出す場合、トップレベル関数（classの外）として定義する必要がある。

```dart
@pragma('vm:entry-point')
Future<void> geofenceCallback(GeofenceCallbackParams params) async {
  WidgetsFlutterBinding.ensureInitialized();
  try { DartPluginRegistrant.ensureInitialized(); } catch (_) {}

  final FlutterLocalNotificationsPlugin notifications = FlutterLocalNotificationsPlugin();
  await notifications.initialize(settings: ...);

  // 1. 音楽ストリームの音量を最大に上げる（Android のみ）
  if (Platform.isAndroid) {
    try {
      await FlutterVolumeController.updateShowSystemUI(false);
      await FlutterVolumeController.setVolume(1.0);
    } catch (_) {}
  }

  // 2. プッシュ通知を発火
  await notifications.show(
    id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title: '降りる駅アラーム',
    body: stationNames,  // geofenceId (station_〇〇) を連結
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        'geofence', 'Geofence',
        importance: Importance.max,
        priority: Priority.high,
        vibrationPattern: Int64List.fromList(kVibrationPattern),
      ),
      iOS: DarwinNotificationDetails(),
    ),
  );

  // 3. ループバイブレーション開始（Android のみ）
  if (Platform.isAndroid) {
    final bool hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator) {
      await Vibration.vibrate(
        pattern: kVibrationPattern,
        intensities: kVibrationIntensities,
        repeat: 0,
      );
    }
  }
}
```

**バイブレーションパターン（`lib/const/const.dart`）:**

| インデックス | 値(ms) | 強度 (0-255) | 意味 |
|---|---|---|---|
| 0 | 0 | 0 | 開始直後（待機なし） |
| 1 | 600 | 255 | 600ms バイブレーション（最大強度） |
| 2 | 100 | 0 | 100ms 停止 |
| 3 | 600 | 255 | 600ms バイブレーション（最大強度） |
| 4 | 100 | 0 | 100ms 停止 |
| 5 | 600 | 255 | 600ms バイブレーション（最大強度） |
| 6 | 100 | 0 | 100ms 停止 |
| 7 | 1000 | 255 | 1000ms バイブレーション（最大強度） |
| （ループ） | `repeat: 0` | - | index 0 に戻って繰り返す |

### 6.6 SharedPreferencesService

**ファイル:** `lib/utility/shared_preferences_service.dart`

| メソッド名 | 引数 | 戻り値 | 説明 |
|---|---|---|---|
| `saveSelectedStation(String json)` | json | `Future<void>` | 選択駅のJSON文字列を保存する |
| `loadSelectedStation()` | なし | `Future<String?>` | 選択駅のJSON文字列を読み込む |
| `removeSelectedStation()` | なし | `Future<void>` | 選択駅を削除する |

---

## 7. API連携仕様

### 7.1 共通仕様

| 項目 | 値 |
|---|---|
| ベースURL | `http://toyohide.work` |
| ベースパス | `/BrainLog/api/` |
| 通信方式 | HTTP POST |
| データ形式 | JSON（UTF-8） |
| エラー時 | 例外をスローし、呼び出し元でキャッチする |

**HttpClient クラス (`data/http/client.dart`):**

```dart
class Environment {
  static String get apiEndPoint => 'toyohide.work';
  static String get apiBasePath => 'BrainLog/api';
}

class HttpClient {
  Future<dynamic> post({
    required APIPath path,
    Map<String, dynamic>? body,
  }) async {
    final Uri uri = Uri.http(Environment.apiEndPoint,
        '${Environment.apiBasePath}/${path.value}');
    final Response response = await _client.post(uri,
        headers: {'content-type': 'application/json'},
        body: json.encode(body));
    return jsonDecode(utf8.decode(response.bodyBytes));
  }
}
```

### 7.2 エンドポイント詳細

#### POST /BrainLog/api/getTrain

```
目的:       全国路線番号→路線名の対応表の取得
リクエスト:  ボディなし
レスポンス:  {data: [{trainNumber: "101", trainName: "山手線"}, ...]}
使用Provider: prefTrainStationProvider（fetchPrefTrainStationData内）
```

#### POST /BrainLog/api/getAllStation

```
目的:       全国の全駅データの取得（駅順補正の参照元）
リクエスト:  ボディなし
レスポンス:  {data: [{stationName: "東京", lineNumber: "101", ...}, ...]}
使用Provider: prefTrainStationProvider（fetchPrefTrainStationData内）
```

#### POST /BrainLog/api/getPrefTrainStation

```
目的:       指定都道府県の路線・駅データの取得
リクエスト:  {"pref": "東京都"}
レスポンス:  {data: [{train_number, train_name, station:[{id, station_name, address, lat, lng, order}]}, ...]}
使用Provider: prefTrainStationProvider（fetchPrefTrainStationData内）
```

### 7.3 データ補正ロジック（DataRepair）の詳細

`fetchPrefTrainStationData` 内で3段階の補正を適用する:

**補正① stationMap補正:**
- `stationMap`（getAllStationの路線名→駅リスト）に同名路線が存在し、駅名セットが異なる場合に駅順を補正
- 例: JR千歳線、JR宗谷本線、JR釧網本線など

**補正② repairTrainNumber補正:**
- `stationMap` に路線名が存在しない路線（stationMapとの路線名が異なる）に適用
- `DataRepair.getRepairTrainNumber(trainName: ...)` で対応する路線番号リストを取得してマージ
- 例: JR八高線（2路線番号をマージ）、わたらせ渓谷鐵道線など

**補正③ patchMap適用:**
- `DataRepair.getStationDataRepairPrefStationModel()` の手動定義データが存在する路線に適用
- パッチデータの駅リストで完全置換（APIの誤座標・欠落駅・誤順序を修正）
- 例: 京王新線の新宿駅追加、JR宗谷本線の石北本線混入修正など

---

## 8. ジオフェンス仕様

### 8.1 共通設定

| 設定項目 | 値 | 説明 |
|---|---|---|
| geofenceId | `'station_${駅名}'` | 駅名を含む一意のジオフェンス識別子 |
| radiusMeters | `1000.0` | ジオフェンスの半径（メートル） |
| triggers | `{GeofenceEvent.enter}` | 入場イベントのみ（退場イベントは対象外） |
| 同時登録数 | 1件（単一駅のみ） | 停止時は `removeAllGeofences()` で全削除 |

### 8.2 iOS固有設定

| 設定項目 | 値 | 説明 |
|---|---|---|
| initialTrigger | `true` | アプリ起動時にすでにジオフェンス圏内の場合もイベントを発火する |

### 8.3 Android固有設定

| 設定項目 | 値 | 説明 |
|---|---|---|
| expiration | `Duration(days: 7)` | ジオフェンスの有効期限（7日間） |
| loiteringDelay | `Duration(minutes: 1)` | 圏内進入後1分間の滞留でイベントを発火（誤検知防止） |
| notificationResponsiveness | `Duration(seconds: 10)` | OSがジオフェンスイベントをチェックする間隔の目安 |

### 8.4 パーミッション要求フロー

```
[request ボタン をタップ]
        │
        ▼
  位置情報（Fine）を要求
  (Permission.location)
        │
        ├── 拒否 → そのまま終了
        │
        ▼
  位置情報（常に許可）を要求
  (Permission.locationAlways)
        │
        ├── 拒否 → そのまま終了
        │
        ▼
  通知パーミッションを要求
  (Permission.notification)
        │
        ▼
  _checkPermissions() で再確認
  → _permissionsGranted を更新
  → AppBarアイコンが黄色に変わる
```

---

## 9. ビルド手順

### 9.1 前提条件

```
- Flutter SDK: 3.x 以上（Dart 3.x）
- Android Studio または Xcode（実機テスト用）
- インターネット接続（OpenStreetMapタイル取得のため）
```

### 9.2 アセットの確認

以下のファイルが存在することを確認する:

```
assets/json/japan_pref.json    ← 都道府県ポリゴンGeoJSON（必須）
assets/images/ic_launcher.png  ← アプリアイコン
assets/images/station.jpg      ← スプラッシュ画面用画像
```

### 9.3 コード生成

モデル（freezed）やProvider（riverpod_generator）を変更した場合は以下のコマンドでコード生成が必要:

```bash
cd flutter_arrive_at_the_station
flutter pub run build_runner build --delete-conflicting-outputs
```

> **注意:** `dart run` ではなく `flutter pub run` を使うこと。

### 9.4 生成されるファイル

| 元ファイル | 生成ファイル | 内容 |
|---|---|---|
| `controllers/pref_train_station/pref_train_station.dart` | `.freezed.dart`, `.g.dart` | freezed + Riverpod Provider |

### 9.5 実機ビルドと動作確認

```bash
flutter run            # デバッグビルド＆実行
flutter build apk      # APK生成 (Android)
flutter build ipa      # IPA生成 (iOS) ※要Xcodeと証明書
```

**ジオフェンスのテスト方法:**

```
Android Emulator:
  1. エミュレータの [Extended controls] → [Location] を開く
  2. 選択した駅の緯度経度を入力し、[SEND] を押す
  3. ジオフェンス境界（駅座標から1000m離れた地点→1000m以内の地点）を
     Send で変化させてイベントをシミュレートする

実機:
  実際に選択した駅の近くへ移動してテストする
  （エミュレータより信頼性が高い）
```

---

## 改訂履歴

| 版 | 日付 | 内容 |
|---|---|---|
| 1.0 | 2026-03-19 | 初版作成 |
