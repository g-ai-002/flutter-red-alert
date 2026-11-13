import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../game/battle_controller.dart';
import '../../game/battle_state.dart';
import '../../game/battle_types.dart';
import '../../game/entity.dart';
import '../../game/terrain.dart';
import '../../theme/palette.dart';

/// 迷你地图：展示地形、矿石、双方单位与当前视野，点击或拖动可移动摄像机。
///
/// 地形只在尺寸或地图版本变化时重建 [ui.Picture]，单位与视野以约 6Hz
/// 单独重绘，避免每次 HUD 刷新都重新遍历 44×44 格。
class BattleMinimap extends StatefulWidget {
  const BattleMinimap({super.key, required this.controller, this.size = 124});

  final BattleController controller;
  final double size;

  @override
  State<BattleMinimap> createState() => _BattleMinimapState();
}

class _BattleMinimapState extends State<BattleMinimap> {
  ui.Picture? _terrain;
  Size _terrainSize = Size.zero;
  int _terrainVersion = -1;
  int _visionVersion = -1;

  @override
  void dispose() {
    _terrain?.dispose();
    super.dispose();
  }

  void _focus(Offset local, Size box) {
    final map = widget.controller.state.map;
    final world = Offset(
      (local.dx / box.width * map.width).clamp(0, map.width.toDouble()),
      (local.dy / box.height * map.height).clamp(0, map.height.toDouble()),
    );
    widget.controller.focusWorld(world);
  }

  void _ensureTerrain(GameMap map, Size size) {
    final vision = widget.controller.state.vision;
    if (_terrain != null &&
        _terrainSize == size &&
        _terrainVersion == map.version &&
        _visionVersion == vision.version) {
      return;
    }
    _terrain?.dispose();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final sx = size.width / map.width;
    final sy = size.height / map.height;
    final fill = Paint();
    final sx2 = sx * 2.1;
    final sy2 = sy * 2.1;
    // 地形按 2 格采样，兼顾清晰度与绘制开销。
    for (var y = 0; y < map.height; y += 2) {
      for (var x = 0; x < map.width; x += 2) {
        final kind = map.terrainAt(x, y);
        final rect = Rect.fromLTWH(x * sx, y * sy, sx2, sy2);
        canvas.drawRect(
          rect,
          fill..color = terrainColor(kind).withValues(alpha: 0.95),
        );
        if (map.oreAt(x, y) > 0) {
          canvas.drawCircle(rect.center, sx * 0.9, fill..color = _oreColor);
        }
        if (!vision.isExplored(x, y)) {
          canvas.drawRect(rect, fill..color = const Color(0xF20B0A08));
        } else if (!vision.isVisible(x, y)) {
          canvas.drawRect(rect, fill..color = const Color(0x800B0A08));
        }
      }
    }
    _terrain = recorder.endRecording();
    _terrainSize = size;
    _terrainVersion = map.version;
    _visionVersion = vision.version;
  }

  @override
  Widget build(BuildContext context) {
    final map = widget.controller.state.map;
    final aspect = map.width / map.height;
    final width = widget.size * aspect;
    final size = Size(width, widget.size);
    _ensureTerrain(map, size);
    return Semantics(
      label: '迷你地图',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) => _focus(details.localPosition, size),
        onPanUpdate: (details) => _focus(details.localPosition, size),
        child: Container(
          width: width,
          height: widget.size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0x663A342B)),
            boxShadow: const [
              BoxShadow(color: Color(0x66000000), blurRadius: 8),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _MinimapPainter(
                controller: widget.controller,
                terrain: _terrain,
              ),
              size: size,
            ),
          ),
        ),
      ),
    );
  }
}

const Color _oreColor = Color(0xFFD9A94B);

class _MinimapPainter extends CustomPainter {
  _MinimapPainter({required this.controller, required this.terrain});

  final BattleController controller;
  final ui.Picture? terrain;
  final Paint _fill = Paint();
  final Paint _stroke = Paint()..style = PaintingStyle.stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final state = controller.state;
    final map = state.map;
    final sx = size.width / map.width;
    final sy = size.height / map.height;

    if (terrain != null) canvas.drawPicture(terrain!);

    final radar = state.radarActive;
    final vision = state.vision;
    for (final building in state.redBuildings) {
      if (!building.alive) continue;
      canvas.drawRect(
        Rect.fromLTWH(
          building.tileX * sx,
          building.tileY * sy,
          building.spec.width * sx,
          building.spec.height * sy,
        ),
        _fill..color = building.team.color,
      );
    }
    for (final building in state.blueBuildings) {
      if (!building.alive) continue;
      if (!radar && !vision.sees(building)) continue;
      canvas.drawRect(
        Rect.fromLTWH(
          building.tileX * sx,
          building.tileY * sy,
          building.spec.width * sx,
          building.spec.height * sy,
        ),
        _fill..color = building.team.color,
      );
    }

    for (final unit in state.redUnits) {
      if (!unit.alive) continue;
      _drawUnit(canvas, unit, sx, sy);
    }
    for (final unit in state.blueUnits) {
      if (!unit.alive) continue;
      if (!radar && !vision.sees(unit)) continue;
      _drawUnit(canvas, unit, sx, sy);
    }

    if (radar) {
      final center = state.map.baseOf(Team.red);
      final progress =
          1 - state.radarRemaining / BattleState.radarScanSeconds;
      canvas.drawCircle(
        Offset(center.dx * sx, center.dy * sy),
        math.max(map.width, map.height) * sx * progress,
        _stroke
          ..strokeWidth = 1.2
          ..color = const Color(0xFFE8C271).withValues(alpha: 0.55),
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
        _stroke
          ..strokeWidth = 1.4
          ..color = const Color(0xFFF4EAD6),
      );
    }
  }

  void _drawUnit(Canvas canvas, Unit unit, double sx, double sy) {
    canvas.drawCircle(
      Offset(unit.x * sx, unit.y * sy),
      1.6,
      _fill..color = unit.team.color,
    );
  }

  @override
  bool shouldRepaint(covariant _MinimapPainter oldDelegate) => true;
}
