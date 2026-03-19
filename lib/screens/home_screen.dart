import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:native_geofence/native_geofence.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vibration/vibration.dart';

import '../controllers/controllers_mixin.dart';
import '../extensions/extensions.dart';
import '../utility/functions.dart';
import '../utility/shared_preferences_service.dart';
import '../utility/utility.dart';
import 'components/near_by_tations_display_alert.dart';
import 'components/pref_train_station_display_alert.dart';
import 'parts/arsta_dialog.dart';

////////////////////////////////////////////////////////////////////////

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with ControllersMixin<HomeScreen> {
  late final Future<List<PrefecturePolygonData>> _future;

  // ignore: always_specify_types
  final LayerHitNotifier<String> _hitNotifier = ValueNotifier(null);

  String? _selectedPrefectureName;

  bool _permissionsGranted = false;

  String? _selectedStationName;
  LatLng? _selectedStationLatLng;

  Position? _currentPosition;
  Timer? _positionTimer;
  List<String> _lastNearbyPrefNames = <String>[];

  final MapController _mapController = MapController();

  Utility utility = Utility();

  ///
  @override
  void initState() {
    super.initState();
    _future = _loadPrefecturePolygonData();
    _initPlugins();
    _startPositionStream();
  }

  ///
  Future<void> _initPlugins() async {
    const InitializationSettings initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await FlutterLocalNotificationsPlugin().initialize(settings: initSettings);

    await NativeGeofenceManager.instance.initialize();

    await _checkPermissions();
    await _loadSelectedStation();
    await _restoreGeofence();
  }

  ///
  Future<void> _restoreGeofence() async {
    final String? json = await SharedPreferencesService.loadSelectedStation();
    if (json == null) {
      return;
    }
    try {
      final Map<String, dynamic> map = jsonDecode(json) as Map<String, dynamic>;
      final double? lat = (map['lat'] as num?)?.toDouble();
      final double? lng = (map['lng'] as num?)?.toDouble();
      final String? stationName = map['station_name'] as String?;
      if (lat == null || lng == null || stationName == null) {
        return;
      }
      final Geofence zone = Geofence(
        id: 'station_$stationName',
        location: Location(latitude: lat, longitude: lng),
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
      await NativeGeofenceManager.instance.createGeofence(zone, geofenceCallback);
    } catch (_) {}
  }

  ///
  @override
  void dispose() {
    _positionTimer?.cancel();
    _hitNotifier.dispose();
    super.dispose();
  }

  ///
  Future<List<PrefecturePolygonData>> _loadPrefecturePolygonData() async {
    final String jsonString = await rootBundle.loadString('assets/json/japan_pref.json');

    final Map<String, dynamic> jsonMap = json.decode(jsonString) as Map<String, dynamic>;

    final List<dynamic> features = jsonMap['features'] as List<dynamic>? ?? <dynamic>[];

    final Map<String, List<_PolygonParts>> prefecturePolygonMap = <String, List<_PolygonParts>>{};

    for (final dynamic feature in features) {
      if (feature is! Map<String, dynamic>) {
        continue;
      }

      final Map<String, dynamic> properties = feature['properties'] as Map<String, dynamic>? ?? <String, dynamic>{};

      final String prefectureName = (properties['N03_001']?.toString() ?? '').trim();

      if (prefectureName.isEmpty) {
        continue;
      }

      final Map<String, dynamic> geometry = feature['geometry'] as Map<String, dynamic>? ?? <String, dynamic>{};

      final String geometryType = geometry['type']?.toString() ?? '';
      final dynamic coordinates = geometry['coordinates'];

      if (coordinates == null) {
        continue;
      }

      prefecturePolygonMap.putIfAbsent(prefectureName, () => <_PolygonParts>[]);

      if (geometryType == 'Polygon') {
        final List<dynamic> polygonCoordinates = coordinates as List<dynamic>;
        final _PolygonParts parts = _buildPolygonParts(polygonCoordinates);

        prefecturePolygonMap[prefectureName]!.add(parts);
      } else if (geometryType == 'MultiPolygon') {
        final List<dynamic> multiPolygonCoordinates = coordinates as List<dynamic>;

        for (final dynamic polygonCoordinates in multiPolygonCoordinates) {
          final List<dynamic> polygonList = polygonCoordinates as List<dynamic>;
          final _PolygonParts parts = _buildPolygonParts(polygonList);

          prefecturePolygonMap[prefectureName]!.add(parts);
        }
      }
    }

    final List<PrefecturePolygonData> result = <PrefecturePolygonData>[];

    for (final MapEntry<String, List<_PolygonParts>> entry in prefecturePolygonMap.entries) {
      result.add(PrefecturePolygonData(name: entry.key, polygonParts: entry.value));
    }

    return result;
  }

  ///
  _PolygonParts _buildPolygonParts(List<dynamic> polygonCoordinates) {
    final List<LatLng> outerPoints = _toLatLngList(polygonCoordinates.first as List<dynamic>);

    final List<List<LatLng>> holePointsList = <List<LatLng>>[];

    if (polygonCoordinates.length >= 2) {
      for (int i = 1; i < polygonCoordinates.length; i++) {
        final List<dynamic> holeCoordinates = polygonCoordinates[i] as List<dynamic>;
        holePointsList.add(_toLatLngList(holeCoordinates));
      }
    }

    return _PolygonParts(outerPoints: outerPoints, holePointsList: holePointsList);
  }

  ///
  List<LatLng> _toLatLngList(List<dynamic> ringCoordinates) {
    final List<LatLng> points = <LatLng>[];

    for (final dynamic pointCoordinates in ringCoordinates) {
      final List<dynamic> point = pointCoordinates as List<dynamic>;
      final double lon = (point[0] as num).toDouble();
      final double lat = (point[1] as num).toDouble();
      points.add(LatLng(lat, lon));
    }

    return points;
  }

  ///
  Polygon<String> _buildJapanMaskPolygon(List<PrefecturePolygonData> polygonDataList) {
    final List<LatLng> outerMask = <LatLng>[
      const LatLng(60.0, 110.0),
      const LatLng(60.0, 160.0),
      const LatLng(10.0, 160.0),
      const LatLng(10.0, 110.0),
    ];

    final List<List<LatLng>> holePointsList = <List<LatLng>>[];

    for (final PrefecturePolygonData data in polygonDataList) {
      for (final _PolygonParts part in data.polygonParts) {
        holePointsList.add(part.outerPoints);
      }
    }

    return Polygon<String>(points: outerMask, holePointsList: holePointsList, color: Colors.white);
  }

  ///
  Future<void> _checkPermissions() async {
    final PermissionStatus location = await Permission.location.status;
    final PermissionStatus locationAlways = await Permission.locationAlways.status;
    final PermissionStatus notification = await Permission.notification.status;

    final bool granted = location.isGranted && locationAlways.isGranted && notification.isGranted;

    if (mounted) {
      setState(() {
        _permissionsGranted = granted;
      });
    }
  }

  ///
  Future<void> _requestPermissions() async {
    await Permission.location.request();

    await Permission.locationAlways.request();

    await Permission.notification.request();

    await _checkPermissions();
  }

  ///
  Future<void> _startPositionStream() async {
    await _fetchCurrentPosition();
    _positionTimer = Timer.periodic(const Duration(seconds: 10), (_) => _fetchCurrentPosition());
  }

  // 半径何キロ圏内を検索するか（変更可能）
  static const double _nearbyRadiusKm = 30.0;

  ///
  Future<void> _fetchCurrentPosition() async {
    try {
      final Position position = await Geolocator.getCurrentPosition();

      final List<PrefecturePolygonData> polygonDataList = await _future;
      final List<String> nearby = _findNearbyPrefectures(
        LatLng(position.latitude, position.longitude),
        polygonDataList,
      );

      // 前回と県リストが変わった時だけ駅データを再取得する
      final List<String> sorted = List<String>.from(nearby)..sort();
      final List<String> lastSorted = List<String>.from(_lastNearbyPrefNames)..sort();
      if (sorted.join(',') != lastSorted.join(',')) {
        _lastNearbyPrefNames = nearby;

        prefTrainNotifier.fetchNearbyStations(prefNames: nearby);
      }

      if (mounted) {
        setState(() => _currentPosition = position);
      }
    } catch (_) {}
  }

  ///
  List<String> _findNearbyPrefectures(LatLng current, List<PrefecturePolygonData> dataList) {
    final List<String> result = <String>[];

    for (final PrefecturePolygonData data in dataList) {
      bool isNearby = false;

      for (final _PolygonParts part in data.polygonParts) {
        // 現在地がポリゴン内にあれば距離0（確実に含む）
        if (_pointInPolygon(current, part.outerPoints)) {
          isNearby = true;
          break;
        }
        // 境界頂点が半径以内にあるか
        for (final LatLng point in part.outerPoints) {
          if (utility.calculateDistance(current, point) / 1000 <= _nearbyRadiusKm) {
            isNearby = true;
            break;
          }
        }
        if (isNearby) {
          break;
        }
      }

      if (isNearby) {
        result.add(data.name);
      }
    }

    return result;
  }

  ///
  bool _pointInPolygon(LatLng point, List<LatLng> polygon) {
    if (polygon.length < 3) {
      return false;
    }
    bool inside = false;
    int j = polygon.length - 1;
    for (int i = 0; i < polygon.length; i++) {
      final double xi = polygon[i].longitude;
      final double yi = polygon[i].latitude;
      final double xj = polygon[j].longitude;
      final double yj = polygon[j].latitude;
      final bool intersect =
          ((yi > point.latitude) != (yj > point.latitude)) &&
          (point.longitude < (xj - xi) * (point.latitude - yi) / (yj - yi) + xi);
      if (intersect) {
        inside = !inside;
      }
      j = i;
    }
    return inside;
  }

  ///
  Future<void> _loadSelectedStation() async {
    final String? json = await SharedPreferencesService.loadSelectedStation();
    if (mounted) {
      if (json != null) {
        try {
          final Map<String, dynamic> map = jsonDecode(json) as Map<String, dynamic>;
          final double? lat = (map['lat'] as num?)?.toDouble();
          final double? lng = (map['lng'] as num?)?.toDouble();
          setState(() {
            _selectedStationName = map['station_name'] as String?;
            _selectedStationLatLng = (lat != null && lng != null) ? LatLng(lat, lng) : null;
          });
        } catch (_) {}
      } else {
        setState(() {
          _selectedStationName = null;
          _selectedStationLatLng = null;
        });
      }
    }
  }

  ///
  Future<void> _removeAllGeofences() async {
    await NativeGeofenceManager.instance.removeAllGeofences();
    if (Platform.isAndroid) {
      await Vibration.cancel();
    }
    await SharedPreferencesService.removeSelectedStation();
    if (mounted) {
      setState(() {
        _selectedStationName = null;
        _selectedStationLatLng = null;
      });
    }
  }

  ///
  void _handleMapTap() {
    final LayerHitResult<String>? hit = _hitNotifier.value;
    final String? tappedPrefecture = (hit == null || hit.hitValues.isEmpty) ? null : hit.hitValues.first;

    if (tappedPrefecture == null) {
      return;
    }

    setState(() => _selectedPrefectureName = tappedPrefecture);
  }

  ///
  @override
  Widget build(BuildContext context) {
    final List<Color> fortyEightColor = utility.getFortyEightColor();

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('あの駅に着いたら'),

            Text('Wake me up at my stop!', style: TextStyle(fontSize: 10)),
          ],
        ),

        actions: <Widget>[
          GestureDetector(
            onTap: () => _requestPermissions(),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(Icons.security, color: _permissionsGranted ? Colors.yellowAccent : Colors.white),
                const SizedBox(height: 5),
                Text(
                  'request',
                  style: TextStyle(fontSize: 10, color: _permissionsGranted ? Colors.yellowAccent : Colors.white),
                ),
              ],
            ),
          ),

          const SizedBox(width: 20),

          GestureDetector(
            onTap: () async {},
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(Icons.remove_red_eye, color: (_selectedStationName != null) ? Colors.yellowAccent : Colors.white),
                const SizedBox(height: 5),
                Text(
                  'watching',
                  style: TextStyle(
                    fontSize: 10,
                    color: (_selectedStationName != null) ? Colors.yellowAccent : Colors.white,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 20),

          GestureDetector(
            onTap: () async {
              // appParamNotifier.setIsSetStation(flag: false);
              await _removeAllGeofences();
            },
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(Icons.close),
                SizedBox(height: 5),
                Text('stop', style: TextStyle(fontSize: 10)),
              ],
            ),
          ),

          const SizedBox(width: 20),
        ],
      ),
      body: FutureBuilder<List<PrefecturePolygonData>>(
        future: _future,
        builder: (BuildContext context, AsyncSnapshot<List<PrefecturePolygonData>> snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(padding: const EdgeInsets.all(16), child: Text('読み込みエラー: ${snapshot.error}')),
            );
          }

          final List<PrefecturePolygonData> polygonDataList = snapshot.data ?? <PrefecturePolygonData>[];

          if (polygonDataList.isEmpty) {
            return const Center(child: Text('都道府県データがありません'));
          }

          final Polygon<String> japanMaskPolygon = _buildJapanMaskPolygon(polygonDataList);

          final List<Polygon<String>> polygons = <Polygon<String>>[];

          for (int i = 0; i < polygonDataList.length; i++) {
            final PrefecturePolygonData data = polygonDataList[i];
            final bool isSelected = data.name == _selectedPrefectureName;
            final Color baseColor = fortyEightColor[i % fortyEightColor.length];

            for (final _PolygonParts part in data.polygonParts) {
              polygons.add(
                Polygon<String>(
                  points: part.outerPoints,
                  holePointsList: part.holePointsList.isEmpty ? null : part.holePointsList,
                  color: isSelected ? Colors.white.withOpacity(0.85) : baseColor.withOpacity(0.50),
                  borderColor: isSelected ? Colors.black : baseColor,
                  borderStrokeWidth: isSelected ? 3.0 : 1.0,
                  hitValue: data.name,
                ),
              );
            }
          }

          final PrefecturePolygonData? selectedPrefecture = _selectedPrefectureName == null
              ? null
              : polygonDataList.where((PrefecturePolygonData e) => e.name == _selectedPrefectureName).firstOrNull;

          final List<Marker> selectedLabelMarkers = <Marker>[
            if (selectedPrefecture != null)
              Marker(
                point: selectedPrefecture.labelPoint,
                width: 120,
                height: 36,
                child: IgnorePointer(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(),
                      ),
                      child: Text(
                        selectedPrefecture.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ),
          ];

          return Column(
            children: <Widget>[
              const SizedBox(height: 16),

              Center(
                child: SizedBox(
                  width: context.screenSize.width * 0.8,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        () {
                          if (_selectedStationName == null) {
                            return '目的地：(未設定)';
                          }
                          if (_currentPosition != null && _selectedStationLatLng != null) {
                            final double meters = utility.calculateDistance(
                              LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                              _selectedStationLatLng!,
                            );
                            final String dist = meters >= 1000
                                ? '${(meters / 1000).toStringAsFixed(1)}km'
                                : '${meters.toStringAsFixed(0)}m';
                            return '目的地：$_selectedStationName（$dist）';
                          }
                          return '目的地：$_selectedStationName';
                        }(),
                        style: TextStyle(
                          fontSize: 14,
                          color: (_selectedStationName != null) ? Colors.yellowAccent : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox.shrink(),
                    ],
                  ),
                ),
              ),

              Divider(color: Colors.white.withValues(alpha: 0.5), thickness: 5, indent: 40, endIndent: 40),

              Center(
                child: SizedBox(
                  width: context.screenSize.width * 0.8,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      IconButton(
                        onPressed: () {
                          ArstaDialog(
                            context: context,
                            widget: NearByStationsDisplayAlert(currentPosition: _currentPosition),
                          ).then((_) async {
                            await _loadSelectedStation();
                          });
                        },
                        icon: const Icon(Icons.gps_fixed),
                      ),

                      ElevatedButton(
                        onPressed: () {
                          setState(() => _selectedPrefectureName = null);
                          _mapController.move(const LatLng(36.5, 137.8), 5.2);
                        },

                        style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent.withValues(alpha: 0.2)),

                        child: const Text('clear'),
                      ),
                    ],
                  ),
                ),
              ),

              Center(
                child: Container(
                  width: context.screenSize.width * 0.8,
                  height: context.screenSize.height * 0.5,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: const LatLng(36.5, 137.8),
                      initialZoom: 5.2,
                      minZoom: 5,
                      maxZoom: 8,
                      interactionOptions: const InteractionOptions(
                        flags:
                            InteractiveFlag.drag |
                            InteractiveFlag.pinchZoom |
                            InteractiveFlag.doubleTapZoom |
                            InteractiveFlag.flingAnimation,
                      ),
                      cameraConstraint: CameraConstraint.contain(
                        bounds: LatLngBounds(const LatLng(20.0, 122.0), const LatLng(47.5, 154.0)),
                      ),
                      onTap: (_, __) => _handleMapTap(),
                    ),
                    children: <Widget>[
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.flutter_arrive_at_the_station',
                      ),

                      /// 日本以外を白で隠すマスク
                      PolygonLayer<String>(polygons: <Polygon<String>>[japanMaskPolygon]),

                      /// 都道府県ポリゴン
                      PolygonLayer<String>(polygons: polygons, hitNotifier: _hitNotifier),

                      /// 選択中の都道府県名
                      MarkerLayer(markers: selectedLabelMarkers),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: Colors.grey.shade100,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      _selectedPrefectureName == null ? '都道府県を選択してください' : '選択中: $_selectedPrefectureName',
                      style: const TextStyle(fontSize: 16, color: Colors.black),
                    ),

                    if (_selectedPrefectureName != null) ...<Widget>[
                      GestureDetector(
                        onTap: () {
                          ArstaDialog(
                            context: context,
                            widget: PrefTrainStationDisplayAlert(prefName: _selectedPrefectureName!),
                          ).then((_) async {
                            await _loadSelectedStation();
                            setState(() => _selectedPrefectureName = null);
                            _mapController.move(const LatLng(36.5, 137.8), 5.2);
                          });
                        },
                        child: const Icon(Icons.train, color: Colors.black),
                      ),
                    ] else ...<Widget>[const SizedBox.shrink()],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

////////////////////////////////////////////////////////////////////////

class PrefecturePolygonData {
  const PrefecturePolygonData({required this.name, required this.polygonParts});

  final String name;

  // ignore: library_private_types_in_public_api
  final List<_PolygonParts> polygonParts;

  ///
  LatLng get labelPoint {
    if (polygonParts.isEmpty) {
      return const LatLng(36.5, 137.8);
    }

    _PolygonParts largestPart = polygonParts.first;
    double largestArea = _polygonArea(largestPart.outerPoints).abs();

    for (final _PolygonParts part in polygonParts) {
      final double area = _polygonArea(part.outerPoints).abs();
      if (area > largestArea) {
        largestArea = area;
        largestPart = part;
      }
    }

    return _polygonCentroid(largestPart.outerPoints);
  }

  ///
  static double _polygonArea(List<LatLng> points) {
    if (points.length < 3) {
      return 0;
    }

    double area = 0;

    for (int i = 0; i < points.length; i++) {
      final LatLng p1 = points[i];
      final LatLng p2 = points[(i + 1) % points.length];
      area += (p1.longitude * p2.latitude) - (p2.longitude * p1.latitude);
    }

    return area / 2;
  }

  ///
  static LatLng _polygonCentroid(List<LatLng> points) {
    if (points.isEmpty) {
      return const LatLng(36.5, 137.8);
    }

    if (points.length < 3) {
      double latSum = 0;
      double lonSum = 0;

      for (final LatLng point in points) {
        latSum += point.latitude;
        lonSum += point.longitude;
      }

      return LatLng(latSum / points.length, lonSum / points.length);
    }

    double areaFactor = 0;
    double centroidX = 0;
    double centroidY = 0;

    for (int i = 0; i < points.length; i++) {
      final LatLng p1 = points[i];
      final LatLng p2 = points[(i + 1) % points.length];
      final double cross = (p1.longitude * p2.latitude) - (p2.longitude * p1.latitude);

      areaFactor += cross;
      centroidX += (p1.longitude + p2.longitude) * cross;
      centroidY += (p1.latitude + p2.latitude) * cross;
    }

    final double area = areaFactor / 2;

    if (area.abs() < 0.0000001) {
      double latSum = 0;
      double lonSum = 0;

      for (final LatLng point in points) {
        latSum += point.latitude;
        lonSum += point.longitude;
      }

      return LatLng(latSum / points.length, lonSum / points.length);
    }

    centroidX = centroidX / (6 * area);
    centroidY = centroidY / (6 * area);

    return LatLng(centroidY, centroidX);
  }
}

class _PolygonParts {
  const _PolygonParts({required this.outerPoints, required this.holePointsList});

  final List<LatLng> outerPoints;
  final List<List<LatLng>> holePointsList;
}

////////////////////////////////////////////////////////////////////////

extension FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
