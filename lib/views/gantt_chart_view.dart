import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_model.dart';
import '../providers/task_provider.dart';

/// ガントチャートビュー
class GanttChartView extends StatefulWidget {
  const GanttChartView({super.key});

  @override
  State<GanttChartView> createState() => _GanttChartViewState();
}

class _GanttChartViewState extends State<GanttChartView> {
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  
  static const double taskRowHeight = 60.0;
  static const double taskLabelWidth = 250.0;
  static const double dayWidth = 40.0;
  static const double headerHeight = 80.0;

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskProvider>(
      builder: (context, taskProvider, child) {
        final allTasks = taskProvider.getAllTasks();
        
        if (allTasks.isEmpty) {
          return _buildEmptyState();
        }

        final dateRange = _getDateRange(allTasks);
        final startDate = dateRange['start']!;
        final endDate = dateRange['end']!;
        final totalDays = endDate.difference(startDate).inDays + 1;

        return Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Row(
                children: [
                  _buildTaskNameColumn(allTasks),
                  Expanded(
                    child: Scrollbar(
                      controller: _horizontalScrollController,
                      thumbVisibility: true,
                      notificationPredicate: (notification) =>
                          notification.metrics.axis == Axis.horizontal,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        controller: _horizontalScrollController,
                        child: SizedBox(
                          width: totalDays * dayWidth,
                          child: Column(
                            children: [
                              _buildDateHeader(startDate, totalDays),
                              Expanded(
                                child: Scrollbar(
                                  controller: _verticalScrollController,
                                  thumbVisibility: true,
                                  notificationPredicate: (notification) =>
                                      notification.metrics.axis == Axis.vertical,
                                  child: ListView.builder(
                                    controller: _verticalScrollController,
                                    itemCount: allTasks.length,
                                    itemBuilder: (context, index) {
                                      return _buildGanttRow(
                                        allTasks[index],
                                        startDate,
                                        totalDays,
                                        taskProvider,
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: const Row(
        children: [
          Text(
            'ガントチャート',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.timeline, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'タスクがありません',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          SizedBox(height: 8),
          Text(
            'WBSタブからタスクを作成してください',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskNameColumn(List<Task> tasks) {
    return Container(
      width: taskLabelWidth,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.grey.shade300, width: 2),
        ),
      ),
      child: Column(
        children: [
          Container(
            height: headerHeight,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: const Center(
              child: Text(
                'タスク名',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          Expanded(
            child: Scrollbar(
              controller: _verticalScrollController,
              thumbVisibility: true,
              child: ListView.builder(
                controller: _verticalScrollController,
                itemCount: tasks.length,
                itemBuilder: (context, index) {
                  final task = tasks[index];
                  return Container(
                    height: taskRowHeight,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 3,
                              height: 16,
                              color: task.color,
                              margin: const EdgeInsets.only(right: 6),
                            ),
                            Expanded(
                              child: Text(
                                task.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_formatDate(task.startDate)} - ${_formatDate(task.endDate)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '進捗: ${(task.progress * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateHeader(DateTime startDate, int totalDays) {
    return Container(
      height: headerHeight,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: _buildMonthHeaders(startDate, totalDays),
            ),
          ),
          Expanded(
            child: Row(
              children: List.generate(totalDays, (index) {
                final date = startDate.add(Duration(days: index));
                final isWeekend =
                    date.weekday == DateTime.saturday ||
                    date.weekday == DateTime.sunday;
                
                return Container(
                  width: dayWidth,
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(color: Colors.grey.shade300),
                    ),
                    color: isWeekend
                        ? Colors.blue.shade50
                        : Colors.transparent,
                  ),
                  child: Center(
                    child: Text(
                      '${date.day}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isWeekend ? Colors.blue : Colors.black87,
                        fontWeight:
                            isWeekend ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMonthHeaders(DateTime startDate, int totalDays) {
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
                '$currentYear年${currentMonth}月',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
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
              '$currentYear年${currentMonth}月',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
      );
    }

    return monthHeaders;
  }

  Widget _buildGanttRow(Task task, DateTime chartStartDate, int totalDays, TaskProvider taskProvider) {
    return Container(
      height: taskRowHeight,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Row(
            children: List.generate(totalDays, (index) {
              final date = chartStartDate.add(Duration(days: index));
              final isWeekend =
                  date.weekday == DateTime.saturday ||
                  date.weekday == DateTime.sunday;
              
              return Container(
                width: dayWidth,
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: Colors.grey.shade300),
                  ),
                  color: isWeekend
                      ? Colors.blue.shade50.withOpacity(0.3)
                      : Colors.transparent,
                ),
              );
            }),
          ),
          _buildTaskBar(task, chartStartDate, taskProvider),
        ],
      ),
    );
  }

  Widget _buildTaskBar(Task task, DateTime chartStartDate, TaskProvider taskProvider) {
    final taskStart = task.startDate;
    final taskEnd = task.endDate;
    final startOffset = taskStart.difference(chartStartDate).inDays;
    final duration = taskEnd.difference(taskStart).inDays + 1;
    final left = startOffset * dayWidth;
    final width = duration * dayWidth;

    return Positioned(
      left: left,
      top: 10,
      bottom: 10,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: width,
            decoration: BoxDecoration(
              color: task.color.withOpacity(0.7),
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              children: [
                Container(
                  width: width * task.progress,
                  decoration: BoxDecoration(
                    color: task.color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '${task.name} (${(task.progress * 100).toStringAsFixed(0)}%)',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        shadows: [
                          Shadow(
                            color: Colors.black45,
                            offset: Offset(1, 1),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: -8,
            top: -6,
            bottom: -6,
            child: _buildResizeHandle(
              color: task.color,
              onDrag: (deltaDays) {
                if (deltaDays == 0) return;
                final newStart = task.startDate.add(Duration(days: deltaDays));
                if (newStart.isAfter(task.endDate)) return;
                taskProvider.updateTask(
                  task.id,
                  task.copyWith(startDate: newStart),
                );
              },
            ),
          ),
          Positioned(
            right: -8,
            top: -6,
            bottom: -6,
            child: _buildResizeHandle(
              color: task.color,
              onDrag: (deltaDays) {
                if (deltaDays == 0) return;
                final newEnd = task.endDate.add(Duration(days: deltaDays));
                if (newEnd.isBefore(task.startDate)) return;
                taskProvider.updateTask(
                  task.id,
                  task.copyWith(endDate: newEnd),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResizeHandle({required Color color, required void Function(int deltaDays) onDrag}) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (details) {
          final deltaDays = (details.delta.dx / dayWidth).round();
          if (deltaDays != 0) {
            onDrag(deltaDays);
          }
        },
        child: Container(
          width: 16,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: color, width: 2),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }

  Map<String, DateTime> _getDateRange(List<Task> tasks) {
    if (tasks.isEmpty) {
      return {
        'start': DateTime.now(),
        'end': DateTime.now().add(const Duration(days: 30)),
      };
    }

    DateTime minDate = tasks.first.startDate;
    DateTime maxDate = tasks.first.endDate;

    for (var task in tasks) {
      if (task.startDate.isBefore(minDate)) {
        minDate = task.startDate;
      }
      if (task.endDate.isAfter(maxDate)) {
        maxDate = task.endDate;
      }
    }

    minDate = DateTime(minDate.year, minDate.month, minDate.day);
    maxDate = DateTime(maxDate.year, maxDate.month, maxDate.day);

    return {
      'start': minDate,
      'end': maxDate,
    };
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}';
  }
}
