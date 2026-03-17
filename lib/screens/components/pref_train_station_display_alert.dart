import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

                Expanded(child: displayPrefTrainList()),
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
              child: Text(train.trainName, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            ...train.station.map(
              (PrefStationModel s) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                child: Text(s.stationName),
              ),
            ),
          ],
        );
      },
    );
  }
}
