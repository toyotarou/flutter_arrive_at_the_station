import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pref_train_station/pref_train_station.dart';

mixin ControllersMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  //==========================================//

  PrefTrainStationState get prefTrainStationState => ref.watch(prefTrainStationProvider);

  PrefTrainStation get prefTrainNotifier => ref.read(prefTrainStationProvider.notifier);

  //==========================================//
}
