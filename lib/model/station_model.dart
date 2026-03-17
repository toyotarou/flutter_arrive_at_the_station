class StationModel {
  StationModel({
    required this.id,
    required this.stationName,
    required this.address,
    required this.lat,
    required this.lng,
    required this.prefecture,
    required this.lineNumber,
    required this.lineName,
  });

  /// JSON → モデル
  factory StationModel.fromJson(Map<String, dynamic> json) {
    return StationModel(
      id: json['id'] as int,
      stationName: json['station_name'] as String,
      address: json['address'] as String,
      lat: json['lat'] as String,
      lng: json['lng'] as String,
      prefecture: json['prefecture'] as String,
      lineNumber: json['line_number'] as String,
      lineName: json['line_name'] as String,
    );
  }

  final int id;
  final String stationName;
  final String address;
  final String lat;
  final String lng;
  final String prefecture;
  final String lineNumber;
  final String lineName;

  /// モデル → JSON
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'station_name': stationName,
      'address': address,
      'lat': lat,
      'lng': lng,
      'prefecture': prefecture,
      'line_number': lineNumber,
      'line_name': lineName,
    };
  }
}
