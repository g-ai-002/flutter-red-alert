import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 作战室背景：暗色地图网格、雷达圈与角落斜纹。
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
    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      radar,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy + radius),
      radar,
    );
    final sweep = Paint()
      ..shader = const LinearGradient(colors: [Color(0x00E8C271), Color(0x33E8C271)])
          .createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawPath(
      Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(center.dx + radius, center.dy)
        ..arcTo(Rect.fromCircle(center: center, radius: radius), 0, -0.5, false)
        ..close(),
      sweep,
    );

    final stripe = Paint()..color = const Color(0x14C8382B);
    for (var i = 0; i < 6; i++) {
      canvas.drawRect(Rect.fromLTWH(-40 + i * 26.0, size.height * 0.78, 10, 200), stripe);
    }
  }

  @override
  bool shouldRepaint(covariant WarRoomPainter oldDelegate) => false;
}
