import 'package:flutter/material.dart';

class DateTimeUtils {
  static DateTime today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  static String inferMealType() {
    final hour = DateTime.now().hour;
    if (hour < 10) return 'Breakfast';
    if (hour < 14) return 'Lunch';
    return 'Dinner';
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
