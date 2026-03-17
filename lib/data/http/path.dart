enum APIPath { getPrefTrainStation, getTrain, getAllStation }

extension APIPathExtension on APIPath {
  String? get value {
    switch (this) {
      case APIPath.getPrefTrainStation:
        return 'getPrefTrainStation';
      case APIPath.getTrain:
        return 'getTrain';
      case APIPath.getAllStation:
        return 'getAllStation';
    }
  }
}
