import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../game/battle_camera.dart';
import '../game/battle_controller.dart';
import '../game/battle_state.dart';
import '../game/battle_types.dart';
import '../game/entity.dart';
import '../game/logic_rate.dart';
import '../services/sound_service.dart';
import '../theme/palette.dart';
import '../utils/constants.dart';
import 'effects.dart';

/// Flame 渲染与逻辑入口：固定步长推进战场，按摄像机变换绘制地形、单位与特效。
///
/// 交互全部由页面层的 Flutter 手势转成 [BattleController] 指令，这里只负责
/// 呈现，避免触摸命中与画面坐标系出现偏差。
class BattleGame extends FlameGame {
  BattleGame({required this.controller, required this.logicRate})
    : _clock = FixedStepClock(logicRate.step);

  final BattleController controller;
  final LogicRate logicRate;

  final Effects effects = Effects();
  final FixedStepClock _clock;

  ui.Picture? _terrain;
  int _terrainVersion = -1;
  ui.Shader? _edgeShader;
  Size _edgeShaderSize = Size.zero;
  final Map<String, TextPainter> _labels = {};
  double _fireSoundGap = 0;

  BattleState get state => controller.state;

  @override
  Color backgroundColor() => const Color(0xFF0E0F0E);

  @override
  Future<void> onLoad() async {
    controller.camera.updateViewport(Size(size.x, size.y));
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    controller.camera.updateViewport(Size(size.x, size.y));
  }

  @override
  void update(double dt) {
    final step = dt.clamp(0.0, 0.1);
    effects.update(step);
    if (_fireSoundGap > 0) _fireSoundGap -= step;
    if (!controller.paused) {
      _clock.advance(step, controller.tick);
      _consumeEvents();
    }
    super.update(dt);
  }

  void _consumeEvents() {
    for (final event in state.drainEvents()) {
      effects.addEvent(event);
      switch (event.kind) {
        case BattleEventKind.bullet:
        case BattleEventKind.shell:
          if (_fireSoundGap <= 0 && event.team == playerTeam) {
            _fireSoundGap = 0.12;
            SoundService.play(BattleFeedback.fire);
          }
          break;
        case BattleEventKind.explosion:
          SoundService.play(BattleFeedback.explosion);
          break;
        case BattleEventKind.build:
          SoundService.play(BattleFeedback.build);
          break;
        case BattleEventKind.spawn:
          SoundService.play(BattleFeedback.ready);
          break;
        case BattleEventKind.unload:
          SoundService.play(BattleFeedback.harvest);
          break;
        case BattleEventKind.move:
          break;
      }
    }
  }

  @override
  void onDispose() {
    effects.clear();
    _terrain?.dispose();
    _terrain = null;
    super.onDispose();
  }

  @override
  void render(Canvas canvas) {
    final camera = controller.camera;
    if (camera.viewport.isEmpty || camera.tileSize <= 0) return;
    final viewport = Rect.fromLTWH(
      0,
      0,
      camera.viewport.width,
      camera.viewport.height,
    );
    canvas.drawRect(viewport, Paint()..color = const Color(0xFF0E0F0E));

    final origin = camera.worldToScreen(Offset.zero);
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(camera.tileSize);
    canvas.clipRect(
      Rect.fromLTWH(0, 0, state.map.width.toDouble(), state.map.height.toDouble()),
    );
    _drawTerrain(canvas);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, state.map.width.toDouble(), state.map.height.toDouble()),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4 / camera.tileSize
        ..color = const Color(0xFF3A3630),
    );
    _drawActors(canvas);
    _drawGhost(canvas);
    effects.render(canvas, camera.tileSize);
    canvas.restore();

    _drawBuildingLabels(canvas);
    _drawEdgeFade(canvas, camera);
    super.render(canvas);
  }

  // ===== 地形 =====

  void _drawTerrain(Canvas canvas) {
    if (_terrain == null || _terrainVersion != state.map.version) {
      _terrain?.dispose();
      _terrain = _buildTerrain();
      _terrainVersion = state.map.version;
    }
    canvas.drawPicture(_terrain!);
  }

  ui.Picture _buildTerrain() {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final map = state.map;
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.012
      ..color = const Color(0x14FFFFFF);
    for (var y = 0; y < map.height; y++) {
      for (var x = 0; x < map.width; x++) {
        final kind = map.terrainAt(x, y);
        final noise = _hash(x, y);
        final base = terrainColor(kind);
        final rect = Rect.fromLTWH(x.toDouble(), y.toDouble(), 1.01, 1.01);
        canvas.drawRect(rect, Paint()..color = _shade(base, noise * 0.12 - 0.06));
        switch (kind) {
          case TerrainKind.grass:
            _paintGrass(canvas, x, y, noise);
            break;
          case TerrainKind.dirt:
            _paintDirt(canvas, x, y, noise);
            break;
          case TerrainKind.road:
            _paintRoad(canvas, x, y);
            break;
          case TerrainKind.water:
            _paintWater(canvas, x, y, noise);
            break;
          case TerrainKind.rock:
            _paintRock(canvas, x, y, noise);
            break;
          case TerrainKind.ore:
            _paintOre(canvas, x, y, map.oreAt(x, y), noise);
            break;
        }
        canvas.drawRect(rect, gridPaint);
      }
    }
    return recorder.endRecording();
  }

  void _paintGrass(Canvas canvas, int x, int y, double noise) {
    final paint = Paint()
      ..color = terrainHighlight(TerrainKind.grass).withValues(alpha: 0.45)
      ..strokeWidth = 0.045
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final fx = x + 0.15 + _hash(x + i * 7, y + i) * 0.7;
      final fy = y + 0.2 + _hash(x + i, y + i * 5) * 0.65;
      canvas.drawLine(
        Offset(fx, fy),
        Offset(fx + 0.05, fy - 0.14),
        paint,
      );
    }
    if (noise > 0.85) {
      canvas.drawCircle(
        Offset(x + 0.7, y + 0.3),
        0.12,
        Paint()..color = const Color(0x22552F1E),
      );
    }
  }

  void _paintDirt(Canvas canvas, int x, int y, double noise) {
    final paint = Paint()..color = const Color(0x33604A33);
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(
        Offset(
          x + 0.2 + _hash(x + i * 3, y + 9) * 0.6,
          y + 0.2 + _hash(x + 5, y + i * 3) * 0.6,
        ),
        0.035 + noise * 0.04,
        paint,
      );
    }
  }

  void _paintRoad(Canvas canvas, int x, int y) {
    if ((x + y) % 4 != 0) return;
    canvas.drawRect(
      Rect.fromLTWH(x + 0.1, y + 0.47, 0.8, 0.045),
      Paint()..color = const Color(0x55E7DCC2),
    );
  }

  void _paintWater(Canvas canvas, int x, int y, double noise) {
    final paint = Paint()
      ..color = terrainHighlight(TerrainKind.water).withValues(alpha: 0.6)
      ..strokeWidth = 0.05
      ..strokeCap = StrokeCap.round;
    final yOffset = 0.3 + noise * 0.3;
    canvas.drawLine(
      Offset(x + 0.2, y + yOffset),
      Offset(x + 0.55, y + yOffset),
      paint,
    );
    canvas.drawLine(
      Offset(x + 0.55, y + yOffset + 0.25),
      Offset(x + 0.85, y + yOffset + 0.25),
      paint,
    );
  }

  void _paintRock(Canvas canvas, int x, int y, double noise) {
    final path = Path()
      ..moveTo(x + 0.15, y + 0.8)
      ..lineTo(x + 0.32, y + 0.25 + noise * 0.1)
      ..lineTo(x + 0.72, y + 0.2)
      ..lineTo(x + 0.9, y + 0.7)
      ..lineTo(x + 0.6, y + 0.88)
      ..close();
    canvas.drawPath(path, Paint()..color = terrainColor(TerrainKind.rock));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.035
        ..color = terrainHighlight(TerrainKind.rock),
    );
  }

  void _paintOre(Canvas canvas, int x, int y, int amount, double noise) {
    _paintDirt(canvas, x, y, noise);
    final ratio = (amount / 2600).clamp(0.25, 1.0);
    final glow = Paint()..color = const Color(0x66D9A94B);
    canvas.drawCircle(Offset(x + 0.5, y + 0.5), 0.3 * ratio, glow);
    for (var i = 0; i < 4; i++) {
      final cx = x + 0.2 + _hash(x + i * 13, y + 3) * 0.6;
      final cy = y + 0.2 + _hash(x + 7, y + i * 11) * 0.6;
      final size = 0.07 + 0.1 * ratio;
      final path = Path()
        ..moveTo(cx, cy - size)
        ..lineTo(cx + size * 0.8, cy)
        ..lineTo(cx, cy + size)
        ..lineTo(cx - size * 0.8, cy)
        ..close();
      canvas.drawPath(path, Paint()..color = const Color(0xFFE7C065));
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.018
          ..color = const Color(0xFF8A6420),
      );
    }
  }

  Color _shade(Color color, double amount) {
    if (amount >= 0) return Color.lerp(color, Colors.white, amount)!;
    return Color.lerp(color, Colors.black, -amount)!;
  }

  double _hash(int x, int y) {
    final value = math.sin(x * 12.9898 + y * 78.233) * 43758.5453;
    return value - value.floor();
  }

  // ===== 单位与建筑 =====

  void _drawActors(Canvas canvas) {
    final actors = List<Actor>.of(state.actors)
      ..sort((a, b) => a.y.compareTo(b.y));
    for (final actor in actors) {
      if (!actor.alive) continue;
      if (actor is Building) {
        _drawBuilding(canvas, actor);
      } else if (actor is Unit) {
        _drawUnit(canvas, actor);
      }
    }
  }

  void _drawUnit(Canvas canvas, Unit unit) {
    final selected = controller.selectedIds.contains(unit.id);
    final center = Offset(unit.x, unit.y);
    final teamColor = unit.team.color;
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.055
      ..color = const Color(0xCC15130F);

    canvas.drawOval(
      Rect.fromCenter(
        center: center + const Offset(0.06, 0.1),
        width: unit.radius * 2.2,
        height: unit.radius * 1.1,
      ),
      Paint()..color = const Color(0x55000000),
    );
    if (selected) {
      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: unit.radius * 2.9,
          height: unit.radius * 2.0,
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.06
          ..color = const Color(0xFFF2D27A),
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
        Paint()..color = Colors.white.withValues(alpha: unit.hitFlash * 1.6),
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

  void _drawInfantry(
    Canvas canvas,
    Unit unit,
    Color teamColor,
    Paint outline,
  ) {
    final center = Offset(unit.x, unit.y);
    canvas.drawCircle(center, 0.28, Paint()..color = teamColor);
    canvas.drawCircle(center, 0.28, outline);
    // 头盔
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: 0.24),
      math.pi,
      math.pi,
      true,
      Paint()..color = _shade(teamColor, -0.25),
    );
    canvas.save();
    canvas.translate(unit.x, unit.y);
    canvas.rotate(unit.facing);
    final gunPaint = Paint()
      ..color = unit.spec.kind == UnitKind.rocket
          ? const Color(0xFF2C2B28)
          : const Color(0xFF4A4A45);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          0.1,
          unit.spec.kind == UnitKind.rocket ? -0.07 : -0.035,
          unit.spec.kind == UnitKind.rocket ? 0.5 : 0.42,
          unit.spec.kind == UnitKind.rocket ? 0.14 : 0.07,
        ),
        const Radius.circular(0.03),
      ),
      gunPaint,
    );
    if (unit.spec.kind == UnitKind.rocket) {
      canvas.drawCircle(
        const Offset(0.55, 0),
        0.055,
        Paint()..color = const Color(0xFF8E241B),
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
    final trackPaint = Paint()..color = const Color(0xFF24231F);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-width / 2, -height / 2, width, height * 0.24),
        const Radius.circular(0.06),
      ),
      trackPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-width / 2, height / 2 - height * 0.24, width, height * 0.24),
        const Radius.circular(0.06),
      ),
      trackPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(0.08)),
      Paint()..color = teamColor,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(0.08)),
      outline,
    );
    canvas.drawCircle(
      Offset(0, 0),
      heavy ? 0.24 : 0.19,
      Paint()..color = _shade(teamColor, -0.18),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, -0.05, heavy ? 0.5 : 0.42, 0.1),
      Paint()..color = const Color(0xFF35342F),
    );
    canvas.restore();
  }

  void _drawHarvester(Canvas canvas, Unit unit, Color teamColor, Paint outline) {
    final center = Offset(unit.x, unit.y);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(unit.facing);
    final body = Rect.fromCenter(center: Offset.zero, width: 0.9, height: 0.66);
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(0.08)),
      Paint()..color = teamColor,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(0.08)),
      outline,
    );
    // 矿石仓
    final bin = Rect.fromLTWH(-0.32, -0.2, 0.46, 0.4);
    canvas.drawRect(bin, Paint()..color = const Color(0xFF3C3A33));
    if (unit.cargo > 0) {
      canvas.drawRect(
        Rect.fromLTWH(
          bin.left + 0.02,
          bin.bottom - bin.height * unit.cargoRatio,
          bin.width - 0.04,
          bin.height * unit.cargoRatio,
        ),
        Paint()..color = const Color(0xFFD9A94B),
      );
    }
    canvas.drawRect(
      Rect.fromLTWH(0.2, -0.22, 0.22, 0.44),
      Paint()..color = _shade(teamColor, -0.25),
    );
    canvas.restore();
  }

  void _drawBuilding(Canvas canvas, Building building) {
    final selected = controller.selectedIds.contains(building.id);
    final rect = building.bounds.deflate(0.05);
    final body = RRect.fromRectAndRadius(rect, const Radius.circular(0.12));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.translate(0.08, 0.1),
        const Radius.circular(0.12),
      ),
      Paint()..color = const Color(0x66000000),
    );
    canvas.drawRRect(body, Paint()..color = const Color(0xFF4B4E4A));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(rect.left + 0.08, rect.top + 0.08, rect.width - 0.16, rect.height - 0.16),
        const Radius.circular(0.08),
      ),
      Paint()..color = const Color(0xFF5B5E58),
    );
    // 阵营色条
    canvas.drawRect(
      Rect.fromLTWH(rect.left + 0.1, rect.bottom - 0.18, rect.width - 0.2, 0.1),
      Paint()..color = building.team.color,
    );
    _drawBuildingDetail(canvas, building, rect);
    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.035
        ..color = const Color(0xFF22211E),
    );
    if (selected) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect.inflate(0.08),
          const Radius.circular(0.14),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.06
          ..color = const Color(0xFFF2D27A),
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
        canvas.drawCircle(
          Offset(rect.left + rect.width * 0.26, center.dy),
          rect.height * 0.22,
          dark,
        );
        canvas.drawCircle(
          Offset(rect.left + rect.width * 0.26, center.dy),
          rect.height * 0.14,
          Paint()..color = const Color(0xFF8A7A55),
        );
        canvas.drawCircle(
          Offset(rect.right - rect.width * 0.26, center.dy),
          rect.height * 0.22,
          dark,
        );
        canvas.drawCircle(
          Offset(rect.right - rect.width * 0.26, center.dy),
          rect.height * 0.14,
          Paint()..color = const Color(0xFF8A7A55),
        );
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
        canvas.drawCircle(center, rect.width * 0.2, Paint()..color = building.team.color);
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
    final rect = Rect.fromCenter(
      center: center,
      width: width,
      height: 0.11,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(0.03)),
      Paint()..color = const Color(0xCC16140F),
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
      Paint()..color = color,
    );
  }

  // ===== 放置预览 =====

  void _drawGhost(Canvas canvas) {
    if (!controller.isPlacing) return;
    final spec = controller.placingSpec;
    final tile = controller.ghostTile;
    if (spec == null || tile == null) return;
    final valid = controller.ghostValid;
    final color = valid ? const Color(0xFF6FCF7A) : const Color(0xFFE0604F);
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
    for (var i = 1; i < spec.width; i++) {
      canvas.drawLine(
        Offset(tile.x + i.toDouble(), rect.top),
        Offset(tile.x + i.toDouble(), rect.bottom),
        Paint()
          ..color = color.withValues(alpha: 0.45)
          ..strokeWidth = 0.03,
      );
    }
    for (var i = 1; i < spec.height; i++) {
      canvas.drawLine(
        Offset(rect.left, tile.y + i.toDouble()),
        Offset(rect.right, tile.y + i.toDouble()),
        Paint()
          ..color = color.withValues(alpha: 0.45)
          ..strokeWidth = 0.03,
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

  void _drawBuildingLabels(Canvas canvas) {
    final camera = controller.camera;
    if (camera.tileSize < 13) return;
    final fontSize = (camera.tileSize * 0.52).clamp(8.0, 18.0);
    for (final building in state.actors.whereType<Building>()) {
      if (!building.alive) continue;
      final screen = camera.worldToScreen(Offset(building.x, building.y));
      if (!Rect.fromLTWH(
        0,
        0,
        camera.viewport.width,
        camera.viewport.height,
      ).contains(screen)) {
        continue;
      }
      final painter = _labelPainter(building.spec.icon, fontSize);
      painter.paint(
        canvas,
        screen - Offset(painter.width / 2, painter.height / 2),
      );
    }
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
            shadows: const [
              Shadow(color: Color(0xCC000000), blurRadius: 4),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    });
  }

  void _drawEdgeFade(Canvas canvas, BattleCamera camera) {
    final size = camera.viewport;
    if (size.isEmpty) return;
    if (_edgeShader == null || _edgeShaderSize != size) {
      _edgeShader = ui.Gradient.linear(
        Offset(0, 0),
        Offset(0, size.height),
        const [
          Color(0x88000000),
          Color(0x00000000),
          Color(0x00000000),
          Color(0x99000000),
        ],
        const [0.0, 0.16, 0.78, 1.0],
      );
      _edgeShaderSize = size;
    }
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = _edgeShader,
    );
  }
}
