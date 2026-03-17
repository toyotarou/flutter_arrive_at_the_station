import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../utility/utility.dart';

////////////////////////////////////////////////////////////////////////

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Future<List<PrefecturePolygonData>> _future;

  // ignore: always_specify_types
  final LayerHitNotifier<String> _hitNotifier = ValueNotifier(null);

  String? _selectedPrefectureName;

  Utility utility = Utility();

  ///
  @override
  void initState() {
    super.initState();
    _future = _loadPrefecturePolygonData();
  }

  ///
  @override
  void dispose() {
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

    return Polygon<String>(
      points: outerMask,
      holePointsList: holePointsList,
      color: Colors.white,
      borderColor: Colors.white,
    );
  }

  ///
  void _handleMapTap() {
    final LayerHitResult<String>? hit = _hitNotifier.value;
    final String? tappedPrefecture = (hit == null || hit.hitValues.isEmpty) ? null : hit.hitValues.first;

    if (tappedPrefecture == null) {
      return;
    }

    debugPrint('クリックした都道府県: $tappedPrefecture');

    setState(() {
      _selectedPrefectureName = tappedPrefecture;
    });
  }

  ///
  @override
  Widget build(BuildContext context) {
    final List<Color> fortyEightColor = utility.getFortyEightColor();

    final Size screenSize = MediaQuery.sizeOf(context);
    final double mapWidth = screenSize.width * 0.8;
    final double mapHeight = screenSize.height * 0.5;

    return Scaffold(
      appBar: AppBar(title: const Text('クリックできる日本地図')),
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
                child: Container(
                  width: mapWidth,
                  height: mapHeight,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: FlutterMap(
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

                      const RichAttributionWidget(
                        attributions: <SourceAttribution>[TextSourceAttribution('OpenStreetMap contributors')],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: Colors.grey.shade100,
                child: Text(
                  _selectedPrefectureName == null ? '都道府県をタップしてください' : '選択中: $_selectedPrefectureName',
                  style: const TextStyle(fontSize: 16, color: Colors.black),
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
