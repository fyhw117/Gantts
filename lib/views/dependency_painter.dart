import 'package:flutter/material.dart';
import '../providers/task_provider.dart';

class DependencyPainter extends CustomPainter {
  final List<TaskWithLevel> visibleTasks;
  final DateTime startDate;
  final double dayWidth;
  final double rowHeight;
  final double headerHeight;

  DependencyPainter({
    required this.visibleTasks,
    required this.startDate,
    required this.dayWidth,
    required this.rowHeight,
    required this.headerHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade600
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final arrowHeadPaint = Paint()
      ..color = Colors.grey.shade600
      ..style = PaintingStyle.fill;

    // Create a map for quick lookup of task index by ID
    final taskIndexMap = {
      for (var i = 0; i < visibleTasks.length; i++) visibleTasks[i].task.id: i,
    };

    for (int i = 0; i < visibleTasks.length; i++) {
      final task = visibleTasks[i].task;
      if (task.dependencies.isEmpty) continue;

      for (final dependencyId in task.dependencies) {
        if (!taskIndexMap.containsKey(dependencyId)) continue;

        final dependencyIndex = taskIndexMap[dependencyId]!;
        final dependencyTask = visibleTasks[dependencyIndex].task;

        // Target: The current task (arrow points TO this task)
        // Source: The dependency task (arrow starts FROM this task)
        // Arrow: Source(End) -> Target(Start)

        /* 
           Wait, logic check:
           Task A depends on Task B.
           Typically this means B must finish before A starts.
           Arrow: B(End) -> A(Start).
           
           My loop: iterating `task` (A). `task.dependencies` contains B.
           So Source is B (dependency), Target is A (current).
        */

        final sourceTask = dependencyTask;
        final targetTask = task;
        final sourceIndex = dependencyIndex;
        final targetIndex = i;

        final sourceEndX = _getX(
          sourceTask.endDate.difference(startDate).inDays + 1,
        );
        final sourceY =
            headerHeight + (sourceIndex * rowHeight) + (rowHeight / 2);

        final targetStartX =
            _getX(targetTask.startDate.difference(startDate).inDays) - 6.0;
        final targetY =
            headerHeight + (targetIndex * rowHeight) + (rowHeight / 2);

        final path = Path();
        path.moveTo(sourceEndX, sourceY);

        const double xOffset = 20.0;

        if (sourceEndX < targetStartX - xOffset) {
          // Standard case: Source is far enough to the left
          // 1. Right to (targetStartX - 10) ? Or midpoint?
          // Let's go to (targetStartX - 20) to make the final approach horizontal
          final midX = targetStartX - xOffset;
          path.lineTo(midX, sourceY);
          path.lineTo(midX, targetY);
          path.lineTo(targetStartX, targetY);
        } else {
          // Overlap case: Source ends after Target starts (or too close)
          // Need to go around
          // 1. Go Right from Source
          final r1 = sourceEndX + 10.0;
          path.lineTo(r1, sourceY);

          // 2. Go Vertical to Mid Y
          final midY = (sourceY + targetY) / 2;
          path.lineTo(r1, midY);

          // 3. Go Left to Target approach X
          final l1 = targetStartX - xOffset;
          path.lineTo(l1, midY);

          // 4. Go Vertical to Target Y
          path.lineTo(l1, targetY);

          // 5. Go Right to Target
          path.lineTo(targetStartX, targetY);
        }

        canvas.drawPath(path, paint);

        // Draw Arrow Head
        _drawArrowHead(canvas, targetStartX, targetY, arrowHeadPaint);
      }
    }
  }

  double _getX(int days) {
    return days * dayWidth;
  }

  void _drawArrowHead(Canvas canvas, double x, double y, Paint paint) {
    final path = Path();
    path.moveTo(x, y);
    path.lineTo(x - 6, y - 4);
    path.lineTo(x - 6, y + 4);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant DependencyPainter oldDelegate) {
    return oldDelegate.visibleTasks != visibleTasks ||
        oldDelegate.startDate != startDate ||
        oldDelegate.dayWidth != dayWidth ||
        oldDelegate.rowHeight != rowHeight;
  }
}
