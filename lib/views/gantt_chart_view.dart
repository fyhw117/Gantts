import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_model.dart';
import '../providers/task_provider.dart';
import 'gantt_grid_painter.dart';
import 'dependency_painter.dart';

/// ガントチャートビュー
class GanttChartView extends StatefulWidget {
  const GanttChartView({super.key});

  @override
  State<GanttChartView> createState() => _GanttChartViewState();
}

class _GanttChartViewState extends State<GanttChartView> {
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  final TransformationController _transformationController =
      TransformationController();

  static const double taskRowHeight = 60.0;
  static const double taskLabelWidth = 250.0;
  static const double headerHeight = 80.0;

  double _dayWidth = 20.0;
  bool _isCompact = false;
  bool _canPanChart = true;

  void _toggleViewMode() {
    setState(() {
      _isCompact = !_isCompact;
      _dayWidth = _isCompact ? 5.0 : 20.0;
    });
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskProvider>(
      builder: (context, taskProvider, child) {
        final visibleTasks = taskProvider.getVisibleTasksWithLevel();

        if (visibleTasks.isEmpty) {
          return _buildEmptyState();
        }

        final allTasks = visibleTasks.map((t) => t.task).toList();
        final dateRange = _getDateRange(allTasks);
        final startDate = dateRange['start']!;
        final endDate = dateRange['end']!;
        final totalDays = endDate.difference(startDate).inDays + 1;

        return Column(
          children: [
            _buildHeader(),
            Expanded(
              child: InteractiveViewer(
                transformationController: _transformationController,
                panEnabled: _canPanChart,
                scaleEnabled: _canPanChart,
                minScale: 0.1,
                maxScale: 5.0,
                boundaryMargin: const EdgeInsets.all(20.0),
                constrained: true,
                child: Row(
                  children: [
                    _buildTaskNameColumn(
                      visibleTasks,
                      taskProvider,
                      startDate,
                      totalDays,
                    ),
                    Expanded(
                      child: Stack(
                        children: [
                          Scrollbar(
                            controller: _horizontalScrollController,
                            thumbVisibility: true,
                            notificationPredicate: (notification) =>
                                notification.metrics.axis == Axis.horizontal,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              controller: _horizontalScrollController,
                              child: SizedBox(
                                width: totalDays * _dayWidth,
                                child: Column(
                                  children: [
                                    _buildDateHeader(startDate, totalDays),
                                    Expanded(
                                      child: Stack(
                                        children: [
                                          Scrollbar(
                                            controller:
                                                _verticalScrollController,
                                            thumbVisibility: true,
                                            notificationPredicate:
                                                (notification) =>
                                                    notification.metrics.axis ==
                                                    Axis.vertical,
                                            child: SingleChildScrollView(
                                              controller:
                                                  _verticalScrollController,
                                              child: Stack(
                                                children: [
                                                  // 依存関係の矢印レイヤー
                                                  CustomPaint(
                                                    size: Size(
                                                      totalDays * _dayWidth,
                                                      visibleTasks.length *
                                                          taskRowHeight,
                                                    ),
                                                    painter: DependencyPainter(
                                                      visibleTasks:
                                                          visibleTasks,
                                                      startDate: startDate,
                                                      dayWidth: _dayWidth,
                                                      rowHeight: taskRowHeight,
                                                      headerHeight: 0,
                                                    ),
                                                  ),
                                                  // タスクリスト
                                                  _buildGanttChartList(
                                                    visibleTasks,
                                                    startDate,
                                                    totalDays,
                                                    taskProvider,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'ガントチャート',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: Icon(_isCompact ? Icons.view_headline : Icons.view_column),
            tooltip: _isCompact ? '標準表示に切り替え' : '全体表示に切り替え',
            onPressed: _toggleViewMode,
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
          Text('タスクがありません', style: TextStyle(fontSize: 18, color: Colors.grey)),
          SizedBox(height: 8),
          Text(
            'WBSタブからタスクを作成してください',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskNameColumn(
    List<TaskWithLevel> tasks,
    TaskProvider taskProvider,
    DateTime startDate,
    int totalDays,
  ) {
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
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: const Center(
              child: Text(
                'タスク名',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
                  final taskWithLevel = tasks[index];
                  final task = taskWithLevel.task;
                  final level = taskWithLevel.level;

                  return Container(
                    height: taskRowHeight,
                    padding: EdgeInsets.only(
                      left: 8 + (level * 20.0), // 階層ごとにインデント
                      right: 8,
                      top: 4,
                      bottom: 4,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: Row(
                      children: [
                        // 展開/折りたたみボタン
                        SizedBox(
                          width: 24,
                          child: task.hasChildren
                              ? IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  iconSize: 20,
                                  icon: Icon(
                                    task.isExpanded
                                        ? Icons.expand_more
                                        : Icons.chevron_right,
                                    size: 20,
                                  ),
                                  onPressed: () =>
                                      taskProvider.toggleExpand(task.id),
                                )
                              : const SizedBox(),
                        ),
                        const SizedBox(width: 4),
                        // タスク情報
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 3,
                                    height: 14,
                                    color: task.color,
                                    margin: const EdgeInsets.only(right: 6),
                                  ),
                                  Expanded(
                                    child: Text(
                                      task.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 1),
                              Row(
                                children: [
                                  Text(
                                    '${_formatDate(task.startDate)} - ${_formatDate(task.endDate)}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '進捗: ${(task.progress * 100).toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ],
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

  Widget _buildGanttChartList(
    List<TaskWithLevel> visibleTasks,
    DateTime startDate,
    int totalDays,
    TaskProvider taskProvider,
  ) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: visibleTasks.length,
      itemBuilder: (context, index) {
        return _buildGanttRow(
          visibleTasks[index].task,
          startDate,
          totalDays,
          taskProvider,
        );
      },
    );
  }

  Widget _buildDateHeader(DateTime startDate, int totalDays) {
    return Container(
      height: headerHeight,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        children: [
          Expanded(
            child: Row(children: _buildMonthHeaders(startDate, totalDays)),
          ),
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
                  width: _dayWidth,
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(color: Colors.grey.shade300),
                    ),
                    color: isToday
                        ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
                        : (isWeekend
                              ? Theme.of(
                                  context,
                                ).colorScheme.tertiary.withOpacity(0.3)
                              : Colors.transparent),
                  ),
                  child: Center(
                    child: _isCompact
                        ? null
                        : Text(
                            '${date.day}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isToday
                                  ? Theme.of(context).colorScheme.primary
                                  : (isWeekend
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.black87),
                              fontWeight: isToday || isWeekend
                                  ? FontWeight.bold
                                  : FontWeight.normal,
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
            width: daysInCurrentMonth * _dayWidth,
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
          width: daysInCurrentMonth * _dayWidth,
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: Colors.grey.shade400, width: 2),
              right: BorderSide(color: Colors.grey.shade400, width: 2),
            ),
          ),
          child: Center(
            child: Text(
              '$currentYear年${currentMonth}月',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      );
    }

    return monthHeaders;
  }

  Widget _buildGanttRow(
    Task task,
    DateTime chartStartDate,
    int totalDays,
    TaskProvider taskProvider,
  ) {
    return Container(
      height: taskRowHeight,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: _buildGanttRowContent(
        task,
        chartStartDate,
        totalDays,
        taskProvider,
      ),
    );
  }

  Widget _buildGanttRowContent(
    Task task,
    DateTime chartStartDate,
    int totalDays,
    TaskProvider taskProvider,
  ) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          height: taskRowHeight,
          width: totalDays * _dayWidth,
          child: CustomPaint(
            painter: GanttGridPainter(
              startDate: chartStartDate,
              totalDays: totalDays,
              dayWidth: _dayWidth,
              primaryColor: Theme.of(context).colorScheme.primary,
              secondaryColor: Theme.of(context).colorScheme.secondary,
              tertiaryColor: Theme.of(context).colorScheme.tertiary,
              gridColor: Colors.grey.shade300,
            ),
          ),
        ),
        _buildTaskBar(task, chartStartDate, taskProvider),
      ],
    );
  }

  Widget _buildTaskBar(
    Task task,
    DateTime chartStartDate,
    TaskProvider taskProvider,
  ) {
    final taskStart = task.startDate;
    final taskEnd = task.endDate;
    final startOffset = taskStart.difference(chartStartDate).inDays;
    final duration = taskEnd.difference(taskStart).inDays + 1;
    final left = startOffset * _dayWidth;
    final width = duration * _dayWidth;

    // 進捗ハンドルの位置計算（0%と100%でリサイズハンドルと重ならないようにクランプ）
    final progressHandlePos = (width * task.progress).clamp(
      12.0,
      width > 24 ? width - 12.0 : 12.0,
    );

    return Positioned(
      left: left,
      top: 10,
      bottom: 10,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // タスクバー本体
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
                // 進捗バー
                Container(
                  width: width * task.progress,
                  decoration: BoxDecoration(
                    color: task.color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          // 左リサイズハンドル
          Positioned(
            left: -10,
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
          // 右リサイズハンドル
          Positioned(
            right: -10,
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
          // 依存関係レシーバー（左端 - ターゲット）
          Positioned(
            left: -24,
            top: 0,
            bottom: 0,
            child: DragTarget<String>(
              onWillAccept: (data) => data != null && data != task.id,
              onAccept: (data) => taskProvider.addDependency(data, task.id),
              builder: (context, candidateData, rejectedData) {
                return Container(
                  width: 20,
                  alignment: Alignment.center,
                  child: candidateData.isNotEmpty
                      ? const Icon(Icons.circle, color: Colors.blue, size: 12)
                      : const SizedBox(),
                );
              },
            ),
          ),
          // 依存関係コネクタ（右端 - ソース）
          Positioned(
            right: -34,
            top: 0,
            bottom: 0,
            child: Listener(
              onPointerDown: (_) {
                setState(() {
                  _canPanChart = false;
                });
              },
              onPointerUp: (_) {
                setState(() {
                  _canPanChart = true;
                });
              },
              onPointerCancel: (_) {
                setState(() {
                  _canPanChart = true;
                });
              },
              child: Draggable<String>(
                data: task.id,
                onDragEnd: (_) {
                  setState(() {
                    _canPanChart = true;
                  });
                },
                onDraggableCanceled: (_, __) {
                  setState(() {
                    _canPanChart = true;
                  });
                },
                onDragCompleted: () {
                  setState(() {
                    _canPanChart = true;
                  });
                },
                feedback: Material(
                  color: Colors.transparent,
                  child: const Icon(
                    Icons.play_arrow,
                    size: 24,
                    color: Colors.blue,
                  ),
                ),
                child: Container(
                  width: 30,
                  alignment: Alignment.center,
                  color: Colors.transparent,
                  child: const Icon(
                    Icons.play_arrow,
                    size: 20,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
          ),
          // 進捗ドラッグハンドル (最後に配置して最前面にする)
          Positioned(
            left: progressHandlePos - 10,
            top: -4,
            bottom: -4,
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                final scale = _transformationController.value
                    .getMaxScaleOnAxis();
                final delta = details.delta.dx / scale;
                final newWidth = (width * task.progress) + delta;
                final newProgress = (newWidth / width).clamp(0.0, 1.0);
                taskProvider.updateTask(
                  task.id,
                  task.copyWith(progress: newProgress),
                );
              },
              child: Container(
                width: 20,
                color: Colors.transparent, // ヒット領域確保
                child: Center(
                  child: Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade600),
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResizeHandle({
    required Color color,
    required void Function(int deltaDays) onDrag,
  }) {
    return _ResizeHandle(color: color, onDrag: onDrag, dayWidth: _dayWidth);
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

    return {'start': minDate, 'end': maxDate};
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}';
  }
}

/// リサイズハンドルウィジェット
class _ResizeHandle extends StatefulWidget {
  final Color color;
  final void Function(int deltaDays) onDrag;
  final double dayWidth;

  const _ResizeHandle({
    required this.color,
    required this.onDrag,
    required this.dayWidth,
  });

  @override
  State<_ResizeHandle> createState() => _ResizeHandleState();
}

class _ResizeHandleState extends State<_ResizeHandle> {
  double _accumulatedDrag = 0;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (details) {
          _accumulatedDrag = 0;
        },
        onHorizontalDragUpdate: (details) {
          _accumulatedDrag += details.delta.dx;
          final deltaDays = (_accumulatedDrag / widget.dayWidth).round();
          if (deltaDays != 0) {
            widget.onDrag(deltaDays);
            _accumulatedDrag = 0; // リセット
          }
        },
        child: Container(
          width: 20,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            border: Border.all(color: widget.color, width: 2),
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 2,
              height: 12,
              decoration: BoxDecoration(
                color: widget.color.withOpacity(0.6),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
