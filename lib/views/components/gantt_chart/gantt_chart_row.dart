import 'package:flutter/material.dart';
import '../../../models/task_model.dart';
import '../../../providers/task_provider.dart';
import '../../gantt_grid_painter.dart';
import 'gantt_components.dart';

class GanttChartRow extends StatefulWidget {
  final Task task;
  final DateTime chartStartDate;
  final int totalDays;
  final TaskProvider taskProvider;
  final double dayWidth;
  final double rowHeight;
  final String? dependencySourceId;
  final ValueChanged<String?> onDependencySourceIdChanged;

  const GanttChartRow({
    super.key,
    required this.task,
    required this.chartStartDate,
    required this.totalDays,
    required this.taskProvider,
    required this.dayWidth,
    required this.rowHeight,
    required this.dependencySourceId,
    required this.onDependencySourceIdChanged,
  });

  @override
  State<GanttChartRow> createState() => _GanttChartRowState();
}

class _GanttChartRowState extends State<GanttChartRow> {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.rowHeight,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SizedBox(
            height: widget.rowHeight,
            width: widget.totalDays * widget.dayWidth,
            child: CustomPaint(
              painter: GanttGridPainter(
                startDate: widget.chartStartDate,
                totalDays: widget.totalDays,
                dayWidth: widget.dayWidth,
                primaryColor: Theme.of(context).colorScheme.primary,
                secondaryColor: Theme.of(context).colorScheme.secondary,
                tertiaryColor: Theme.of(context).colorScheme.tertiary,
                gridColor: Colors.grey.shade300,
              ),
            ),
          ),
          _buildTaskBar(),
        ],
      ),
    );
  }

  Widget _buildTaskBar() {
    final task = widget.task;
    final taskStart = task.startDate;
    final taskEnd = task.endDate;
    final startOffset = taskStart.difference(widget.chartStartDate).inDays;
    final duration = taskEnd.difference(taskStart).inDays + 1;
    final left = startOffset * widget.dayWidth;
    final width = duration * widget.dayWidth;
    final progressHandlePos = width * task.progress;

    // Handle Configuration
    // 判定範囲の幅 (Hit area width)
    const double handleWidth = 34.0;
    // リサイズハンドルの位置調整 (Position offset)
    const double handleOffset = -17.0;

    return Positioned(
      left: left,
      top: 8,
      bottom: 8,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // タスクバー本体
          // タスクバー本体
          GestureDetector(
            onTap: () {
              if (widget.dependencySourceId != null) {
                if (widget.dependencySourceId != task.id) {
                  if (task.dependencies.contains(widget.dependencySourceId)) {
                    widget.taskProvider.removeDependency(
                      widget.dependencySourceId!,
                      task.id,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('関連付けを解除しました')),
                    );
                  } else {
                    widget.taskProvider.addDependency(
                      widget.dependencySourceId!,
                      task.id,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('関連付けを追加しました')),
                    );
                  }
                  widget.onDependencySourceIdChanged(null);
                } else {
                  widget.onDependencySourceIdChanged(null);
                }
              }
            },
            onSecondaryTapUp: (details) {
              _showContextMenu(context, details.globalPosition, task);
            },
            onLongPressStart: (details) {
              _showContextMenu(context, details.globalPosition, task);
            },
            child: Container(
              width: width,
              decoration: BoxDecoration(
                color: task.color.withOpacity(0.3),
                borderRadius: BorderRadius.circular(4),
                border: widget.dependencySourceId == task.id
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
              child: Stack(
                children: [
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
            left: handleOffset,
            top: -6,
            bottom: -6,
            child: ResizeHandle(
              color: task.color,
              dayWidth: widget.dayWidth,
              onDrag: (deltaDays) {
                if (deltaDays == 0) return;
                final newStart = task.startDate.add(Duration(days: deltaDays));
                if (newStart.isAfter(task.endDate)) return;
                widget.taskProvider.updateTask(
                  task.id,
                  task.copyWith(startDate: newStart),
                );
              },
              width: handleWidth,
            ),
          ),
          // 右リサイズハンドル
          Positioned(
            right: handleOffset,
            top: -6,
            bottom: -6,
            child: ResizeHandle(
              color: task.color,
              dayWidth: widget.dayWidth,
              onDrag: (deltaDays) {
                if (deltaDays == 0) return;
                final newEnd = task.endDate.add(Duration(days: deltaDays));
                if (newEnd.isBefore(task.startDate)) return;
                widget.taskProvider.updateTask(
                  task.id,
                  task.copyWith(endDate: newEnd),
                );
              },
              width: handleWidth,
            ),
          ),
          // 依存関係レシーバー
          Positioned(
            left: -24,
            top: 0,
            bottom: 0,
            child: DragTarget<String>(
              onWillAccept: (data) => data != null && data != task.id,
              onAccept: (data) =>
                  widget.taskProvider.addDependency(data, task.id),
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
          // 進捗ドラッグハンドル
          Positioned(
            left: progressHandlePos - 20,
            top: -2,
            bottom: 12,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: (details) {
                final delta = details.delta.dx;
                final newWidth = (width * task.progress) + delta;
                final newProgress = (newWidth / width).clamp(0.0, 1.0);
                widget.taskProvider.updateTask(
                  task.id,
                  task.copyWith(progress: newProgress),
                );
              },
              child: Container(
                width: 40,
                color: Colors.transparent,
                alignment: Alignment.topCenter,
                child: CustomPaint(
                  size: const Size(12, 12),
                  painter: TrianglePainter(
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
        widget.onDependencySourceIdChanged(task.id);
      }
    });
  }
}
