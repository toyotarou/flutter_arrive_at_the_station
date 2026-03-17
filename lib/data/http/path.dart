enum APIPath { getPrefTrainStation }

extension APIPathExtension on APIPath {
  String? get value {
    switch (this) {
      case APIPath.getPrefTrainStation:
        return 'getPrefTrainStation';
    }
  }
}
