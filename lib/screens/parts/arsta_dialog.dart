// ignore_for_file: non_constant_identifier_names

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> ArstaDialog({
  required BuildContext context,
  required Widget widget,
  double paddingTop = 0,
  double paddingRight = 0,
  double paddingBottom = 0,
  double paddingLeft = 0,
  bool clearBarrierColor = false,
  bool? executeFunctionWhenDialogClose,
  WidgetRef? ref,
  String? from,
}) {
  // ignore: inference_failure_on_function_invocation
  return showDialog(
    context: context,
    barrierColor: clearBarrierColor ? Colors.transparent : Colors.blueGrey.withOpacity(0.3),
    builder: (BuildContext ctx) {
      return MediaQuery(
        data: MediaQuery.of(ctx).copyWith(
        viewInsets: EdgeInsets.zero,
        padding: MediaQuery.of(ctx).viewPadding,
      ),
        child: Container(
          padding: EdgeInsets.only(top: paddingTop, right: paddingRight, bottom: paddingBottom, left: paddingLeft),
          child: Dialog(
            backgroundColor: Colors.blueGrey.withOpacity(0.3),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            insetPadding: const EdgeInsets.all(30),
            child: widget,
          ),
        ),
      );
    },
    // ignore: always_specify_types
  ).then((value) {});
}
