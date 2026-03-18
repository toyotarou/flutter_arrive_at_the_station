import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences への読み書きをまとめたユーティリティクラス
class SharedPreferencesService {
  SharedPreferencesService._();

  // ─── selectedStation ─────────────────────────────────

  static const String _kSelectedStation = 'selectedStation';

  /// 選択駅の JSON 文字列を保存する
  static Future<void> saveSelectedStation(String json) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSelectedStation, json);
  }

  /// 選択駅の JSON 文字列を読み込む
  static Future<String?> loadSelectedStation() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kSelectedStation);
  }

  /// 選択駅を削除する
  static Future<void> removeSelectedStation() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSelectedStation);
  }
}
