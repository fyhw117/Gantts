import 'package:flutter/material.dart';

class TrianglePainter extends CustomPainter {
  final Color color;
  final Color borderColor;

  TrianglePainter({required this.color, required this.borderColor});

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
  bool shouldRepaint(covariant TrianglePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.borderColor != borderColor;
  }
}

class ResizeHandle extends StatefulWidget {
  final Color color;
  final void Function(int deltaDays) onDrag;
  final double dayWidth;

  const ResizeHandle({
    super.key,
    required this.color,
    required this.onDrag,
    required this.dayWidth,
  });

  @override
  State<ResizeHandle> createState() => _ResizeHandleState();
}

class _ResizeHandleState extends State<ResizeHandle> {
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
          final int deltaDays = (_accumulatedDrag / widget.dayWidth).round();

          if (deltaDays != 0) {
            widget.onDrag(deltaDays);
            _accumulatedDrag -= deltaDays * widget.dayWidth;
          }
        },
        child: Container(
          width: 20, // Increase hit area
          color: Colors.transparent,
          alignment: Alignment.center,
          child: Container(
            width: 8,
            height: 24, // Ensure visible height
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
