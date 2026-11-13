import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../game/battle_camera.dart';
import '../game/battle_state.dart';
import '../game/battle_types.dart';
import '../game/entity.dart';
import '../game/placement_state.dart';
import '../utils/constants.dart';
import 'paint_utils.dart';

/// 单位、建筑、血条、放置预览与建筑标签的世界坐标绘制。
///
/// 所有坐标以格子为单位，由战场入口统一施加摄像机变换，这里只关心造型。
class ActorPainter {
  ActorPainter({
    required this.state,
    required this.selectedIds,
    required this.placement,
  });

  final BattleState state;
  final Set<int> selectedIds;
  final PlacementState placement;

  final Map<String, TextPainter> _labels = {};
  final List<Actor> _visible = [];
  final Paint _fill = Paint();
  final Paint _stroke = Paint()..style = PaintingStyle.stroke;
  final Paint _outline = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.055
    ..color = const Color(0xCC15130F);

  Paint _solid(Color color) => _fill..color = color;

  Paint _outlined(Color color, double width) => _stroke
    ..color = color
    ..strokeWidth = width;

  void dispose() => _labels.clear();

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
    final outline = _outline;

    canvas.drawOval(
      Rect.fromCenter(
        center: center + const Offset(0.06, 0.1),
        width: unit.radius * 2.2,
        height: unit.radius * 1.1,
      ),
      _solid(const Color(0x55000000)),
    );
    if (selected) {
      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: unit.radius * 2.9,
          height: unit.radius * 2.0,
        ),
        _outlined(const Color(0xFFF2D27A), 0.06),
      );
    }

    switch (unit.spec.kind) {
      case UnitKind.rifle:
      case UnitKind.rocket:
        _drawInfantry(canvas, unit, teamColor, outline);
        break;
      case UnitKind.harvester:
        _drawHarvester(canvas, unit, teamColor, outline);
        break;
      case UnitKind.lightTank:
      case UnitKind.heavyTank:
        _drawTank(canvas, unit, teamColor, outline);
        break;
    }

    if (unit.hitFlash > 0) {
      canvas.drawCircle(
        center,
        unit.radius * 1.3,
        _solid(Colors.white.withValues(alpha: unit.hitFlash * 1.6)),
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

  void _drawInfantry(Canvas canvas, Unit unit, Color teamColor, Paint outline) {
    final center = Offset(unit.x, unit.y);
    canvas.drawCircle(center, 0.28, _solid(teamColor));
    canvas.drawCircle(center, 0.28, outline);
    // 头盔
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: 0.24),
      math.pi,
      math.pi,
      true,
      _solid(shadeColor(teamColor, -0.25)),
    );
    canvas.save();
    canvas.translate(unit.x, unit.y);
    canvas.rotate(unit.facing);
    final rocket = unit.spec.kind == UnitKind.rocket;
    final gunPaint = _solid(
      rocket ? const Color(0xFF2C2B28) : const Color(0xFF4A4A45),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          0.1,
          rocket ? -0.07 : -0.035,
          rocket ? 0.5 : 0.42,
          rocket ? 0.14 : 0.07,
        ),
        const Radius.circular(0.03),
      ),
      gunPaint,
    );
    if (rocket) {
      canvas.drawCircle(
        const Offset(0.55, 0),
        0.055,
        _solid(const Color(0xFF8E241B)),
      );
    }
    canvas.restore();
  }

  void _drawTank(Canvas canvas, Unit unit, Color teamColor, Paint outline) {
    final heavy = unit.spec.kind == UnitKind.heavyTank;
    final width = heavy ? 0.86 : 0.74;
    final height = heavy ? 0.72 : 0.62;
    final center = Offset(unit.x, unit.y);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(unit.facing);
    final body = Rect.fromCenter(
      center: Offset.zero,
      width: width,
      height: height,
    );
    final trackPaint = _solid(const Color(0xFF24231F));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-width / 2, -height / 2, width, height * 0.24),
        const Radius.circular(0.06),
      ),
      trackPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          -width / 2,
          height / 2 - height * 0.24,
          width,
          height * 0.24,
        ),
        const Radius.circular(0.06),
      ),
      trackPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(0.08)),
      _solid(teamColor),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(0.08)),
      outline,
    );
    canvas.drawCircle(
      Offset.zero,
      heavy ? 0.24 : 0.19,
      _solid(shadeColor(teamColor, -0.18)),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, -0.05, heavy ? 0.5 : 0.42, 0.1),
      _solid(const Color(0xFF35342F)),
    );
    canvas.restore();
  }

  void _drawHarvester(
    Canvas canvas,
    Unit unit,
    Color teamColor,
    Paint outline,
  ) {
    final center = Offset(unit.x, unit.y);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(unit.facing);
    final body = Rect.fromCenter(center: Offset.zero, width: 0.9, height: 0.66);
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(0.08)),
      _solid(teamColor),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(0.08)),
      outline,
    );
    // 矿石仓
    const bin = Rect.fromLTWH(-0.32, -0.2, 0.46, 0.4);
    canvas.drawRect(bin, _solid(const Color(0xFF3C3A33)));
    if (unit.cargo > 0) {
      canvas.drawRect(
        Rect.fromLTWH(
          bin.left + 0.02,
          bin.bottom - bin.height * unit.cargoRatio,
          bin.width - 0.04,
          bin.height * unit.cargoRatio,
        ),
        _solid(const Color(0xFFD9A94B)),
      );
    }
    canvas.drawRect(
      const Rect.fromLTWH(0.2, -0.22, 0.22, 0.44),
      _solid(shadeColor(teamColor, -0.25)),
    );
    canvas.restore();
  }

  void _drawBuilding(Canvas canvas, Building building) {
    final selected = selectedIds.contains(building.id);
    final rect = building.bounds.deflate(0.05);
    final body = RRect.fromRectAndRadius(rect, const Radius.circular(0.12));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.translate(0.08, 0.1),
        const Radius.circular(0.12),
      ),
      _solid(const Color(0x66000000)),
    );
    canvas.drawRRect(body, _solid(const Color(0xFF4B4E4A)));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          rect.left + 0.08,
          rect.top + 0.08,
          rect.width - 0.16,
          rect.height - 0.16,
        ),
        const Radius.circular(0.08),
      ),
      _solid(const Color(0xFF5B5E58)),
    );
    // 阵营色条
    canvas.drawRect(
      Rect.fromLTWH(rect.left + 0.1, rect.bottom - 0.18, rect.width - 0.2, 0.1),
      _solid(building.team.color),
    );
    _drawBuildingDetail(canvas, building, rect);
    canvas.drawRRect(body, _outlined(const Color(0xFF22211E), 0.035));
    if (selected) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect.inflate(0.08),
          const Radius.circular(0.14),
        ),
        _outlined(const Color(0xFFF2D27A), 0.06),
      );
    }
    if (building.hp < building.maxHp) {
      _drawHpBar(
        canvas,
        center: Offset(building.x, building.bounds.top - 0.16),
        width: math.min(2.4, rect.width * 0.8),
        ratio: building.hp / building.maxHp,
        color: building.team.color,
      );
    }
  }

  void _drawBuildingDetail(Canvas canvas, Building building, Rect rect) {
    final center = rect.center;
    final dark = Paint()..color = const Color(0xFF353732);
    switch (building.spec.kind) {
      case BuildingKind.hq:
        canvas.drawCircle(center, rect.width * 0.16, dark);
        canvas.drawCircle(
          center,
          rect.width * 0.1,
          Paint()..color = building.team.color,
        );
        canvas.drawLine(
          Offset(center.dx, rect.top + 0.1),
          Offset(center.dx, center.dy - rect.width * 0.16),
          Paint()
            ..color = const Color(0xFFCCC3AE)
            ..strokeWidth = 0.045,
        );
        break;
      case BuildingKind.power:
        final bolt = Path()
          ..moveTo(center.dx - 0.18, rect.top + 0.18)
          ..lineTo(center.dx + 0.08, rect.top + 0.18)
          ..lineTo(center.dx - 0.02, center.dy)
          ..lineTo(center.dx + 0.2, center.dy)
          ..lineTo(center.dx - 0.12, rect.bottom - 0.22)
          ..lineTo(center.dx - 0.02, center.dy + 0.06)
          ..lineTo(center.dx - 0.22, center.dy + 0.06)
          ..close();
        canvas.drawPath(bolt, Paint()..color = const Color(0xFFE8C36A));
        break;
      case BuildingKind.refinery:
        for (final dx in [
          rect.left + rect.width * 0.26,
          rect.right - rect.width * 0.26,
        ]) {
          canvas.drawCircle(Offset(dx, center.dy), rect.height * 0.22, dark);
          canvas.drawCircle(
            Offset(dx, center.dy),
            rect.height * 0.14,
            Paint()..color = const Color(0xFF8A7A55),
          );
        }
        break;
      case BuildingKind.barracks:
        canvas.drawRect(
          Rect.fromLTWH(
            rect.left + 0.2,
            rect.bottom - 0.34,
            rect.width - 0.4,
            0.2,
          ),
          dark,
        );
        for (var i = 0; i < 3; i++) {
          canvas.drawRect(
            Rect.fromLTWH(
              rect.left + 0.16 + i * (rect.width - 0.32) / 3,
              rect.top + 0.14,
              (rect.width - 0.32) / 3 - 0.03,
              0.16,
            ),
            Paint()..color = const Color(0xFF6D6F66),
          );
        }
        break;
      case BuildingKind.factory:
        canvas.drawRect(
          Rect.fromLTWH(
            rect.left + rect.width * 0.18,
            center.dy - 0.05,
            rect.width * 0.64,
            rect.height * 0.38,
          ),
          dark,
        );
        canvas.drawLine(
          Offset(rect.left + 0.15, rect.top + 0.16),
          Offset(rect.right - 0.15, rect.top + 0.16),
          Paint()
            ..color = const Color(0xFFD9A94B)
            ..strokeWidth = 0.07,
        );
        break;
      case BuildingKind.tower:
        canvas.drawCircle(center, rect.width * 0.3, dark);
        canvas.drawCircle(
          center,
          rect.width * 0.2,
          Paint()..color = building.team.color,
        );
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(building.facing);
        canvas.drawRect(
          Rect.fromLTWH(0, -0.05, rect.width * 0.42, 0.1),
          Paint()..color = const Color(0xFF2B2A26),
        );
        canvas.restore();
        break;
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
      _solid(const Color(0xCC16140F)),
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
      _solid(color),
    );
  }

  // ===== 放置预览 =====

  void drawGhost(Canvas canvas) {
    final spec = placement.spec;
    final tile = placement.tile;
    if (spec == null || tile == null) return;
    final color = placement.valid
        ? const Color(0xFF6FCF7A)
        : const Color(0xFFE0604F);
    final rect = Rect.fromLTWH(
      tile.x.toDouble(),
      tile.y.toDouble(),
      spec.width.toDouble(),
      spec.height.toDouble(),
    );
    canvas.drawRect(rect, Paint()..color = color.withValues(alpha: 0.22));
    canvas.drawRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.09
        ..color = color,
    );
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
    final viewport = Rect.fromLTWH(
      0,
      0,
      camera.viewport.width,
      camera.viewport.height,
    );
    for (final building in state.redBuildings) {
      _drawBuildingLabel(canvas, camera, viewport, fontSize, building);
    }
    for (final building in state.blueBuildings) {
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
    painter.paint(
      canvas,
      screen - Offset(painter.width / 2, painter.height / 2),
    );
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
