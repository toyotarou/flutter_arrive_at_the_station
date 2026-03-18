/// バイブレーションパターン（停止するまでループ）
/// [待機ms, 振動ms, 待機ms, 振動ms, ...]
const List<int> kVibrationPattern = <int>[0, 600, 100, 600, 100, 600, 100, 1000];

/// バイブレーション強度（kVibrationPattern に対応）
const List<int> kVibrationIntensities = <int>[0, 255, 0, 255, 0, 255, 0, 255];
