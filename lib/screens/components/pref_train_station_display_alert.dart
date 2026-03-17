import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../controllers/controllers_mixin.dart';
import '../../model/pref_train_station_model.dart';

class PrefTrainStationDisplayAlert extends ConsumerStatefulWidget {
  const PrefTrainStationDisplayAlert({super.key, required this.prefName});

  final String prefName;

  @override
  ConsumerState<PrefTrainStationDisplayAlert> createState() => _PrefTrainStationDisplayAlertState();
}

class _PrefTrainStationDisplayAlertState extends ConsumerState<PrefTrainStationDisplayAlert>
    with ControllersMixin<PrefTrainStationDisplayAlert> {
  List<LatLng> _polylinePoints = <LatLng>[];
  String? _selectedTrainName;
  List<List<LatLng>> _prefPolygons = <List<LatLng>>[];
  final MapController _mapController = MapController();
  bool _isBoundsActive = false;

  ///
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      prefTrainNotifier.getPrefTrainStation(prefName: widget.prefName);
    });
    _loadPrefPolygons();
  }

  ///
  Future<void> _loadPrefPolygons() async {
    final List<List<LatLng>> polygons = await loadFilteredPrefPolygons(widget.prefName);
    if (mounted) {
      setState(() => _prefPolygons = polygons);
    }
  }

  /// レイキャスティング法で点がポリゴン群の内側かどうかを判定
  bool _isInsidePref(PrefStationModel s) {
    final LatLng point = LatLng(s.lat, s.lng);
    for (final List<LatLng> ring in _prefPolygons) {
      if (_pointInPolygon(point, ring)) {
        return true;
      }
    }
    return false;
  }

  bool _pointInPolygon(LatLng point, List<LatLng> polygon) {
    bool inside = false;
    int j = polygon.length - 1;
    for (int i = 0; i < polygon.length; j = i++) {
      final double xi = polygon[i].longitude, yi = polygon[i].latitude;
      final double xj = polygon[j].longitude, yj = polygon[j].latitude;
      if (((yi > point.latitude) != (yj > point.latitude)) &&
          (point.longitude < (xj - xi) * (point.latitude - yi) / (yj - yi) + xi)) {
        inside = !inside;
      }
    }
    return inside;
  }

  ///
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,

      body: SafeArea(
        child: DefaultTextStyle(
          style: const TextStyle(color: Colors.white),

          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[Text(widget.prefName), const SizedBox.shrink()],
                ),

                Divider(color: Colors.white.withOpacity(0.4), thickness: 5),

                Expanded(
                  child: Stack(
                    children: <Widget>[
                      Positioned.fill(
                        child: PrefectureMapWidget(
                          prefName: widget.prefName,
                          polylinePoints: _polylinePoints,
                          mapController: _mapController,
                        ),
                      ),
                      displayPrefTrainList(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  ///
  Widget displayPrefTrainList() {
    if (prefTrainStationState.selectedPrefName != widget.prefName) {
      return const Center(child: CircularProgressIndicator());
    }

    final List<PrefTrainModel> trainList = prefTrainStationState.prefTrainList;

    if (trainList.isEmpty) {
      return const Center(child: Text('データがありません'));
    }

    return ListView.builder(
      itemCount: trainList.length,
      itemBuilder: (BuildContext context, int index) {
        final PrefTrainModel train = trainList[index];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: double.infinity,
              color: Colors.white.withOpacity(0.2),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(train.trainName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),

                  Row(
                    children: <Widget>[
                      if (_selectedTrainName != null) ...<Widget>[
                        GestureDetector(
                          onTap: () {
                            if (_isBoundsActive) {
                              // 解除 → 都道府県にリセット
                              setState(() => _isBoundsActive = false);
                              if (_prefPolygons.isNotEmpty) {
                                final List<LatLng> allPrefPoints = _prefPolygons
                                    .expand((List<LatLng> ring) => ring)
                                    .toList();
                                final double minLat = allPrefPoints
                                    .map((LatLng p) => p.latitude)
                                    .reduce((double a, double b) => a < b ? a : b);
                                final double maxLat = allPrefPoints
                                    .map((LatLng p) => p.latitude)
                                    .reduce((double a, double b) => a > b ? a : b);
                                final double minLng = allPrefPoints
                                    .map((LatLng p) => p.longitude)
                                    .reduce((double a, double b) => a < b ? a : b);
                                final double maxLng = allPrefPoints
                                    .map((LatLng p) => p.longitude)
                                    .reduce((double a, double b) => a > b ? a : b);
                                _mapController.fitCamera(
                                  CameraFit.bounds(
                                    bounds: LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng)),
                                    padding: const EdgeInsets.all(24),
                                  ),
                                );
                              }
                            } else {
                              // バウンズ表示
                              if (_polylinePoints.isEmpty) {
                                return;
                              }
                              setState(() => _isBoundsActive = true);
                              final double minLat = _polylinePoints
                                  .map((LatLng p) => p.latitude)
                                  .reduce((double a, double b) => a < b ? a : b);
                              final double maxLat = _polylinePoints
                                  .map((LatLng p) => p.latitude)
                                  .reduce((double a, double b) => a > b ? a : b);
                              final double minLng = _polylinePoints
                                  .map((LatLng p) => p.longitude)
                                  .reduce((double a, double b) => a < b ? a : b);
                              final double maxLng = _polylinePoints
                                  .map((LatLng p) => p.longitude)
                                  .reduce((double a, double b) => a > b ? a : b);
                              _mapController.fitCamera(
                                CameraFit.bounds(
                                  bounds: LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng)),
                                  padding: const EdgeInsets.all(24),
                                ),
                              );
                            }
                          },
                          child: Icon(Icons.pages, color: _isBoundsActive ? Colors.yellow : null),
                        ),

                        const SizedBox(width: 20),
                      ],

                      GestureDetector(
                        onTap: () {
                          setState(() {
                            if (_selectedTrainName == train.trainName) {
                              _selectedTrainName = null;
                              _polylinePoints = <LatLng>[];
                            } else {
                              _selectedTrainName = train.trainName;
                              _polylinePoints = train.station
                                  .map((PrefStationModel s) => LatLng(s.lat, s.lng))
                                  .toList();

                              // DEBUG: 駅の順番を確認
                              debugPrint('=== ${train.trainName} 駅順 ===');
                              for (final PrefStationModel s in train.station) {
                                debugPrint('order:${s.order}  ${s.stationName}  (${s.lat}, ${s.lng})');
                              }
                            }
                            _isBoundsActive = false;
                          });

                          // 別の電車に切り替えた時（または解除時）は白塗り都道府県が中心に来るようにリセット
                          if (_prefPolygons.isNotEmpty) {
                            final List<LatLng> allPrefPoints = _prefPolygons
                                .expand((List<LatLng> ring) => ring)
                                .toList();
                            final double minLat = allPrefPoints
                                .map((LatLng p) => p.latitude)
                                .reduce((double a, double b) => a < b ? a : b);
                            final double maxLat = allPrefPoints
                                .map((LatLng p) => p.latitude)
                                .reduce((double a, double b) => a > b ? a : b);
                            final double minLng = allPrefPoints
                                .map((LatLng p) => p.longitude)
                                .reduce((double a, double b) => a < b ? a : b);
                            final double maxLng = allPrefPoints
                                .map((LatLng p) => p.longitude)
                                .reduce((double a, double b) => a > b ? a : b);
                            _mapController.fitCamera(
                              CameraFit.bounds(
                                bounds: LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng)),
                                padding: const EdgeInsets.all(24),
                              ),
                            );
                          }
                        },
                        child: Icon(
                          Icons.stacked_line_chart,
                          color: _selectedTrainName == train.trainName ? Colors.yellow : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ...train.station.map(
              (PrefStationModel s) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                child: Text(s.stationName, style: TextStyle(color: _isInsidePref(s) ? Colors.white : Colors.grey)),
              ),
            ),
          ],
        );
      },
    );
  }
}

////////////////////////////////////////////////////////////////////////

/// 都道府県ポリゴンをJSONから読み込み、離島フィルタを適用して返す
Future<List<List<LatLng>>> loadFilteredPrefPolygons(String prefName) async {
  final String jsonString = await rootBundle.loadString('assets/json/japan_pref.json');
  final Map<String, dynamic> jsonMap = json.decode(jsonString) as Map<String, dynamic>;
  final List<dynamic> features = jsonMap['features'] as List<dynamic>? ?? <dynamic>[];

  final List<List<LatLng>> allRings = <List<LatLng>>[];

  for (final dynamic feature in features) {
    if (feature is! Map<String, dynamic>) {
      continue;
    }

    final Map<String, dynamic> properties = feature['properties'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final String name = (properties['N03_001']?.toString() ?? '').trim();
    if (name != prefName) {
      continue;
    }

    final Map<String, dynamic> geometry = feature['geometry'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final String type = geometry['type']?.toString() ?? '';
    final dynamic coordinates = geometry['coordinates'];
    if (coordinates == null) {
      continue;
    }

    if (type == 'Polygon') {
      allRings.add(_toLatLngListGlobal((coordinates as List<dynamic>).first as List<dynamic>));
    } else if (type == 'MultiPolygon') {
      for (final dynamic polygon in coordinates as List<dynamic>) {
        allRings.add(_toLatLngListGlobal((polygon as List<dynamic>).first as List<dynamic>));
      }
    }
  }

  if (allRings.length > 1) {
    double bboxArea(List<LatLng> ring) {
      final double minLat = ring.map((LatLng p) => p.latitude).reduce((double a, double b) => a < b ? a : b);
      final double maxLat = ring.map((LatLng p) => p.latitude).reduce((double a, double b) => a > b ? a : b);
      final double minLng = ring.map((LatLng p) => p.longitude).reduce((double a, double b) => a < b ? a : b);
      final double maxLng = ring.map((LatLng p) => p.longitude).reduce((double a, double b) => a > b ? a : b);
      return (maxLat - minLat) * (maxLng - minLng);
    }

    final List<LatLng> largestRing = allRings.reduce(
      (List<LatLng> a, List<LatLng> b) => bboxArea(a) >= bboxArea(b) ? a : b,
    );
    final double minLat = largestRing.map((LatLng p) => p.latitude).reduce((double a, double b) => a < b ? a : b);
    final double maxLat = largestRing.map((LatLng p) => p.latitude).reduce((double a, double b) => a > b ? a : b);
    final double minLng = largestRing.map((LatLng p) => p.longitude).reduce((double a, double b) => a < b ? a : b);
    final double maxLng = largestRing.map((LatLng p) => p.longitude).reduce((double a, double b) => a > b ? a : b);
    final double mainLat = (minLat + maxLat) / 2;
    final double mainLng = (minLng + maxLng) / 2;

    allRings.removeWhere((List<LatLng> ring) {
      final double centLat = ring.map((LatLng p) => p.latitude).reduce((double a, double b) => a + b) / ring.length;
      final double centLng = ring.map((LatLng p) => p.longitude).reduce((double a, double b) => a + b) / ring.length;
      final double distSq = (centLat - mainLat) * (centLat - mainLat) + (centLng - mainLng) * (centLng - mainLng);
      return distSq > 0.9 * 0.9;
    });
  }

  return allRings;
}

List<LatLng> _toLatLngListGlobal(List<dynamic> ring) {
  return ring.map((dynamic p) {
    final List<dynamic> point = p as List<dynamic>;
    return LatLng((point[1] as num).toDouble(), (point[0] as num).toDouble());
  }).toList();
}

////////////////////////////////////////////////////////////////////////

class PrefectureMapWidget extends StatefulWidget {
  const PrefectureMapWidget({
    super.key,
    required this.prefName,
    required this.polylinePoints,
    required this.mapController,
  });

  final String prefName;
  final List<LatLng> polylinePoints;
  final MapController mapController;

  @override
  State<PrefectureMapWidget> createState() => _PrefectureMapWidgetState();
}

class _PrefectureMapWidgetState extends State<PrefectureMapWidget> {
  late final Future<List<List<LatLng>>> _future;

  @override
  void initState() {
    super.initState();
    _future = loadFilteredPrefPolygons(widget.prefName);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<List<LatLng>>>(
      future: _future,
      builder: (BuildContext context, AsyncSnapshot<List<List<LatLng>>> snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final List<List<LatLng>> allRings = snapshot.data!;

        // バウンディングボックスを計算
        double minLat = double.infinity, maxLat = -double.infinity;
        double minLng = double.infinity, maxLng = -double.infinity;
        for (final List<LatLng> ring in allRings) {
          for (final LatLng p in ring) {
            if (p.latitude < minLat) {
              minLat = p.latitude;
            }
            if (p.latitude > maxLat) {
              maxLat = p.latitude;
            }
            if (p.longitude < minLng) {
              minLng = p.longitude;
            }
            if (p.longitude > maxLng) {
              maxLng = p.longitude;
            }
          }
        }

        // 都道府県以外を黒でカバーするマスク
        final Polygon<String> maskPolygon = Polygon<String>(
          points: <LatLng>[
            const LatLng(60.0, 110.0),
            const LatLng(60.0, 160.0),
            const LatLng(10.0, 160.0),
            const LatLng(10.0, 110.0),
          ],
          holePointsList: allRings,
          color: Colors.black,
          borderColor: Colors.black,
        );

        return FlutterMap(
          mapController: widget.mapController,
          options: MapOptions(
            initialCameraFit: CameraFit.bounds(
              bounds: LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng)),
              padding: const EdgeInsets.all(24),
            ),
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
          ),
          children: <Widget>[
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.flutter_arrive_at_the_station',
            ),
            PolygonLayer<String>(
              polygons: allRings
                  .map(
                    (List<LatLng> ring) => Polygon<String>(
                      points: ring,
                      color: Colors.white,
                      borderColor: Colors.black,
                      borderStrokeWidth: 1.5,
                    ),
                  )
                  .toList(),
            ),
            PolygonLayer<String>(polygons: <Polygon<String>>[maskPolygon]),
            if (widget.polylinePoints.length >= 2)
              PolylineLayer<String>(
                polylines: <Polyline<String>>[
                  Polyline<String>(points: widget.polylinePoints, color: Colors.red.withOpacity(0.4), strokeWidth: 20),
                ],
              ),
            if (widget.polylinePoints.isNotEmpty)
              MarkerLayer(
                markers: widget.polylinePoints
                    .map(
                      (LatLng point) => Marker(
                        point: point,
                        width: 7,
                        height: 7,
                        child: Container(
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        ),
                      ),
                    )
                    .toList(),
              ),
          ],
        );
      },
    );
  }
}
