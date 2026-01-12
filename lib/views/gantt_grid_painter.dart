import 'package:flutter/material.dart';

class GanttGridPainter extends CustomPainter {
  final DateTime startDate;
  final int totalDays;
  final double dayWidth;
  final Color primaryColor;
  final Color secondaryColor;
  final Color tertiaryColor;
  final Color gridColor;

  GanttGridPainter({
    required this.startDate,
    required this.totalDays,
    required this.dayWidth,
    required this.primaryColor,
    required this.secondaryColor,
    required this.tertiaryColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final paint = Paint();

    for (int i = 0; i < totalDays; i++) {
      final date = startDate.add(Duration(days: i));
      final isToday =
          date.year == today.year &&
          date.month == today.month &&
          date.day == today.day;
      final isWeekend =
          date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;

      final x = i * dayWidth;

      // Draw background
      if (isToday) {
        paint.color = primaryColor.withOpacity(0.3);
        canvas.drawRect(Rect.fromLTWH(x, 0, dayWidth, size.height), paint);
      } else if (isWeekend) {
        paint.color = tertiaryColor.withOpacity(0.3);
        canvas.drawRect(Rect.fromLTWH(x, 0, dayWidth, size.height), paint);
      }

      // Draw border line
      paint.color = gridColor;
      paint.strokeWidth = 1.0;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant GanttGridPainter oldDelegate) {
    return oldDelegate.startDate != startDate ||
        oldDelegate.totalDays != totalDays ||
        oldDelegate.dayWidth != dayWidth ||
        oldDelegate.primaryColor != primaryColor;
  }
}
