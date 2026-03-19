import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:native_geofence/native_geofence.dart';

import '../../controllers/controllers_mixin.dart';
import '../../model/pref_train_station_model.dart';
import '../../utility/functions.dart';
import '../../utility/shared_preferences_service.dart';
import '../../utility/utility.dart';

////////////////////////////////////////////////////////////////////////

class NearByStationsDisplayAlert extends ConsumerStatefulWidget {
  const NearByStationsDisplayAlert({super.key, this.currentPosition});

  final Position? currentPosition;

  @override
  ConsumerState<NearByStationsDisplayAlert> createState() => _NearByStationsDisplayAlertState();
}

class _NearByStationsDisplayAlertState extends ConsumerState<NearByStationsDisplayAlert>
    with ControllersMixin<NearByStationsDisplayAlert> {
  final MapController _mapController = MapController();
  final Utility _utility = Utility();

  int _selectedKm = 1;
  PrefStationModel? _selectedStation;

  LatLng get _center {
    if (widget.currentPosition != null) {
      return LatLng(widget.currentPosition!.latitude, widget.currentPosition!.longitude);
    }
    return const LatLng(35.6812, 139.7671);
  }

  ///
  LatLngBounds _boundsForKm(int km) {
    final double deltaLat = km / 111.0;
    final double deltaLng = km / (111.0 * cos(_center.latitude * pi / 180));
    return LatLngBounds(
      LatLng(_center.latitude - deltaLat, _center.longitude - deltaLng),
      LatLng(_center.latitude + deltaLat, _center.longitude + deltaLng),
    );
  }

  ///
  void _changeRadius(int km) {
    setState(() => _selectedKm = km);
    _mapController.fitCamera(CameraFit.bounds(bounds: _boundsForKm(km), padding: const EdgeInsets.all(24)));
  }

  /// 駅タップ：選択 or 解除
  Future<void> _onStationTap(PrefStationModel station) async {
    if (_selectedStation?.id == station.id) {
      // 再タップ → 解除
      await NativeGeofenceManager.instance.removeAllGeofences();
      await SharedPreferencesService.removeSelectedStation();
      setState(() => _selectedStation = null);
    } else {
      // 新規選択
      await SharedPreferencesService.saveSelectedStation(jsonEncode(station.toJson()));
      setState(() => _selectedStation = station);
    }
  }

  /// TTT：ジオフェンス登録して画面を閉じる
  Future<void> _onSetGeofence() async {
    final PrefStationModel? station = _selectedStation;
    if (station == null) {
      return;
    }

    await NativeGeofenceManager.instance.removeAllGeofences();

    final Geofence zone = Geofence(
      id: 'station_${station.stationName}',
      location: Location(latitude: station.lat, longitude: station.lng),
      radiusMeters: 1000,
      triggers: <GeofenceEvent>{GeofenceEvent.enter},
      iosSettings: const IosGeofenceSettings(initialTrigger: true),
      androidSettings: const AndroidGeofenceSettings(
        initialTriggers: <GeofenceEvent>{GeofenceEvent.enter},
        expiration: Duration(days: 7),
        loiteringDelay: Duration(minutes: 1),
        notificationResponsiveness: Duration(seconds: 10),
      ),
    );

    try {
      await NativeGeofenceManager.instance.createGeofence(zone, geofenceCallback);
    } catch (_) {}

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  ///
  @override
  Widget build(BuildContext context) {
    final List<PrefStationModel> allStations = prefTrainStationState.nearbyStations;

    final List<({PrefStationModel station, double distKm})> filteredStations = allStations
        .map((PrefStationModel s) {
          final double distKm = _utility.calculateDistance(_center, LatLng(s.lat, s.lng)) / 1000;
          return (station: s, distKm: distKm);
        })
        .where((({double distKm, PrefStationModel station}) e) => e.distKm <= _selectedKm)
        .toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: DefaultTextStyle(
          style: const TextStyle(color: Colors.white),
          child: Stack(
            children: <Widget>[
              // 地図（全面）
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCameraFit: CameraFit.bounds(bounds: _boundsForKm(1), padding: const EdgeInsets.all(24)),
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.drag | InteractiveFlag.pinchZoom,
                      ),
                    ),
                    children: <Widget>[
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.flutter_arrive_at_the_station',
                      ),

                      // 範囲円
                      // ignore: always_specify_types
                      CircleLayer(
                        // ignore: always_specify_types
                        circles: <CircleMarker>[
                          // ignore: always_specify_types
                          CircleMarker(
                            point: _center,
                            radius: _selectedKm * 1000.0,
                            useRadiusInMeter: true,
                            color: Colors.blue.withValues(alpha: 0.15),
                            borderColor: Colors.blue,
                            borderStrokeWidth: 2,
                          ),
                        ],
                      ),

                      // マーカー（現在地 + 圏内の駅）
                      MarkerLayer(
                        markers: <Marker>[
                          // 現在地
                          Marker(
                            point: _center,
                            width: 20,
                            height: 20,
                            child: Container(
                              decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                            ),
                          ),
                          // 駅
                          ...filteredStations.map((({double distKm, PrefStationModel station}) e) {
                            final bool isSelected = _selectedStation?.id == e.station.id;
                            final Color plateColor = isSelected
                                ? Colors.redAccent.withValues(alpha: 0.9)
                                : Colors.blueAccent.withValues(alpha: 0.85);

                            return Marker(
                              point: LatLng(e.station.lat, e.station.lng),
                              width: 80,
                              height: 44,
                              alignment: Alignment.bottomCenter,
                              child: GestureDetector(
                                onTap: () => _onStationTap(e.station),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: plateColor,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: <Widget>[
                                          Text(
                                            e.station.stationName,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            '${e.distKm.toStringAsFixed(1)}Km',
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // ピン先
                                    Container(
                                      width: 4,
                                      height: 4,
                                      decoration: BoxDecoration(color: plateColor, shape: BoxShape.circle),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // km 選択ボタン（地図の上に重ねる）
              Positioned(
                bottom: 70,
                left: 20,
                right: 20,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <int>[1, 3, 5, 10, 20].map((int km) {
                    final bool isSelected = _selectedKm == km;
                    return GestureDetector(
                      onTap: () => _changeRadius(km),
                      child: CircleAvatar(
                        radius: 28,
                        backgroundColor: isSelected
                            ? Colors.yellowAccent.withValues(alpha: 0.9)
                            : Colors.black.withValues(alpha: 0.5),
                        child: Text(
                          '${km}Km',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.black : Colors.white,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // 設定ボタン
              Positioned(
                bottom: 5,
                left: 20,
                right: 20,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    const SizedBox.shrink(),

                    ElevatedButton.icon(
                      onPressed: _selectedStation != null ? _onSetGeofence : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedStation != null
                            ? Colors.yellowAccent.withValues(alpha: 0.8)
                            : Colors.grey.withValues(alpha: 0.4),
                      ),
                      icon: const Icon(Icons.location_on, size: 18),
                      label: const Text('設定', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
