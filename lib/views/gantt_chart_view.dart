import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import '../../models/task_model.dart';
import '../../providers/task_provider.dart';
import 'package:linked_scroll_controller/linked_scroll_controller.dart';
import 'components/gantt_chart/gantt_chart_header.dart';
import 'components/gantt_chart/gantt_chart_row.dart';
import 'components/gantt_chart/gantt_task_column.dart';
import 'dependency_painter.dart';
import 'project_list_view.dart';

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
        if (taskProvider.projects.isEmpty) {
          return _buildNoProjectState(context);
        }

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
                  GanttTaskColumn(
                    tasks: visibleTasks,
                    taskProvider: taskProvider,
                    scrollController: _taskNameScrollController,
                    width: taskLabelWidth,
                    headerHeight: headerHeight,
                    rowHeight: taskRowHeight,
                  ),
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
                      child: Column(
                        children: [
                          // 上部: 日付ヘッダー (横スクロールのみ)
                          SingleChildScrollView(
                            controller: _dateHeaderScrollController,
                            scrollDirection: Axis.horizontal,
                            physics: const ClampingScrollPhysics(), // バウンス抑制
                            child: SizedBox(
                              width: totalDays * _dayWidth,
                              child: GanttChartHeader(
                                startDate: startDate,
                                totalDays: totalDays,
                                dayWidth: _dayWidth,
                                isCompact: _isCompact,
                                headerHeight: headerHeight,
                              ),
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
                                      // タスクリスト
                                      _buildGanttChartList(
                                        visibleTasks,
                                        startDate,
                                        totalDays,
                                        taskProvider,
                                      ),
                                      // 依存関係の矢印レイヤー
                                      IgnorePointer(
                                        child: CustomPaint(
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
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNoProjectState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.folder_off, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'プロジェクトがありません',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProjectListView(),
                ),
              );
            },
            child: const Text('プロジェクトを作成する'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
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
        return GanttChartRow(
          task: visibleTasks[index].task,
          chartStartDate: startDate,
          totalDays: totalDays,
          taskProvider: taskProvider,
          dayWidth: _dayWidth,
          rowHeight: taskRowHeight,
          dependencySourceId: _dependencySourceId,
          onDependencySourceIdChanged: (id) {
            setState(() {
              _dependencySourceId = id;
            });
          },
        );
      },
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

    return {'start': minDate, 'end': maxDate};
  }
}
