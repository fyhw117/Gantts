import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import '../models/task_model.dart';
import '../providers/task_provider.dart';
import 'package:linked_scroll_controller/linked_scroll_controller.dart';
import 'gantt_grid_painter.dart';
import 'dependency_painter.dart';

/// ガントチャートビュー
class GanttChartView extends StatefulWidget {
  const GanttChartView({super.key});

  @override
  State<GanttChartView> createState() => _GanttChartViewState();
}

class _GanttChartViewState extends State<GanttChartView> {
  late LinkedScrollControllerGroup _verticalControllers;
  late ScrollController _taskNameScrollController;
  late ScrollController _gridVerticalScrollController;

  late LinkedScrollControllerGroup _horizontalControllers;
  late ScrollController _dateHeaderScrollController;
  late ScrollController _gridHorizontalScrollController;

  static const double taskRowHeight = 40.0;
  static const double taskLabelWidth = 160.0;
  static const double headerHeight = 40.0;

  double _dayWidth = 20.0;
  double _baseDayWidth = 20.0;
  bool _isCompact = false; // "標準表示"状態かどうか（アイコンの意味と逆にならないように注意）
  String? _dependencySourceId; // 関連付けの開始点となるタスクID

  @override
  void initState() {
    super.initState();
    _verticalControllers = LinkedScrollControllerGroup();
    _taskNameScrollController = _verticalControllers.addAndGet();
    _gridVerticalScrollController = _verticalControllers.addAndGet();

    _horizontalControllers = LinkedScrollControllerGroup();
    _dateHeaderScrollController = _horizontalControllers.addAndGet();
    _gridHorizontalScrollController = _horizontalControllers.addAndGet();
  }

  void _toggleViewMode() {
    setState(() {
      _isCompact = !_isCompact;
      _dayWidth = _isCompact ? 5.0 : 20.0;
    });
  }

  @override
  void dispose() {
    _taskNameScrollController.dispose();
    _gridVerticalScrollController.dispose();
    _dateHeaderScrollController.dispose();
    _gridHorizontalScrollController.dispose();
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
              child: Row(
                children: [
                  // 左側: タスク名列 (固定)
                  _buildTaskNameColumn(visibleTasks, taskProvider),
                  // 右側: ガントチャート (ズーム・スクロール可能)
                  Expanded(
                    child: Listener(
                      onPointerSignal: (event) {
                        if (event is PointerScrollEvent) {
                          final keys =
                              HardwareKeyboard.instance.logicalKeysPressed;
                          if (keys.contains(LogicalKeyboardKey.controlLeft) ||
                              keys.contains(LogicalKeyboardKey.controlRight)) {
                            final dy = event.scrollDelta.dy;
                            setState(() {
                              if (dy < 0) {
                                // Zoom In
                                _dayWidth = (_dayWidth * 1.1).clamp(5.0, 100.0);
                              } else if (dy > 0) {
                                // Zoom Out
                                _dayWidth = (_dayWidth * 0.9).clamp(5.0, 100.0);
                              }
                            });
                          }
                        }
                      },
                      onPointerPanZoomStart: (event) {
                        _baseDayWidth = _dayWidth;
                      },
                      onPointerPanZoomUpdate: (event) {
                        setState(() {
                          _dayWidth = (_baseDayWidth * event.scale).clamp(
                            5.0,
                            100.0,
                          );
                        });
                      },
                      child: GestureDetector(
                        onScaleStart: (details) {
                          _baseDayWidth = _dayWidth;
                        },
                        onScaleUpdate: (details) {
                          setState(() {
                            _dayWidth = (_baseDayWidth * details.scale).clamp(
                              5.0,
                              100.0,
                            );
                          });
                        },
                        child: Column(
                          children: [
                            // 上部: 日付ヘッダー (横スクロールのみ)
                            SingleChildScrollView(
                              controller: _dateHeaderScrollController,
                              scrollDirection: Axis.horizontal,
                              physics: const ClampingScrollPhysics(), // バウンス抑制
                              child: SizedBox(
                                width: totalDays * _dayWidth,
                                child: _buildDateHeader(startDate, totalDays),
                              ),
                            ),
                            // メイン: チャートグリッド (縦横スクロール可能)
                            Expanded(
                              child: SingleChildScrollView(
                                controller: _gridHorizontalScrollController,
                                scrollDirection: Axis.horizontal,
                                physics: const ClampingScrollPhysics(),
                                child: SizedBox(
                                  width: totalDays * _dayWidth,
                                  child: SingleChildScrollView(
                                    controller: _gridVerticalScrollController,
                                    physics: const ClampingScrollPhysics(),
                                    child: Stack(
                                      children: [
                                        // 依存関係の矢印レイヤー
                                        CustomPaint(
                                          size: Size(
                                            totalDays * _dayWidth,
                                            visibleTasks.length * taskRowHeight,
                                          ),
                                          painter: DependencyPainter(
                                            visibleTasks: visibleTasks,
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
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'ガントチャート',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          IconButton(
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(4),
            icon: Icon(_isCompact ? Icons.zoom_in : Icons.zoom_out),
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
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ),
          Expanded(
            child: Scrollbar(
              controller: _taskNameScrollController,
              thumbVisibility: true,
              child: ListView.builder(
                controller: _taskNameScrollController,
                itemCount: tasks.length,
                itemBuilder: (context, index) {
                  final taskWithLevel = tasks[index];
                  final task = taskWithLevel.task;
                  final level = taskWithLevel.level;

                  return Container(
                    height: taskRowHeight,
                    padding: EdgeInsets.only(
                      left: 2 + (level * 10.0), // 階層ごとにインデント
                      right: 2,
                      top: 0,
                      bottom: 0,
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
                          width: 16,
                          child: task.hasChildren
                              ? IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  iconSize: 16,
                                  icon: Icon(
                                    task.isExpanded
                                        ? Icons.expand_more
                                        : Icons.chevron_right,
                                    size: 16,
                                  ),
                                  onPressed: () =>
                                      taskProvider.toggleExpand(task.id),
                                )
                              : const SizedBox(),
                        ),
                        const SizedBox(width: 2),
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
                                    margin: const EdgeInsets.only(right: 2),
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
                                    '${(task.progress * 100).toStringAsFixed(0)}%',
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

    // 進捗ハンドルの位置計算
    final progressHandlePos = width * task.progress;

    return Positioned(
      left: left,
      top: 8,
      bottom: 8,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // タスクバー本体
          Container(
            width: width,
            decoration: BoxDecoration(
              color: task.color.withOpacity(0.3),
              borderRadius: BorderRadius.circular(4),
              border: _dependencySourceId == task.id
                  ? Border.all(color: Colors.red, width: 2)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: GestureDetector(
              onTap: () {
                if (_dependencySourceId != null) {
                  if (_dependencySourceId != task.id) {
                    if (task.dependencies.contains(_dependencySourceId)) {
                      taskProvider.removeDependency(
                        _dependencySourceId!,
                        task.id,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('関連付けを解除しました')),
                      );
                    } else {
                      taskProvider.addDependency(_dependencySourceId!, task.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('関連付けを追加しました')),
                      );
                    }
                    setState(() {
                      _dependencySourceId = null;
                    });
                  } else {
                    setState(() {
                      _dependencySourceId = null;
                    });
                  }
                }
              },
              onSecondaryTapUp: (details) {
                _showContextMenu(context, details.globalPosition, task);
              },
              onLongPressStart: (details) {
                _showContextMenu(context, details.globalPosition, task);
              },
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

          // 進捗ドラッグハンドル (最後に配置して最前面にする)
          Positioned(
            left: progressHandlePos - 20,
            top: -2, // 上にはみ出す（タッチ領域拡大）
            bottom: 12, // 下半分はリサイズハンドル用に空ける
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: (details) {
                final delta = details.delta.dx;
                final newWidth = (width * task.progress) + delta;
                final newProgress = (newWidth / width).clamp(0.0, 1.0);
                taskProvider.updateTask(
                  task.id,
                  task.copyWith(progress: newProgress),
                );
              },
              child: Container(
                width: 40,
                color: Colors.transparent, // ヒット領域確保
                alignment: Alignment.topCenter,
                child: CustomPaint(
                  size: const Size(12, 12),
                  painter: _TrianglePainter(
                    color: Colors.white,
                    borderColor: Colors.grey.shade600,
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

  void _showContextMenu(BuildContext context, Offset position, Task task) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        const PopupMenuItem(
          value: 'connect',
          child: Row(
            children: [Icon(Icons.link), SizedBox(width: 8), Text('関連付けを編集')],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'connect') {
        setState(() {
          _dependencySourceId = task.id;
        });
      }
    });
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
          color: Colors.transparent, // ヒットターゲット確保
          alignment: Alignment.center,
          child: Container(
            width: 8,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              border: Border.all(
                color: widget.color.withOpacity(0.8),
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  final Color borderColor;

  _TrianglePainter({required this.color, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width / 2, size.height);
    path.close();

    // Shadow
    canvas.drawShadow(path, Colors.black.withOpacity(0.3), 2.0, false);

    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.borderColor != borderColor;
  }
}
