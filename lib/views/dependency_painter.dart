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

        final targetStartX = _getX(
          targetTask.startDate.difference(startDate).inDays,
        );
        final targetY =
            headerHeight + (targetIndex * rowHeight) + (rowHeight / 2);

        final path = Path();
        path.moveTo(sourceEndX, sourceY);

        // Bezier Curve
        final controlPoint1 = Offset(sourceEndX + 20, sourceY);
        final controlPoint2 = Offset(targetStartX - 20, targetY);

        // If source is to the right of target, curve needs to go around or be steeper
        if (sourceEndX > targetStartX) {
          // Complex curve or simple S-curve?
          // For simplicity, S-curve is usually fine, but might look weird if overlapping.
          // Let's use simple cubicTo for now.
        }

        path.cubicTo(
          controlPoint1.dx,
          controlPoint1.dy,
          controlPoint2.dx,
          controlPoint2.dy,
          targetStartX,
          targetY,
        );

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
