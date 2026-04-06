import 'package:flutter/material.dart';

class GeofenceAlertDialog extends StatelessWidget {
  const GeofenceAlertDialog({super.key, required this.stationName, required this.onStop});

  final String stationName;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Focus(
        autofocus: true,
        child: GestureDetector(
          onTap: onStop,
          child: ColoredBox(
            color: Colors.red.shade900.withValues(alpha: 0.93),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(Icons.location_on, size: 80, color: Colors.white),
                const SizedBox(height: 32),
                Text(
                  '$stationName\nに近づきました！',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.white, height: 1.4),
                ),
                const SizedBox(height: 60),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white54, width: 2),
                  ),
                  child: const Column(
                    children: <Widget>[
                      Icon(Icons.touch_app, size: 64, color: Colors.white),
                      SizedBox(height: 12),
                      Text('画面をタップして停止', style: TextStyle(fontSize: 22, color: Colors.white)),
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
}
