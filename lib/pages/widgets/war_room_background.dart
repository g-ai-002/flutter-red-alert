import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// 作战室背景：暗色地图网格与雷达圈。
class WarRoomPainter extends CustomPainter {
  const WarRoomPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = const Color(0x0DFFFFFF)
      ..strokeWidth = 1;
    const step = 56.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final center = Offset(size.width * 0.78, size.height * 0.28);
    final radius = math.min(size.width, size.height) * 0.34;
    final radar = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x18E8C271);
    for (var i = 1; i <= 4; i++) {
      canvas.drawCircle(center, radius * i / 4, radar);
    }
    for (final horizontal in [true, false]) {
      canvas.drawLine(
        horizontal ? Offset(center.dx - radius, center.dy) : Offset(center.dx, center.dy - radius),
        horizontal ? Offset(center.dx + radius, center.dy) : Offset(center.dx, center.dy + radius),
        radar,
      );
    }
  }

  @override
  bool shouldRepaint(covariant WarRoomPainter oldDelegate) => false;
}
