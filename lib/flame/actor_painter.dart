import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../game/battle_camera.dart';
import '../game/battle_state.dart';
import '../game/entity.dart';
import '../game/placement_state.dart';
import '../utils/constants.dart';
import 'building_art.dart';
import 'paint_utils.dart';
import 'unit_art.dart';

/// 单位、建筑、血条、放置预览与建筑标签的世界坐标绘制。
///
/// 所有坐标以格子为单位，由战场入口统一施加摄像机变换；这里负责视野裁剪、
/// 选中框、血条与标签，具体造型交给 [UnitArt] 与 [BuildingArt]。
class ActorPainter {
  ActorPainter({required this.state, required this.selectedIds, required this.placement}) {
    final brush = ArtBrush();
    _brush = brush;
    _unitArt = UnitArt(brush);
    _buildingArt = BuildingArt(brush);
  }

  final BattleState state;
  final Set<int> selectedIds;
  final PlacementState placement;

  final Map<String, TextPainter> _labels = {};
  final List<Actor> _visible = [];
  late final ArtBrush _brush;
  late final UnitArt _unitArt;
  late final BuildingArt _buildingArt;
  final Paint _outline = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.055
    ..color = const Color(0xCC15130F);

  void dispose() {
    _labels.clear();
    _unitArt.dispose();
    _buildingArt.dispose();
  }

  // ===== 单位与建筑 =====

  void drawActors(Canvas canvas, Rect view) {
    _visible.clear();
    for (final actor in state.actors) {
      if (!actor.alive) continue;
      if (!state.isVisibleToPlayer(actor)) continue;
      if (actor is Building) {
        if (!view.overlaps(actor.bounds)) continue;
      } else if (actor.x + actor.radius < view.left ||
          actor.x - actor.radius > view.right ||
          actor.y + actor.radius < view.top ||
          actor.y - actor.radius > view.bottom) {
        continue;
      }
      _visible.add(actor);
    }
    _visible.sort((a, b) => a.y.compareTo(b.y));
    for (final actor in _visible) {
      if (actor is Building) {
        _drawBuilding(canvas, actor);
      } else if (actor is Unit) {
        _drawUnit(canvas, actor);
      }
    }
  }

  void _drawUnit(Canvas canvas, Unit unit) {
    final selected = selectedIds.contains(unit.id);
    final center = Offset(unit.x, unit.y);
    final teamColor = unit.team.color;

    canvas.drawOval(
      Rect.fromCenter(
        center: center + const Offset(0.06, 0.1),
        width: unit.radius * 2.2,
        height: unit.radius * 1.1,
      ),
      _brush.solid(const Color(0x55000000)),
    );
    if (selected) {
      canvas.drawOval(
        Rect.fromCenter(center: center, width: unit.radius * 2.9, height: unit.radius * 2.0),
        _brush.outlined(const Color(0xFFF2D27A), 0.06),
      );
    }

    _unitArt.paint(canvas, unit, _outline);

    if (unit.hitFlash > 0) {
      canvas.drawCircle(
        center,
        unit.radius * 1.3,
        _brush.solid(Colors.white.withValues(alpha: unit.hitFlash * 1.6)),
      );
    }
    if (unit.hp < unit.maxHp) {
      _drawHpBar(
        canvas,
        center: center + Offset(0, -unit.radius - 0.22),
        width: 0.8,
        ratio: unit.hp / unit.maxHp,
        color: teamColor,
      );
    }
    if (unit.isHarvester && unit.cargo > 0) {
      _drawHpBar(
        canvas,
        center: center + Offset(0, unit.radius + 0.16),
        width: 0.8,
        ratio: unit.cargoRatio,
        color: const Color(0xFFD9A94B),
      );
    }
  }

  void _drawBuilding(Canvas canvas, Building building) {
    _buildingArt.paint(canvas, building, _outline);
    if (selectedIds.contains(building.id)) {
      _buildingArt.paintSelection(canvas, building);
    }
    if (building.hp < building.maxHp) {
      _drawHpBar(
        canvas,
        center: Offset(building.x, building.bounds.top - 0.16),
        width: math.min(2.4, (building.bounds.width - 0.1) * 0.8),
        ratio: building.hp / building.maxHp,
        color: building.team.color,
      );
    }
  }

  void _drawHpBar(
    Canvas canvas, {
    required Offset center,
    required double width,
    required double ratio,
    required Color color,
  }) {
    final rect = Rect.fromCenter(center: center, width: width, height: 0.11);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(0.03)),
      _brush.solid(const Color(0xCC16140F)),
    );
    final clamped = ratio.clamp(0.0, 1.0);
    if (clamped <= 0) return;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          rect.left + 0.015,
          rect.top + 0.02,
          (rect.width - 0.03) * clamped,
          rect.height - 0.04,
        ),
        const Radius.circular(0.02),
      ),
      _brush.solid(color),
    );
  }

  // ===== 放置预览 =====

  void drawGhost(Canvas canvas) {
    final spec = placement.spec;
    final tile = placement.tile;
    if (spec == null || tile == null) return;
    final color = placement.valid ? const Color(0xFF6FCF7A) : const Color(0xFFE0604F);
    final rect = Rect.fromLTWH(
      tile.x.toDouble(),
      tile.y.toDouble(),
      spec.width.toDouble(),
      spec.height.toDouble(),
    );
    canvas.drawRect(rect, Paint()..color = color.withValues(alpha: 0.22));
    canvas.drawRect(rect, _brush.outlined(color, 0.09));
    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.45)
      ..strokeWidth = 0.03;
    for (var i = 1; i < spec.width; i++) {
      canvas.drawLine(
        Offset(tile.x + i.toDouble(), rect.top),
        Offset(tile.x + i.toDouble(), rect.bottom),
        linePaint,
      );
    }
    for (var i = 1; i < spec.height; i++) {
      canvas.drawLine(
        Offset(rect.left, tile.y + i.toDouble()),
        Offset(rect.right, tile.y + i.toDouble()),
        linePaint,
      );
    }
    if (spec.isDefense && spec.range > 0) {
      canvas.drawCircle(
        rect.center,
        spec.range,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.04
          ..color = color.withValues(alpha: 0.5),
      );
    }
  }

  // ===== 屏幕空间文字 =====

  void drawBuildingLabels(Canvas canvas, BattleCamera camera) {
    if (camera.tileSize < 13) return;
    final fontSize = (camera.tileSize * 0.52).clamp(8.0, 18.0);
    final viewport = Rect.fromLTWH(0, 0, camera.viewport.width, camera.viewport.height);
    for (final building in state.allBuildings) {
      _drawBuildingLabel(canvas, camera, viewport, fontSize, building);
    }
  }

  void _drawBuildingLabel(
    Canvas canvas,
    BattleCamera camera,
    Rect viewport,
    double fontSize,
    Building building,
  ) {
    if (!building.alive) return;
    if (!state.isVisibleToPlayer(building)) return;
    final screen = camera.worldToScreen(Offset(building.x, building.y));
    if (!viewport.contains(screen)) return;
    final painter = _labelPainter(building.spec.icon, fontSize);
    painter.paint(canvas, screen - Offset(painter.width / 2, painter.height / 2));
  }

  TextPainter _labelPainter(String text, double fontSize) {
    final key = '$text|${fontSize.round()}';
    return _labels.putIfAbsent(key, () {
      return TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: const Color(0xFFF4EADA),
            fontFamily: kIsWeb ? kWebFontFamily : null,
            shadows: const [Shadow(color: Color(0xCC000000), blurRadius: 4)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    });
  }
}
