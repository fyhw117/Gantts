import 'package:flutter/material.dart';
import '../../../providers/task_provider.dart';

class GanttTaskColumn extends StatelessWidget {
  final List<TaskWithLevel> tasks;
  final TaskProvider taskProvider;
  final ScrollController scrollController;
  final double width;
  final double headerHeight;
  final double rowHeight;

  const GanttTaskColumn({
    super.key,
    required this.tasks,
    required this.taskProvider,
    required this.scrollController,
    required this.width,
    required this.headerHeight,
    required this.rowHeight,
  });

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
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
              controller: scrollController,
              thumbVisibility: true,
              child: ListView.builder(
                controller: scrollController,
                itemCount: tasks.length,
                itemBuilder: (context, index) {
                  final taskWithLevel = tasks[index];
                  final task = taskWithLevel.task;
                  final level = taskWithLevel.level;

                  return Container(
                    height: rowHeight,
                    padding: EdgeInsets.only(
                      left: 2 + (level * 10.0), // 階層ごとにインデント
                      right: 2,
                      top: 0,
                      bottom: 0,
                    ),
                    decoration: BoxDecoration(
                      color: task.progress >= 1.0
                          ? Colors.grey.shade300
                          : Colors.transparent,
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: Opacity(
                      opacity: task.progress >= 1.0 ? 0.5 : 1.0,
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
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                          decoration: task.progress >= 1.0
                                              ? TextDecoration.lineThrough
                                              : null,
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
}
