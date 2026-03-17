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

  ///
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      prefTrainNotifier.getPrefTrainStation(prefName: widget.prefName);
    });
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
                        child: PrefectureMapWidget(prefName: widget.prefName, polylinePoints: _polylinePoints),
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
                children: [
                  Expanded(
                    child: Text(train.trainName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),

                  GestureDetector(
                    onTap: () {
                      setState(() {
                        if (_selectedTrainName == train.trainName) {
                          _selectedTrainName = null;
                          _polylinePoints = <LatLng>[];
                        } else {
                          _selectedTrainName = train.trainName;
                          _polylinePoints = train.station.map((PrefStationModel s) => LatLng(s.lat, s.lng)).toList();
                        }
                      });
                    },
                    child: Icon(
                      Icons.stacked_line_chart,
                      color: _selectedTrainName == train.trainName ? Colors.yellow : null,
                    ),
                  ),
                ],
              ),
            ),
            ...train.station.map(
              (PrefStationModel s) =>
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4), child: Text(s.stationName)),
            ),
          ],
        );
      },
    );
  }
}

////////////////////////////////////////////////////////////////////////

class PrefectureMapWidget extends StatefulWidget {
  const PrefectureMapWidget({super.key, required this.prefName, required this.polylinePoints});

  final String prefName;
  final List<LatLng> polylinePoints;

  @override
  State<PrefectureMapWidget> createState() => _PrefectureMapWidgetState();
}

class _PrefectureMapWidgetState extends State<PrefectureMapWidget> {
  late final Future<List<List<LatLng>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadPolygons();
  }

  Future<List<List<LatLng>>> _loadPolygons() async {
    final String jsonString = await rootBundle.loadString('assets/json/japan_pref.json');
    final Map<String, dynamic> jsonMap = json.decode(jsonString) as Map<String, dynamic>;
    final List<dynamic> features = jsonMap['features'] as List<dynamic>? ?? <dynamic>[];

    final List<List<LatLng>> allRings = <List<LatLng>>[];

    for (final dynamic feature in features) {
      if (feature is! Map<String, dynamic>) continue;

      final Map<String, dynamic> properties = feature['properties'] as Map<String, dynamic>? ?? <String, dynamic>{};
      final String name = (properties['N03_001']?.toString() ?? '').trim();
      if (name != widget.prefName) continue;

      final Map<String, dynamic> geometry = feature['geometry'] as Map<String, dynamic>? ?? <String, dynamic>{};
      final String type = geometry['type']?.toString() ?? '';
      final dynamic coordinates = geometry['coordinates'];
      if (coordinates == null) continue;

      if (type == 'Polygon') {
        final List<dynamic> rings = coordinates as List<dynamic>;
        allRings.add(_toLatLngList(rings.first as List<dynamic>));
      } else if (type == 'MultiPolygon') {
        for (final dynamic polygon in coordinates as List<dynamic>) {
          final List<dynamic> rings = polygon as List<dynamic>;
          allRings.add(_toLatLngList(rings.first as List<dynamic>));
        }
      }
    }

    // 離島除去: 最大リング（バウンディングボックス面積が最大）の中心から 0.9度以上離れたリングを除外
    if (allRings.length > 1) {
      double _bboxArea(List<LatLng> ring) {
        final double minLat = ring.map((LatLng p) => p.latitude).reduce((double a, double b) => a < b ? a : b);
        final double maxLat = ring.map((LatLng p) => p.latitude).reduce((double a, double b) => a > b ? a : b);
        final double minLng = ring.map((LatLng p) => p.longitude).reduce((double a, double b) => a < b ? a : b);
        final double maxLng = ring.map((LatLng p) => p.longitude).reduce((double a, double b) => a > b ? a : b);
        return (maxLat - minLat) * (maxLng - minLng);
      }

      final List<LatLng> largestRing = allRings.reduce(
        (List<LatLng> a, List<LatLng> b) => _bboxArea(a) >= _bboxArea(b) ? a : b,
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

  List<LatLng> _toLatLngList(List<dynamic> ring) {
    return ring.map((dynamic p) {
      final List<dynamic> point = p as List<dynamic>;
      return LatLng((point[1] as num).toDouble(), (point[0] as num).toDouble());
    }).toList();
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
            if (p.latitude < minLat) minLat = p.latitude;
            if (p.latitude > maxLat) maxLat = p.latitude;
            if (p.longitude < minLng) minLng = p.longitude;
            if (p.longitude > maxLng) maxLng = p.longitude;
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
