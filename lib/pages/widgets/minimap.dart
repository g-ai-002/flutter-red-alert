import 'package:flutter/material.dart';

import '../../game/battle_controller.dart';
import '../../game/battle_types.dart';
import '../../game/entity.dart';
import '../../theme/palette.dart';

/// 迷你地图：展示地形、矿石、双方单位与当前视野，点击或拖动可移动摄像机。
class BattleMinimap extends StatelessWidget {
  const BattleMinimap({super.key, required this.controller, this.size = 124});

  final BattleController controller;
  final double size;

  void _focus(Offset local, Size box) {
    final map = controller.state.map;
    final world = Offset(
      (local.dx / box.width * map.width).clamp(0, map.width.toDouble()),
      (local.dy / box.height * map.height).clamp(0, map.height.toDouble()),
    );
    controller.focusWorld(world);
  }

  @override
  Widget build(BuildContext context) {
    final map = controller.state.map;
    final aspect = map.width / map.height;
    final width = size * aspect;
    return Semantics(
      label: '迷你地图',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) =>
            _focus(details.localPosition, Size(width, size)),
        onPanUpdate: (details) =>
            _focus(details.localPosition, Size(width, size)),
        child: Container(
          width: width,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0x663A342B)),
            boxShadow: const [
              BoxShadow(color: Color(0x66000000), blurRadius: 8),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: CustomPaint(
            painter: _MinimapPainter(controller: controller),
            size: Size(width, size),
          ),
        ),
      ),
    );
  }
}

class _MinimapPainter extends CustomPainter {
  _MinimapPainter({required this.controller});

  final BattleController controller;

  @override
  void paint(Canvas canvas, Size size) {
    final state = controller.state;
    final map = state.map;
    final sx = size.width / map.width;
    final sy = size.height / map.height;

    // 地形按 2 格采样，兼顾清晰度与绘制开销。
    for (var y = 0; y < map.height; y += 2) {
      for (var x = 0; x < map.width; x += 2) {
        final kind = map.terrainAt(x, y);
        final rect = Rect.fromLTWH(x * sx, y * sy, sx * 2.1, sy * 2.1);
        canvas.drawRect(
          rect,
          Paint()..color = terrainColor(kind).withValues(alpha: 0.95),
        );
        if (map.oreAt(x, y) > 0) {
          canvas.drawCircle(
            rect.center,
            sx * 0.9,
            Paint()..color = const Color(0xFFD9A94B),
          );
        }
      }
    }

    for (final building in state.actors.whereType<Building>()) {
      if (!building.alive) continue;
      canvas.drawRect(
        Rect.fromLTWH(
          building.tileX * sx,
          building.tileY * sy,
          building.spec.width * sx,
          building.spec.height * sy,
        ),
        Paint()..color = building.team.color,
      );
    }

    for (final unit in state.unitsOf(Team.red)) {
      canvas.drawCircle(
        Offset(unit.x * sx, unit.y * sy),
        1.6,
        Paint()..color = unit.team.color,
      );
    }
    for (final unit in state.unitsOf(Team.blue)) {
      canvas.drawCircle(
        Offset(unit.x * sx, unit.y * sy),
        1.6,
        Paint()..color = unit.team.color,
      );
    }

    final visible = controller.camera.visibleWorld.intersect(
      Rect.fromLTWH(0, 0, map.width.toDouble(), map.height.toDouble()),
    );
    if (!visible.isEmpty) {
      canvas.drawRect(
        Rect.fromLTWH(
          visible.left * sx,
          visible.top * sy,
          visible.width * sx,
          visible.height * sy,
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = const Color(0xFFF4EAD6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MinimapPainter oldDelegate) => true;
}
