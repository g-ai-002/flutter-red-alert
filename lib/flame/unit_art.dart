import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../game/battle_types.dart';
import '../game/entity.dart';
import 'paint_utils.dart';

/// 单位造型：按「类型 + 阵营」录制成 [ui.Picture]，绘制时只做平移与旋转；
/// 步兵的头盔不随朝向转动，身体与武器分成两张缓存。
class UnitArt {
  UnitArt(this.brush);

  final ArtBrush brush;
  final Map<int, ui.Picture> _bodies = {};
  final Map<int, ui.Picture> _weapons = {};

  @visibleForTesting
  int get cachedPictures => _bodies.length + _weapons.length;

  void paint(Canvas canvas, Unit unit, Paint outline) {
    final spec = unit.spec;
    final key = spec.kind.index * 2 + unit.team.index;
    canvas.save();
    canvas.translate(unit.x, unit.y);
    if (spec.category == ProductionCategory.infantry) {
      canvas.drawPicture(_bodies[key] ??= _recordBody(spec, unit.team, outline));
      canvas.rotate(unit.facing);
      canvas.drawPicture(_weapons[key] ??= _recordWeapon(spec, unit.team));
    } else {
      canvas.rotate(unit.facing);
      canvas.drawPicture(_bodies[key] ??= _recordBody(spec, unit.team, outline));
      if (spec.isHarvester) _harvesterCargo(canvas, unit.cargoRatio);
    }
    canvas.restore();
  }

  void dispose() {
    for (final picture in [..._bodies.values, ..._weapons.values]) {
      picture.dispose();
    }
    _bodies.clear();
    _weapons.clear();
  }

  ui.Picture _recordBody(UnitSpec spec, Team team, Paint outline) {
    return _record((canvas) {
      switch (spec.kind) {
        case UnitKind.rifle:
        case UnitKind.rocket:
          _infantryBody(canvas, team.color, outline);
          break;
        case UnitKind.engineer:
          _engineerBody(canvas, team.color, outline);
          break;
        case UnitKind.harvester:
          _harvesterBody(canvas, team.color, outline);
          break;
        case UnitKind.lightTank:
        case UnitKind.heavyTank:
          _tankBody(canvas, spec, team.color, outline);
          break;
        case UnitKind.artillery:
          _artilleryBody(canvas, team.color, outline);
          break;
        case UnitKind.gunship:
          _gunshipBody(canvas, team.color, outline);
          break;
      }
    });
  }

  ui.Picture _recordWeapon(UnitSpec spec, Team team) =>
      _record((canvas) => _infantryWeapon(canvas, spec, team.color));

  ui.Picture _record(void Function(Canvas canvas) draw) {
    final recorder = ui.PictureRecorder();
    draw(Canvas(recorder));
    return recorder.endRecording();
  }

  void _infantryBody(Canvas canvas, Color teamColor, Paint outline) {
    canvas.drawCircle(Offset.zero, 0.28, brush.solid(teamColor));
    canvas.drawCircle(Offset.zero, 0.28, outline);
    canvas.drawArc(
      const Rect.fromLTRB(-0.24, -0.24, 0.24, 0.24),
      math.pi,
      math.pi,
      true,
      brush.solid(shadeColor(teamColor, -0.25)),
    );
  }

  void _engineerBody(Canvas canvas, Color teamColor, Paint outline) {
    canvas.drawCircle(Offset.zero, 0.28, brush.solid(teamColor));
    canvas.drawCircle(Offset.zero, 0.28, outline);
    // 黄色安全帽，便于在步兵群里一眼认出工兵。
    canvas.drawArc(
      const Rect.fromLTRB(-0.24, -0.24, 0.24, 0.24),
      math.pi,
      math.pi,
      true,
      brush.solid(const Color(0xFFE8C36A)),
    );
    canvas.drawRect(
      const Rect.fromLTWH(-0.06, 0.02, 0.12, 0.2),
      brush.solid(const Color(0xFF8C8C86)),
    );
  }

  void _infantryWeapon(Canvas canvas, UnitSpec spec, Color teamColor) {
    if (spec.kind == UnitKind.engineer) {
      // 扳手：短柄加开口环。
      canvas.drawRect(
        const Rect.fromLTWH(0.1, -0.03, 0.24, 0.06),
        brush.solid(const Color(0xFF9A9A92)),
      );
      canvas.drawCircle(
        const Offset(0.38, 0),
        0.08,
        brush.outlined(const Color(0xFFC6C6BC), 0.035),
      );
      return;
    }
    final rocket = spec.kind == UnitKind.rocket;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0.1, rocket ? -0.07 : -0.035, rocket ? 0.5 : 0.42, rocket ? 0.14 : 0.07),
        const Radius.circular(0.03),
      ),
      brush.solid(rocket ? const Color(0xFF2C2B28) : const Color(0xFF4A4A45)),
    );
    if (rocket) {
      canvas.drawCircle(const Offset(0.55, 0), 0.055, brush.solid(const Color(0xFF8E241B)));
    }
  }

  void _tankBody(Canvas canvas, UnitSpec spec, Color teamColor, Paint outline) {
    final heavy = spec.kind == UnitKind.heavyTank;
    final width = heavy ? 0.86 : 0.74;
    final height = heavy ? 0.72 : 0.62;
    final body = Rect.fromCenter(center: Offset.zero, width: width, height: height);
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
    canvas.drawRRect(RRect.fromRectAndRadius(body, const Radius.circular(0.08)), outline);
    canvas.drawCircle(Offset.zero, heavy ? 0.24 : 0.19, brush.solid(shadeColor(teamColor, -0.18)));
    canvas.drawRect(
      Rect.fromLTWH(0, -0.05, heavy ? 0.5 : 0.42, 0.1),
      brush.solid(const Color(0xFF35342F)),
    );
  }

  void _artilleryBody(Canvas canvas, Color teamColor, Paint outline) {
    const width = 0.82;
    const height = 0.6;
    final body = Rect.fromCenter(center: Offset.zero, width: width, height: height);
    final track = brush.solid(const Color(0xFF24231F));
    for (final top in [-height / 2, height / 2 - height * 0.22]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-width / 2, top, width, height * 0.22),
          const Radius.circular(0.05),
        ),
        track,
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(0.07)),
      brush.solid(teamColor),
    );
    canvas.drawRRect(RRect.fromRectAndRadius(body, const Radius.circular(0.07)), outline);
    // 低矮炮塔与超长身管，是自行火炮最好认的轮廓。
    canvas.drawCircle(const Offset(-0.04, 0), 0.17, brush.solid(shadeColor(teamColor, -0.2)));
    canvas.drawRect(
      const Rect.fromLTWH(-0.04, -0.05, 0.86, 0.1),
      brush.solid(const Color(0xFF35342F)),
    );
    canvas.drawRect(
      const Rect.fromLTWH(0.62, -0.08, 0.12, 0.16),
      brush.solid(const Color(0xFF24231F)),
    );
  }

  void _gunshipBody(Canvas canvas, Color teamColor, Paint outline) {
    final dark = brush.solid(const Color(0xFF2B2A26));
    // 尾梁、尾桨与短翼，构成直升机的十字轮廓。
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-0.66, -0.045, 0.7, 0.09),
        const Radius.circular(0.04),
      ),
      dark,
    );
    canvas.drawRect(const Rect.fromLTWH(-0.68, -0.16, 0.08, 0.32), dark);
    canvas.drawRect(const Rect.fromLTWH(-0.1, -0.3, 0.3, 0.1), dark);
    canvas.drawRect(const Rect.fromLTWH(-0.1, 0.2, 0.3, 0.1), dark);
    // 机身与座舱。
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0.02, 0), width: 0.6, height: 0.42),
      brush.solid(teamColor),
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0.02, 0), width: 0.6, height: 0.42),
      outline,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0.2, 0), width: 0.26, height: 0.22),
      brush.solid(const Color(0xFF8FB6C4)),
    );
    // 旋翼：两层半透明椭圆加一根桨叶。
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 1.12, height: 0.16),
      brush.solid(const Color(0x55E8E8E0)),
    );
    canvas.drawLine(
      const Offset(-0.52, 0),
      const Offset(0.52, 0),
      brush.outlined(const Color(0x99F0F0E8), 0.035),
    );
    // 滑橇。
    for (final y in [-0.26, 0.2]) {
      canvas.drawLine(
        Offset(-0.16, y),
        Offset(0.28, y),
        brush.outlined(const Color(0xFF35342F), 0.045),
      );
    }
  }

  void _harvesterBody(Canvas canvas, Color teamColor, Paint outline) {
    final body = Rect.fromCenter(center: Offset.zero, width: 0.9, height: 0.66);
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(0.08)),
      brush.solid(teamColor),
    );
    canvas.drawRRect(RRect.fromRectAndRadius(body, const Radius.circular(0.08)), outline);
    // 矿石仓：仓位随载货量填充，填充部分由 _harvesterCargo 逐帧绘制。
    canvas.drawRect(_cargoBin, brush.solid(const Color(0xFF3C3A33)));
    canvas.drawRect(
      const Rect.fromLTWH(0.2, -0.22, 0.22, 0.44),
      brush.solid(shadeColor(teamColor, -0.25)),
    );
  }

  static const Rect _cargoBin = Rect.fromLTWH(-0.32, -0.2, 0.46, 0.4);

  void _harvesterCargo(Canvas canvas, double ratio) {
    if (ratio <= 0) return;
    canvas.drawRect(
      Rect.fromLTWH(
        _cargoBin.left + 0.02,
        _cargoBin.bottom - _cargoBin.height * ratio,
        _cargoBin.width - 0.04,
        _cargoBin.height * ratio,
      ),
      brush.solid(const Color(0xFFD9A94B)),
    );
  }
}
