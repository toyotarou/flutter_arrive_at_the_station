import 'package:flutter/material.dart';

// ignore: non_constant_identifier_names
Future<void> error_dialog({required BuildContext context, required String title, required String content}) {
  return showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: Colors.blueGrey.withValues(alpha: 0.3),
        title: Text(title, style: const TextStyle(fontSize: 12)),
        content: Text(content, style: const TextStyle(fontSize: 12)),
      );
    },
  );
}
