import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:native_geofence/native_geofence.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../controllers/controllers_mixin.dart';
import '../../model/pref_train_station_model.dart';
import '../../utility/functions.dart';
import '../../utility/shared_preferences_service.dart';
import '../parts/error_dialog.dart';

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
  final TextEditingController _searchController = TextEditingController();
  final ItemScrollController _itemScrollController = ItemScrollController();

  PrefStationModel? _selectedStation;

  ///
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      prefTrainNotifier.getPrefTrainStation(prefName: widget.prefName);
    });
    _loadPrefPolygons();
    _loadSelectedStation();
  }

  ///
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  ///
  Future<void> _loadSelectedStation() async {
    final String? json = await SharedPreferencesService.loadSelectedStation();
    if (json != null && mounted) {
      try {
        final Map<String, dynamic> map = jsonDecode(json) as Map<String, dynamic>;
        setState(() => _selectedStation = PrefStationModel.fromJson(map));
      } catch (_) {}
    }
  }

  ///
  Future<void> _registerGeofence(PrefStationModel station) async {
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
  }

  ///
  Future<void> _loadPrefPolygons() async {
    final List<List<LatLng>> polygons = await loadFilteredPrefPolygons(widget.prefName);
    if (mounted) {
      setState(() => _prefPolygons = polygons);
    }
  }

  ///
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,

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
                      // 地図（背景）
                      Positioned.fill(
                        child: PrefectureMapWidget(
                          prefName: widget.prefName,
                          polylinePoints: _polylinePoints,
                          mapController: _mapController,
                          selectedLatLng: _selectedStation != null
                              ? LatLng(_selectedStation!.lat, _selectedStation!.lng)
                              : null,
                        ),
                      ),

                      // 電車リスト（検索ボタン分だけ上に隙間）
                      Positioned.fill(top: 110, child: displayPrefTrainList()),

                      Positioned(
                        top: 5,
                        right: 10,
                        left: 10,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Text('目的地の駅を選択してください。', style: TextStyle(fontSize: 10)),

                            const DefaultTextStyle(
                              style: TextStyle(fontSize: 10),
                              child: Row(
                                children: <Widget>[
                                  Icon(Icons.stacked_line_chart, size: 15),
                                  SizedBox(width: 5),
                                  Text('路線図'),
                                  SizedBox(width: 20),
                                  Icon(Icons.pages, size: 15),
                                  SizedBox(width: 5),
                                  Text('路線全域'),
                                ],
                              ),
                            ),

                            const SizedBox(height: 5),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                // 検索ボタン（BottomSheetを開く）
                                ElevatedButton.icon(
                                  onPressed: () => _showSearchBottomSheet(context),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.pinkAccent.withValues(alpha: 0.2),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),

                                  icon: const Icon(Icons.search, color: Colors.white, size: 18),
                                  label: const Text('駅名検索', style: TextStyle(color: Colors.white, fontSize: 12)),
                                ),

                                ElevatedButton.icon(
                                  onPressed: () async {
                                    final PrefStationModel? station = _selectedStation;
                                    if (station == null) {
                                      await error_dialog(
                                        context: context,
                                        title: '駅が選択されていません',
                                        content: '目的地の駅を選択してから設定ボタンを押してください。',
                                      );
                                      return;
                                    }
                                    await _registerGeofence(station);

                                    if (context.mounted) {
                                      Navigator.pop(context);
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: (_selectedStation != null)
                                        ? Colors.yellowAccent.withValues(alpha: 0.4)
                                        : Colors.pinkAccent.withValues(alpha: 0.2),
                                  ),

                                  icon: const Icon(Icons.location_on, color: Colors.white, size: 18),
                                  label: const Text('設定', style: TextStyle(color: Colors.white, fontSize: 12)),
                                ),
                              ],
                            ),

                            Divider(color: Colors.white.withValues(alpha: 0.5), thickness: 5),
                          ],
                        ),
                      ),
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
  void _showSearchBottomSheet(BuildContext context) {
    final List<PrefTrainModel> trainList = prefTrainStationState.prefTrainList;
    final Map<String, int> indexByTrainName = <String, int>{};
    for (int i = 0; i < trainList.length; i++) {
      indexByTrainName[trainList[i].trainName] = i;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _SearchSheet(
        trainList: trainList,
        indexByTrainName: indexByTrainName,
        itemScrollController: _itemScrollController,
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

    return ScrollablePositionedList.builder(
      itemScrollController: _itemScrollController,
      itemCount: trainList.length,
      itemBuilder: (BuildContext context, int index) {
        final PrefTrainModel train = trainList[index];

        return Stack(
          children: <Widget>[
            ExpansionTile(
              collapsedBackgroundColor: Colors.white.withOpacity(0.2),
              backgroundColor: Colors.white.withOpacity(0.2),
              iconColor: Colors.white,
              collapsedIconColor: Colors.white,
              onExpansionChanged: (bool expanded) async {
                if (!expanded && _selectedStation != null) {
                  if (train.station.any((PrefStationModel s) => s.id == _selectedStation!.id)) {
                    setState(() => _selectedStation = null);
                    await SharedPreferencesService.removeSelectedStation();
                  }
                }
              },
              title: Text(
                train.trainName,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12),
              ),

              children: train.station
                  .map(
                    (PrefStationModel s) => Container(
                      margin: const EdgeInsets.only(left: 40, right: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.4))),
                      ),
                      child: Row(
                        children: <Widget>[
                          GestureDetector(
                            onTap: () async {
                              if (_selectedStation?.id == s.id) {
                                setState(() => _selectedStation = null);
                                await SharedPreferencesService.removeSelectedStation();
                              } else {
                                setState(() => _selectedStation = s);
                                await SharedPreferencesService.saveSelectedStation(jsonEncode(s.toJson()));
                              }
                            },
                            child: CircleAvatar(
                              backgroundColor: (_selectedStation != null && _selectedStation!.id == s.id)
                                  ? Colors.yellowAccent.withValues(alpha: 0.6)
                                  : Colors.black.withValues(alpha: 0.4),
                              radius: 12,
                            ),
                          ),

                          const SizedBox(width: 20),

                          Expanded(
                            child: Stack(
                              children: <Widget>[
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Text(
                                    '${s.lat} / ${s.lng}',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),

                                Text(
                                  s.stationName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),

            Positioned(
              top: 15,
              right: 60,

              child: Row(
                children: <Widget>[
                  if (_selectedTrainName != null && _selectedTrainName == train.trainName) ...<Widget>[
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 30, maxWidth: 30),

                      onPressed: () {
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
                      icon: Icon(
                        Icons.pages,
                        color: (_isBoundsActive && _selectedTrainName == train.trainName)
                            ? Colors.greenAccent
                            : Colors.white,
                      ),
                    ),

                    const SizedBox(width: 20),
                  ],

                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 30, maxWidth: 30),

                    onPressed: () {
                      setState(() {
                        if (_selectedTrainName == train.trainName) {
                          _selectedTrainName = null;
                          _polylinePoints = <LatLng>[];
                        } else {
                          _selectedTrainName = train.trainName;
                          _polylinePoints = train.station.map((PrefStationModel s) => LatLng(s.lat, s.lng)).toList();
                        }
                        _isBoundsActive = false;
                      });

                      // 別の電車に切り替えた時（または解除時）は白塗り都道府県が中心に来るようにリセット
                      if (_prefPolygons.isNotEmpty) {
                        final List<LatLng> allPrefPoints = _prefPolygons.expand((List<LatLng> ring) => ring).toList();
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
                    icon: Icon(
                      Icons.stacked_line_chart,
                      color: _selectedTrainName == train.trainName ? Colors.greenAccent : Colors.white,
                    ),
                  ),
                ],
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
    this.selectedLatLng,
  });

  final String prefName;
  final List<LatLng> polylinePoints;
  final MapController mapController;
  final LatLng? selectedLatLng;

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
              polygons: allRings.map((List<LatLng> ring) {
                return Polygon<String>(points: ring, color: Colors.pinkAccent.withValues(alpha: 0.3));
              }).toList(),
            ),

            PolygonLayer<String>(polygons: <Polygon<String>>[maskPolygon]),

            if (widget.polylinePoints.length >= 2) ...<Widget>[
              PolylineLayer<String>(
                polylines: <Polyline<String>>[
                  Polyline<String>(
                    points: widget.polylinePoints,
                    color: Colors.greenAccent.withOpacity(0.4),
                    strokeWidth: 20,
                  ),
                ],
              ),
            ],

            if (widget.polylinePoints.isNotEmpty) ...<Widget>[
              MarkerLayer(
                markers: widget.polylinePoints.map((LatLng point) {
                  final bool isSelected =
                      widget.selectedLatLng != null &&
                      point.latitude == widget.selectedLatLng!.latitude &&
                      point.longitude == widget.selectedLatLng!.longitude;
                  return Marker(
                    point: point,
                    width: isSelected ? 14 : 7,
                    height: isSelected ? 14 : 7,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.yellowAccent : Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        );
      },
    );
  }
}

////////////////////////////////////////////////////////////////////////

class _SearchSheet extends StatefulWidget {
  const _SearchSheet({required this.trainList, required this.indexByTrainName, required this.itemScrollController});

  final List<PrefTrainModel> trainList;
  final Map<String, int> indexByTrainName;
  final ItemScrollController itemScrollController;

  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  final TextEditingController _ctrl = TextEditingController();
  List<({String stationName, PrefTrainModel train})> _results = <({String stationName, PrefTrainModel train})>[];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _search() {
    final String query = _ctrl.text.trim();
    final List<({String stationName, PrefTrainModel train})> found = <({String stationName, PrefTrainModel train})>[];
    for (final PrefTrainModel train in widget.trainList) {
      for (final PrefStationModel s in train.station) {
        if (s.stationName.contains(query)) {
          found.add((stationName: s.stationName, train: train));
          break;
        }
      }
    }
    setState(() => _results = found);
  }

  @override
  Widget build(BuildContext context) {
    final double keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: '駅名を入力',
                      hintStyle: const TextStyle(color: Colors.white54),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.white54),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.white),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    _search();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent.withOpacity(0.4)),
                  child: const Text('検索', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
          if (_results.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text('ここに結果が出ます', style: TextStyle(color: Colors.white54)),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _results.length,
                itemBuilder: (_, int i) {
                  final ({String stationName, PrefTrainModel train}) item = _results[i];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.train, color: Colors.white70),
                    title: Text(item.train.trainName, style: const TextStyle(color: Colors.white)),
                    subtitle: Text(item.stationName, style: const TextStyle(color: Colors.white70)),
                    onTap: () {
                      Navigator.pop(context);
                      final int? idx = widget.indexByTrainName[item.train.trainName];
                      if (idx != null && widget.itemScrollController.isAttached) {
                        widget.itemScrollController.scrollTo(
                          index: idx,
                          duration: const Duration(milliseconds: 450),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                  );
                },
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
