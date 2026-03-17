import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

///
extension ContextEx on BuildContext {
  TextTheme get textTheme => Theme.of(this).textTheme;

  ColorScheme get colorTheme => Theme.of(this).colorScheme;

  Size get screenSize => MediaQuery.of(this).size;
}

///
extension DateTimeEx on DateTime {
  String get yyyymmdd {
    final DateFormat outputFormat = DateFormat('yyyy-MM-dd');
    return outputFormat.format(this);
  }

  String get yyyymm {
    final DateFormat outputFormat = DateFormat('yyyy-MM');
    return outputFormat.format(this);
  }

  String get mmdd {
    final DateFormat outputFormat = DateFormat('MM-dd');
    return outputFormat.format(this);
  }

  String get yyyy {
    final DateFormat outputFormat = DateFormat('yyyy');
    return outputFormat.format(this);
  }

  String get mm {
    final DateFormat outputFormat = DateFormat('MM');
    return outputFormat.format(this);
  }

  String get dd {
    final DateFormat outputFormat = DateFormat('dd');
    return outputFormat.format(this);
  }

  String get youbiStr {
    final DateFormat outputFormat = DateFormat('EEEE');
    return outputFormat.format(this);
  }
}

///

const int _fullLengthCode = 65248;

extension StringEx on String {
  DateTime toDateTime() {
    final DateFormat dateFormatter = DateFormat('yyyy-MM-dd HH:mm:ss');
    return dateFormatter.parseStrict(this);
  }

  int toInt() {
    return int.parse(this);
  }

  String toCurrency() {
    final NumberFormat formatter = NumberFormat('#,###');
    return formatter.format(int.parse(this));
  }

  double toDouble() {
    return double.parse(this);
  }

  String alphanumericToFullLength() {
    final RegExp regex = RegExp(r'^[a-zA-Z0-9]+$');
    final Iterable<String> string = runes.map<String>((int rune) {
      final String char = String.fromCharCode(rune);
      return regex.hasMatch(char)
          ? String.fromCharCode(rune + _fullLengthCode)
          : char;
    });
    return string.join();
  }

  String alphanumericToHalfLength() {
    final RegExp regex = RegExp(r'^[Ａ-Ｚａ-ｚ０-９]+$');
    final Iterable<String> string = runes.map<String>((int rune) {
      final String char = String.fromCharCode(rune);
      return regex.hasMatch(char)
          ? String.fromCharCode(rune - _fullLengthCode)
          : char;
    });
    return string.join();
  }
}
