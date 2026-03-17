import 'package:flutter/material.dart';

class Utility {
  ///
  List<Color> getFortyEightColor() {
    return <Color>[
      const Color(0xFFE53935), // 赤
      const Color(0xFF1E88E5), // 青
      const Color(0xFF43A047), // 緑
      const Color(0xFF8E24AA), // 紫
      const Color(0xFFFFA726), // オレンジ
      const Color(0xFF00ACC1), // シアン
      const Color(0xFFFDD835), // 黄
      const Color(0xFF6D4C41), // 茶
      const Color(0xFFD81B60), // ピンク
      const Color(0xFF3949AB), // インディゴ
      const Color(0xFF00897B), // ティール
      const Color(0xFF7CB342), // ライムグリーン
      const Color(0xFF5E35B1), // ディープパープル
      const Color(0xFFFB8C00), // 濃いオレンジ
      const Color(0xFF00838F), // 濃いシアン
      const Color(0xFFF4511E), // 赤橙
      const Color(0xFF558B2F), // 濃い黄緑
      const Color(0xFF6A1B9A), // 濃い紫
      const Color(0xFF2E7D32), // ダークグリーン
      const Color(0xFF283593), // ダークブルー
      const Color(0xFFAD1457), // ダークピンク
      const Color(0xFF4E342E), // ダークブラウン
      const Color(0xFF1565C0), // 濃い青
      const Color(0xFF9E9D24), // オリーブ
      const Color(0xCC42A5F5), // 明るい青 (80%)
      const Color(0xCC66BB6A), // 明るい緑 (80%)
      const Color(0xCCAB47BC), // 明るい紫 (80%)
      const Color(0xCCFFB74D), // 明るいオレンジ (80%)
      const Color(0xCC26C6DA), // 明るいシアン (80%)
      const Color(0xCCFFF176), // 明るい黄 (80%)
      const Color(0xCC8D6E63), // 明るい茶 (80%)
      const Color(0xCCF06292), // 明るいピンク (80%)
      const Color(0xCC5C6BC0), // 明るいインディゴ (80%)
      const Color(0xCC26A69A), // 明るいティール (80%)
      const Color(0xCC9CCC65), // 明るいライム (80%)
      const Color(0xCC9575CD), // 明るいパープル (80%)
      const Color(0x99FFCC80), // 淡いオレンジ (60%)
      const Color(0x9980DEEA), // 淡いシアン (60%)
      const Color(0x99FFAB91), // サーモン (60%)
      const Color(0x99C5E1A5), // 淡い緑 (60%)
      const Color(0x99B39DDB), // 淡い紫 (60%)
      const Color(0x99A5D6A7), // ミントグリーン (60%)
      const Color(0x999FA8DA), // 淡い青 (60%)
      const Color(0x99F48FB1), // 淡いピンク (60%)
      const Color(0x99BCAAA4), // 淡いブラウン (60%)
      const Color(0xCCEF5350), // 明るい赤 (80%)
      const Color(0xFFBDBDBD), // グレー
      const Color(0xFFE0E0E0), // ライトグレー
    ];
  }

  ///
  void showError(String msg) {
    ScaffoldMessenger.of(
      NavigationService.navigatorKey.currentContext!,
    ).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 5)));
  }

  ///
  List<String> getRepairTrainNumber({required String trainName}) {
    final Map<String, List<String>> map = <String, List<String>>{
      'JR八高線': <String>['11317', '11318'],
      'わたらせ渓谷鐵道線': <String>['99312'],
      '上信電鉄上信線': <String>['99327'],
    };

    return map[trainName] ?? <String>[];

    //上毛電鉄
    //上越新幹線
    //北陸新幹線
  }
}

class NavigationService {
  const NavigationService._();

  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
}
