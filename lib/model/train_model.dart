class TrainModel {
  TrainModel({required this.trainNumber, required this.trainName});

  /// JSON → モデル
  factory TrainModel.fromJson(Map<String, dynamic> json) {
    return TrainModel(trainNumber: json['train_number'] as String, trainName: json['train_name'] as String);
  }

  final String trainNumber;
  final String trainName;

  /// モデル → JSON
  Map<String, dynamic> toJson() {
    return <String, dynamic>{'train_number': trainNumber, 'train_name': trainName};
  }
}
