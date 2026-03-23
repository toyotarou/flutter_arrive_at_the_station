# flutter_arrive_at_the_station

駅への到着を自動検知して通知する Flutter アプリです（アプリタイトル: **EKI NI TSUITARA**）。ジオフェンス機能で指定した駅の近くに来るとローカル通知・バイブレーションでお知らせします。全国の路線・駅情報を地図上に表示し、都道府県・路線単位で目標駅を設定できます。

---

## 主な機能

- **ジオフェンス到着検知**: `native_geofence` で指定駅の半径エリアへの入場を検知
- **ローカル通知**: 到着時に `flutter_local_notifications` でプッシュ通知
- **バイブレーション**: 到着時に端末を振動（`vibration`）
- **音量制御**: 通知音量を `flutter_volume_controller` で管理
- **地図表示**: `flutter_map` (OpenStreetMap) で駅位置・ジオフェンスエリアを地図表示
- **近隣駅表示**: 現在地周辺の駅一覧をダイアログで確認
- **都道府県別路線・駅検索**: 都道府県 → 路線 → 駅の階層で目標駅を選択
- **路線内駅順ソート**: `order` フィールドで路線内の駅を正しい順序で表示
- **設定保存**: `shared_preferences` でジオフェンス設定を永続化
- **環境変数管理**: `flutter_dotenv` で API エンドポイントを管理
- **アプリ再起動**: UniqueKey 切り替えによる状態リセット機能

---

## 使用技術

| カテゴリ | ライブラリ |
|---|---|
| UI フレームワーク | Flutter (Material 3 off / ダークテーマ) |
| 状態管理 | hooks_riverpod / flutter_riverpod / riverpod_annotation |
| HTTP 通信 | http |
| 国際化 | intl |
| コード生成 | freezed / freezed_annotation / json_serializable |
| 地図 | flutter_map / latlong2 (OpenStreetMap) |
| グラフ | fl_chart |
| ジオフェンス | native_geofence |
| 位置情報 (GPS) | geolocator |
| ローカル通知 | flutter_local_notifications |
| 権限管理 | permission_handler |
| バイブレーション | vibration |
| 音量制御 | flutter_volume_controller |
| 設定保存 | shared_preferences |
| 画像キャッシュ | cached_network_image / flutter_cache_manager |
| スクロール制御 | scroll_to_index / scrollable_positioned_list |
| カルーセル | flutter_carousel_slider |
| 環境変数 | flutter_dotenv |
| アイコン | font_awesome_flutter |
| スプラッシュ | flutter_native_splash |
| ランチャーアイコン | flutter_launcher_icons |
| Linter | flutter_lints / custom_lint / riverpod_lint |

---

## データモデル

### `StationModel`
全国の駅情報（HTTP API 取得）を保持します。

| フィールド | 型 | 説明 |
|---|---|---|
| id | int | 駅 ID |
| stationName | String | 駅名 |
| address | String | 住所 |
| lat | String | 緯度 |
| lng | String | 経度 |
| prefecture | String | 都道府県 |
| lineNumber | String | 路線番号 |
| lineName | String | 路線名 |

### `PrefStationModel`
都道府県別路線データ内の駅情報を保持します。

| フィールド | 型 | 説明 |
|---|---|---|
| id | String | 駅 ID |
| stationName | String | 駅名 |
| address | String | 住所 |
| lat | double | 緯度 |
| lng | double | 経度 |
| order | int | 路線内の駅順序 |

### `PrefTrainModel`
都道府県内の路線情報（駅リスト付き）を保持します。

| フィールド | 型 | 説明 |
|---|---|---|
| trainNumber | int | 路線番号 |
| trainName | String | 路線名 |
| station | List\<PrefStationModel\> | 駅一覧（order 順にソート済み） |

### `TrainModel`
路線の基本情報を保持します。

---

## 画面構成

```
HomeScreen（ホーム画面）
│  ※ 地図・ジオフェンス設定・現在地表示
├── components/
│   ├── near_by_tations_display_alert.dart        近隣駅一覧ダイアログ
│   └── pref_train_station_display_alert.dart     都道府県別路線・駅選択ダイアログ
└── parts/                                        共通パーツ
```

---

## コントローラー（Riverpod）

| ディレクトリ / ファイル | 役割 |
|---|---|
| controllers/pref_train_station/ | 都道府県別路線・駅データの取得・管理 |
| controllers/controllers_mixin.dart | コントローラーをまとめる Mixin |

---

## ディレクトリ構成

```
lib/
├── const/              定数定義
├── controllers/        Riverpod コントローラー
├── data/               データ定数・初期値
├── extensions/         拡張メソッド
├── model/              データモデル（Station / PrefStation / Train）
├── screens/            UI 画面・コンポーネント
├── utility/            ユーティリティ関数
└── main.dart           エントリーポイント

assets/
└── json/               路線・駅データ JSON ファイル

documents/              設計ドキュメント
```

---

## 必要な権限

| 権限 | 用途 |
|---|---|
| 位置情報（常時） | ジオフェンス・GPS 取得 |
| 通知 | 到着通知の表示 |
| バックグラウンド位置情報 | アプリ非起動時のジオフェンス検知 |

---

## セットアップ

```bash
# 依存パッケージのインストール
flutter pub get

# コード生成（Freezed / Riverpod）
dart run build_runner build --delete-conflicting-outputs

# 環境変数ファイルの作成
cp .env.example .env
# .env に API エンドポイント等を設定

# アプリ起動
flutter run
```

---

## 動作環境

- Flutter: 3.x 以上
- Dart SDK: ^3.10.8
- iOS / Android 対応（縦向き固定）
- バックグラウンドの位置情報権限が必要
