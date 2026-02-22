import 'package:flutter/material.dart';

class GanttChartHeader extends StatelessWidget {
  final DateTime startDate;
  final int totalDays;
  final double dayWidth;
  final bool isCompact;
  final double headerHeight;

  const GanttChartHeader({
    super.key,
    required this.startDate,
    required this.totalDays,
    required this.dayWidth,
    required this.isCompact,
    required this.headerHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: headerHeight,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        children: [
          Expanded(child: Row(children: _buildMonthHeaders(context))),
          Expanded(
            child: Row(
              children: List.generate(totalDays, (index) {
                final date = startDate.add(Duration(days: index));
                final now = DateTime.now();
                final isToday =
                    date.year == now.year &&
                    date.month == now.month &&
                    date.day == now.day;
                final isWeekend =
                    date.weekday == DateTime.saturday ||
                    date.weekday == DateTime.sunday;

                return Container(
                  width: dayWidth,
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(color: Colors.grey.shade300),
                    ),
                    color: isToday
                        ? Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.3)
                        : (isWeekend
                              ? Theme.of(
                                  context,
                                ).colorScheme.tertiary.withValues(alpha: 0.3)
                              : Colors.transparent),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Center(
                        child: isCompact
                            ? null
                            : Text(
                                '${date.day}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isToday
                                      ? Theme.of(context).colorScheme.primary
                                      : (isWeekend
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.primary
                                            : Colors.black87),
                                  fontWeight: isToday || isWeekend
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                      ),
                      if (isToday)
                        Positioned(
                          left: (dayWidth / 2) - 1,
                          top: 0,
                          bottom: 0,
                          child: Container(width: 2, color: Colors.redAccent),
                        ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMonthHeaders(BuildContext context) {
    List<Widget> monthHeaders = [];
    int currentMonth = startDate.month;
    int currentYear = startDate.year;
    int daysInCurrentMonth = 0;

    for (int i = 0; i < totalDays; i++) {
      final date = startDate.add(Duration(days: i));

      if (date.month == currentMonth && date.year == currentYear) {
        daysInCurrentMonth++;
      } else {
        monthHeaders.add(
          Container(
            width: daysInCurrentMonth * dayWidth,
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: Colors.grey.shade400, width: 2),
                right: BorderSide(color: Colors.grey.shade400, width: 2),
              ),
            ),
            child: Center(
              child: Text(
                '$currentYear年$currentMonth月',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        );

        currentMonth = date.month;
        currentYear = date.year;
        daysInCurrentMonth = 1;
      }
    }

    if (daysInCurrentMonth > 0) {
      monthHeaders.add(
        Container(
          width: daysInCurrentMonth * dayWidth,
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: Colors.grey.shade400, width: 2),
              right: BorderSide(color: Colors.grey.shade400, width: 2),
            ),
          ),
          child: Center(
            child: Text(
              '$currentYear年$currentMonth月',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      );
    }

    return monthHeaders;
  }
}
