import 'package:flutter/material.dart';

class DateTimeUtils {
  static DateTime today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  static String inferMealType() {
    final hour = DateTime.now().hour;
    if (hour < 5) return 'Snack'; // 00:00–04:59 late night
    if (hour < 11) return 'Breakfast'; // 05:00–10:59
    if (hour < 15) return 'Lunch'; // 11:00–14:59
    if (hour < 17) return 'Snack'; // 15:00–16:59 afternoon
    if (hour < 21) return 'Dinner'; // 17:00–20:59
    return 'Snack'; // 21:00+ late
  }

  static TimeOfDay parseTime(String timeStr) {
    final m = RegExp(r'(\d+):(\d+)(?:\s*(AM|PM))?', caseSensitive: false).firstMatch(timeStr);
    if (m == null) return TimeOfDay.now();
    int hour = int.parse(m.group(1)!);
    final minute = int.parse(m.group(2)!);
    final period = m.group(3)?.toUpperCase();
    if (period == 'PM' && hour != 12) hour += 12;
    if (period == 'AM' && hour == 12) hour = 0;
    return TimeOfDay(hour: hour % 24, minute: minute);
  }
}
