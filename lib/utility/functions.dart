import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:native_geofence/native_geofence.dart';
import 'package:vibration/vibration.dart';

import '../const/const.dart';
import 'shared_preferences_service.dart';

/// =======================
/// Geofence コールバック（トップレベル必須）
/// =======================
@pragma('vm:entry-point')
Future<void> geofenceCallback(GeofenceCallbackParams params) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    DartPluginRegistrant.ensureInitialized();
  } catch (_) {}

  final FlutterLocalNotificationsPlugin notifications = FlutterLocalNotificationsPlugin();

  const InitializationSettings initSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(),
  );

  await notifications.initialize(settings: initSettings);

  // 音量を最大に上げる（Android のみ・音楽ストリーム）
  if (Platform.isAndroid) {
    try {
      await FlutterVolumeController.updateShowSystemUI(false);
      await FlutterVolumeController.setVolume(1.0);
    } catch (_) {}
  }

  final String stationNames = params.geofences.map((ActiveGeofence g) => g.id).join(', ');

  final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'geofence',
    'Geofence',
    channelDescription: 'Notify when entering the selected station area',
    importance: Importance.max,
    priority: Priority.high,
    vibrationPattern: Int64List.fromList(kVibrationPattern),
  );

  const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

  final NotificationDetails details = NotificationDetails(android: androidDetails, iOS: iosDetails);

  await notifications.show(
    id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title: '降りる駅アラーム',
    body: stationNames,
    notificationDetails: details,
  );

  // ループバイブレーション開始（Android のみ）
  if (Platform.isAndroid) {
    final bool hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator) {
      await Vibration.vibrate(pattern: kVibrationPattern, intensities: kVibrationIntensities, repeat: 0);
    }
  }

  // アラートフラグを SharedPreferences に保存する（バックグラウンド起動後の復元用）
  await SharedPreferencesService.saveGeofencePendingAlert();

  // アプリが前面にある場合、UI isolate へ直接通知してダイアログを表示させる
  final SendPort? uiPort = IsolateNameServer.lookupPortByName('geofence_alert_port');
  uiPort?.send(null);
}
