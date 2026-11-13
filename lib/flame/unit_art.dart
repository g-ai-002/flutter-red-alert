import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/battle_types.dart';
import '../game/entity.dart';
import 'paint_utils.dart';

/// 单位造型：步兵、坦克与采矿车的世界坐标绘制，机甲朝向跟着 [Unit.facing]。
class UnitArt {
  UnitArt(this.brush);

  final ArtBrush brush;

  void paint(Canvas canvas, Unit unit, Paint outline) {
    final color = unit.team.color;
    switch (unit.spec.kind) {
      case UnitKind.rifle:
      case UnitKind.rocket:
        _infantry(canvas, unit, color, outline);
        break;
      case UnitKind.harvester:
        _harvester(canvas, unit, color, outline);
        break;
      case UnitKind.lightTank:
      case UnitKind.heavyTank:
        _tank(canvas, unit, color, outline);
        break;
    }
  }

  void _infantry(Canvas canvas, Unit unit, Color teamColor, Paint outline) {
    final center = Offset(unit.x, unit.y);
    canvas.drawCircle(center, 0.28, brush.solid(teamColor));
    canvas.drawCircle(center, 0.28, outline);
    // 头盔
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: 0.24),
      math.pi,
      math.pi,
      true,
      brush.solid(shadeColor(teamColor, -0.25)),
    );
    canvas.save();
    canvas.translate(unit.x, unit.y);
    canvas.rotate(unit.facing);
    final rocket = unit.spec.kind == UnitKind.rocket;
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
      brush.solid(
        rocket ? const Color(0xFF2C2B28) : const Color(0xFF4A4A45),
      ),
    );
    if (rocket) {
      canvas.drawCircle(
        const Offset(0.55, 0),
        0.055,
        brush.solid(const Color(0xFF8E241B)),
      );
    }
    canvas.restore();
  }

  void _tank(Canvas canvas, Unit unit, Color teamColor, Paint outline) {
    final heavy = unit.spec.kind == UnitKind.heavyTank;
    final width = heavy ? 0.86 : 0.74;
    final height = heavy ? 0.72 : 0.62;
    canvas.save();
    canvas.translate(unit.x, unit.y);
    canvas.rotate(unit.facing);
    final body = Rect.fromCenter(
      center: Offset.zero,
      width: width,
      height: height,
    );
    final track = brush.solid(const Color(0xFF24231F));
    for (final top in [-height / 2, height / 2 - height * 0.24]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-width / 2, top, width, height * 0.24),
          const Radius.circular(0.06),
        ),
        track,
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(0.08)),
      brush.solid(teamColor),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(0.08)),
      outline,
    );
    canvas.drawCircle(
      Offset.zero,
      heavy ? 0.24 : 0.19,
      brush.solid(shadeColor(teamColor, -0.18)),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, -0.05, heavy ? 0.5 : 0.42, 0.1),
      brush.solid(const Color(0xFF35342F)),
    );
    canvas.restore();
  }

  void _harvester(Canvas canvas, Unit unit, Color teamColor, Paint outline) {
    canvas.save();
    canvas.translate(unit.x, unit.y);
    canvas.rotate(unit.facing);
    final body = Rect.fromCenter(center: Offset.zero, width: 0.9, height: 0.66);
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(0.08)),
      brush.solid(teamColor),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(0.08)),
      outline,
    );
    // 矿石仓：随载货量填充。
    const bin = Rect.fromLTWH(-0.32, -0.2, 0.46, 0.4);
    canvas.drawRect(bin, brush.solid(const Color(0xFF3C3A33)));
    if (unit.cargo > 0) {
      canvas.drawRect(
        Rect.fromLTWH(
          bin.left + 0.02,
          bin.bottom - bin.height * unit.cargoRatio,
          bin.width - 0.04,
          bin.height * unit.cargoRatio,
        ),
        brush.solid(const Color(0xFFD9A94B)),
      );
    }
    canvas.drawRect(
      const Rect.fromLTWH(0.2, -0.22, 0.22, 0.44),
      brush.solid(shadeColor(teamColor, -0.25)),
    );
    canvas.restore();
  }
}
