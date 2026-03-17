class PrefStationModel {
  PrefStationModel({
    required this.id,
    required this.stationName,
    required this.address,
    required this.lat,
    required this.lng,
  });

  factory PrefStationModel.fromJson(Map<String, dynamic> json) {
    return PrefStationModel(
      id: json['id'] as String,
      stationName: json['station_name'] as String,
      address: json['address'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }

  final String id;
  final String stationName;
  final String address;
  final double lat;
  final double lng;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'id': id, 'station_name': stationName, 'address': address, 'lat': lat, 'lng': lng};
  }
}

class PrefTrainModel {
  PrefTrainModel({required this.trainNumber, required this.trainName, required this.station});

  factory PrefTrainModel.fromJson(Map<String, dynamic> json) {
    final List<dynamic> list = (json['station'] ?? <dynamic>[]) as List<dynamic>;
    return PrefTrainModel(
      trainNumber: json['train_number'] as int,
      trainName: json['train_name'] as String,
      // ignore: always_specify_types
      station: list.map((e) => PrefStationModel.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  final int trainNumber;
  final String trainName;
  final List<PrefStationModel> station;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'train_number': trainNumber,
      'train_name': trainName,
      'station': station.map((PrefStationModel e) => e.toJson()).toList(),
    };
  }
}
