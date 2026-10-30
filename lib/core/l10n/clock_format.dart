import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show Unicode;

/// A time of day on a 12-hour clock with the language's period ("8:00 م",
/// "8:00 PM"), in Latin digits like every number in the app (ADR 4).
String formatClock(int hour, int minute) =>
    '${hour12(hour)}:${minute.toString().padLeft(2, '0')} ${clockPeriod(hour)}';

/// What is left of a wait ("4:59"), kept left to right inside Arabic text.
String formatWait(Duration left) {
  final seconds = left.inSeconds;
  final time = '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  return '${Unicode.LRI}$time${Unicode.PDI}';
}

/// 1–12 for a 0–23 [hour].
int hour12(int hour) => hour % 12 == 0 ? 12 : hour % 12;

/// "ص" / "م" (AM / PM) for a 0–23 [hour].
String clockPeriod(int hour) => hour < 12 ? 'time_am'.tr() : 'time_pm'.tr();
