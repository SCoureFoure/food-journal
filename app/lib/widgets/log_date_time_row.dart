import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class LogDateTimeRow extends StatelessWidget {
  final DateTime date;
  final TimeOfDay time;
  final bool enabled;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<TimeOfDay> onTimeChanged;
  final Widget? leading;

  const LogDateTimeRow({
    super.key,
    required this.date,
    required this.time,
    required this.onDateChanged,
    required this.onTimeChanged,
    this.enabled = true,
    this.leading,
  });

  String _formatTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (leading != null) ...[leading!, const Spacer()],
        if (leading == null) const Spacer(),
        TextButton.icon(
          onPressed: enabled ? () => _pickDate(context) : null,
          icon: const Icon(Icons.calendar_today, size: 14),
          label: Text(DateFormat('MMM d').format(date)),
        ),
        TextButton.icon(
          onPressed: enabled ? () => _pickTime(context) : null,
          icon: const Icon(Icons.access_time, size: 14),
          label: Text(_formatTime(time)),
        ),
      ],
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
    );
    if (picked != null) onDateChanged(picked);
  }

  Future<void> _pickTime(BuildContext context) async {
    final picked = await showTimePicker(context: context, initialTime: time);
    if (picked != null) onTimeChanged(picked);
  }
}
