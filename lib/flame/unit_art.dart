import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../game/battle_types.dart';
import '../game/entity.dart';
import 'paint_utils.dart';

/// 单位造型：按「类型 + 阵营」录制成 [ui.Picture]，绘制时只做平移与旋转；
/// 步兵的身体与武器分成两张缓存，头盔不随朝向转动。
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

  void _rect(Canvas c, Rect r, Color color) => c.drawRect(r, brush.solid(color));

  void _round(Canvas c, Rect r, double radius, Color color) =>
      c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(radius)), brush.solid(color));

  void _circle(Canvas c, Offset o, double radius, Color color) =>
      c.drawCircle(o, radius, brush.solid(color));

  void _line(Canvas c, Offset a, Offset b, Color color, double width) =>
      c.drawLine(a, b, brush.outlined(color, width));

  ui.Picture _recordBody(UnitSpec spec, Team team, Paint outline) =>
      _record((canvas) => switch (spec.kind) {
        UnitKind.rifle || UnitKind.rocket => _infantryBody(canvas, team.color, outline),
        UnitKind.engineer => _engineerBody(canvas, team.color, outline),
        UnitKind.harvester => _harvesterBody(canvas, team.color, outline),
        UnitKind.lightTank || UnitKind.heavyTank => _tankBody(canvas, spec, team.color, outline),
        UnitKind.artillery => _artilleryBody(canvas, team.color, outline),
        UnitKind.gunship => _gunshipBody(canvas, team.color, outline),
      });

  ui.Picture _recordWeapon(UnitSpec spec, Team team) =>
      _record((canvas) => _infantryWeapon(canvas, spec, team.color));

  ui.Picture _record(void Function(Canvas canvas) draw) {
    final recorder = ui.PictureRecorder();
    draw(Canvas(recorder));
    return recorder.endRecording();
  }

  /// 步兵：背包、双肩与头盔叠出俯视轮廓，比单个圆点更容易分辨阵营。
  void _infantryBody(Canvas canvas, Color teamColor, Paint outline, {Color? helmet}) {
    final pack = Rect.fromCenter(center: const Offset(-0.03, 0.1), width: 0.48, height: 0.34);
    _round(canvas, pack, 0.1, shadeColor(teamColor, -0.32));
    for (final dx in [-0.22, 0.22]) {
      final shoulder = Rect.fromCenter(center: Offset(dx, 0.02), width: 0.22, height: 0.3);
      canvas.drawOval(shoulder, brush.solid(shadeColor(teamColor, -0.1)));
      canvas.drawOval(shoulder, outline);
    }
    final base = helmet ?? teamColor;
    _circle(canvas, Offset.zero, 0.3, base);
    canvas.drawCircle(Offset.zero, 0.3, outline);
    canvas.drawArc(
      const Rect.fromLTRB(-0.27, -0.27, 0.27, 0.27),
      math.pi * 1.04,
      math.pi * 0.92,
      true,
      brush.solid(shadeColor(base, -0.34)),
    );
    _circle(canvas, const Offset(-0.07, -0.07), 0.06, shadeColor(base, 0.35));
    _rect(canvas, const Rect.fromLTWH(-0.3, 0.16, 0.6, 0.055), shadeColor(teamColor, 0.12));
  }

  void _engineerBody(Canvas canvas, Color teamColor, Paint outline) {
    _infantryBody(canvas, teamColor, outline, helmet: const Color(0xFFE8C36A));
    _round(canvas, const Rect.fromLTWH(0.1, 0.14, 0.24, 0.16), 0.03, const Color(0xFFB8873B));
    _rect(canvas, const Rect.fromLTWH(0.17, 0.11, 0.1, 0.04), const Color(0xFF6E511F));
  }

  void _infantryWeapon(Canvas canvas, UnitSpec spec, Color teamColor) {
    if (spec.kind == UnitKind.engineer) {
      _rect(canvas, const Rect.fromLTWH(0.06, -0.035, 0.26, 0.07), const Color(0xFF9A9A92));
      canvas.drawCircle(
        const Offset(0.36, 0),
        0.09,
        brush.outlined(const Color(0xFFC6C6BC), 0.04),
      );
      _rect(canvas, const Rect.fromLTWH(0.32, -0.025, 0.07, 0.05), const Color(0xFFC6C6BC));
      return;
    }
    final rocket = spec.kind == UnitKind.rocket;
    _rect(canvas, const Rect.fromLTWH(0.02, -0.045, 0.2, 0.09), const Color(0xFF6E4B2F));
    final receiver = Rect.fromLTWH(0.14, rocket ? -0.08 : -0.045, rocket ? 0.42 : 0.38, rocket ? 0.16 : 0.09);
    _round(canvas, receiver, 0.025, const Color(0xFF3A3934));
    _rect(canvas, Rect.fromLTWH(0.27, 0.04, 0.07, rocket ? 0.13 : 0.1), const Color(0xFF20201D));
    _rect(canvas, Rect.fromLTWH(0.48, -0.015, rocket ? 0.36 : 0.3, 0.03), const Color(0xFF20201D));
    _rect(canvas, Rect.fromLTWH(rocket ? 0.68 : 0.62, -0.04, 0.06, 0.08), const Color(0xFF3A3934));
    _rect(canvas, const Rect.fromLTWH(0.21, -0.1, 0.04, 0.055), const Color(0xFF20201D));
    if (rocket) {
      _circle(canvas, const Offset(0.74, 0), 0.07, const Color(0xFFC8382B));
      _circle(canvas, const Offset(0.74, 0), 0.03, const Color(0xFFE8C36A));
    }
  }

  void _tankBody(Canvas canvas, UnitSpec spec, Color teamColor, Paint outline) {
    final heavy = spec.kind == UnitKind.heavyTank;
    final width = heavy ? 0.92 : 0.78;
    final height = heavy ? 0.78 : 0.66;
    final barrel = heavy ? 0.58 : 0.5;
    _tracks(canvas, width: width, height: height, ratio: 0.24, radius: 0.06);
    final hull = Path()
      ..moveTo(-width / 2, -height * 0.3)
      ..lineTo(width * 0.28, -height / 2)
      ..lineTo(width / 2, -height * 0.2)
      ..lineTo(width / 2, height * 0.2)
      ..lineTo(width * 0.28, height / 2)
      ..lineTo(-width / 2, height * 0.3)
      ..close();
    canvas.drawPath(hull, brush.solid(teamColor));
    // 上部装甲、前部斜面与尾部引擎格栅。
    _round(canvas, Rect.fromLTWH(-width * 0.36, -height * 0.26, width * 0.62, height * 0.52), 0.06, shadeColor(teamColor, 0.08));
    _rect(canvas, Rect.fromLTWH(width * 0.3, -height * 0.4, width * 0.17, height * 0.8), shadeColor(teamColor, 0.2));
    for (var i = 0; i < 3; i++) {
      _rect(canvas, Rect.fromLTWH(-width * 0.36, -height * 0.18 + i * 0.1, width * 0.2, 0.055), const Color(0xFF2B2A26));
    }
    // 炮塔、舱盖、主炮与同轴机枪。
    final turret = heavy ? 0.27 : 0.22;
    _circle(canvas, Offset.zero, turret, shadeColor(teamColor, -0.16));
    canvas.drawCircle(Offset.zero, turret, brush.outlined(const Color(0xAA15130F), 0.04));
    _circle(canvas, const Offset(-0.05, -0.04), turret * 0.42, shadeColor(teamColor, 0.18));
    _rect(canvas, const Rect.fromLTWH(0, -0.05, 0.22, 0.1), const Color(0xFF403F39));
    _rect(canvas, Rect.fromLTWH(0, -0.05, barrel, 0.1), const Color(0xFF2E2D29));
    _rect(canvas, Rect.fromLTWH(barrel, -0.085, 0.1, 0.17), const Color(0xFF1F1E1B));
    _rect(canvas, const Rect.fromLTWH(0.12, 0.09, 0.2, 0.03), const Color(0xFF232220));
    _rect(canvas, Rect.fromLTWH(-width * 0.3, height * 0.28, width * 0.44, 0.05), shadeColor(teamColor, 0.26));
    canvas.drawPath(hull, outline);
  }

  void _artilleryBody(Canvas canvas, Color teamColor, Paint outline) {
    const width = 0.86;
    const height = 0.62;
    _tracks(canvas, width: width, height: height, ratio: 0.22, radius: 0.05);
    final hull = Path()
      ..moveTo(-width / 2, -height * 0.32)
      ..lineTo(width * 0.3, -height / 2)
      ..lineTo(width / 2, -height * 0.22)
      ..lineTo(width / 2, height * 0.22)
      ..lineTo(width * 0.3, height / 2)
      ..lineTo(-width / 2, height * 0.32)
      ..close();
    canvas.drawPath(hull, brush.solid(teamColor));
    // 低矮炮塔与超长身管，是自行火炮最好认的轮廓。
    _circle(canvas, const Offset(-0.08, 0), 0.18, shadeColor(teamColor, -0.2));
    _rect(canvas, const Rect.fromLTWH(-0.28, -0.06, 0.28, 0.12), const Color(0xFF403F39));
    _rect(canvas, const Rect.fromLTWH(-0.05, -0.055, 1.02, 0.09), const Color(0xFF2E2D29));
    _rect(canvas, const Rect.fromLTWH(0.38, -0.075, 0.18, 0.13), const Color(0xFF403F39));
    _rect(canvas, const Rect.fromLTWH(0.96, -0.09, 0.12, 0.16), const Color(0xFF1F1E1B));
    _rect(canvas, const Rect.fromLTWH(-0.34, -0.22, 0.22, 0.09), const Color(0xFF4B4A42));
    _rect(canvas, const Rect.fromLTWH(-0.34, 0.14, 0.22, 0.09), const Color(0xFF4B4A42));
    for (final y in [-0.2, 0.2]) {
      _line(canvas, Offset(-width * 0.44, y), Offset(-width * 0.62, y * 1.6), const Color(0xFF35342F), 0.06);
    }
    canvas.drawPath(hull, outline);
  }

  /// 车体上下两条履带，坦克与自行火炮共用；带横向履带齿与挡泥板。
  void _tracks(Canvas canvas, {required double width, required double height, required double ratio, required double radius}) {
    final band = height * ratio;
    for (final top in [-height / 2, height / 2 - band]) {
      final rect = Rect.fromLTWH(-width / 2, top, width, band);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)), brush.solid(const Color(0xFF1F1E1B)));
      for (var x = rect.left + 0.08; x < rect.right - 0.04; x += 0.11) {
        _line(canvas, Offset(x, rect.top + 0.02), Offset(x, rect.bottom - 0.02), const Color(0xFF43423B), 0.026);
      }
      _line(canvas, Offset(rect.left + 0.04, rect.top - 0.015), Offset(rect.right - 0.04, rect.top - 0.015), const Color(0xFF5A5951), 0.035);
    }
  }

  void _gunshipBody(Canvas canvas, Color teamColor, Paint outline) {
    // 尾梁、尾桨与短翼，构成直升机的十字轮廓。
    _round(canvas, const Rect.fromLTWH(-0.72, -0.05, 0.76, 0.1), 0.04, const Color(0xFF2B2A26));
    _rect(canvas, const Rect.fromLTWH(-0.74, -0.2, 0.06, 0.4), const Color(0xFF2B2A26));
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(-0.7, 0), width: 0.05, height: 0.42),
      brush.solid(const Color(0x99E8E8E0)),
    );
    for (final y in [-0.3, 0.22]) {
      _rect(canvas, Rect.fromLTWH(-0.12, y, 0.34, 0.08), const Color(0xFF2B2A26));
      for (var i = 0; i < 3; i++) {
        _circle(canvas, Offset(0.04 + i * 0.09, y + (y < 0 ? -0.035 : 0.035)), 0.035, const Color(0xFF141311));
      }
    }
    // 机身、座舱、发动机罩与旋翼。
    final body = Rect.fromCenter(center: const Offset(0.02, 0), width: 0.62, height: 0.44);
    canvas.drawOval(body, brush.solid(teamColor));
    canvas.drawOval(body, outline);
    canvas.drawOval(Rect.fromCenter(center: const Offset(0.2, 0), width: 0.28, height: 0.24), brush.solid(const Color(0xFF8FB6C4)));
    _round(canvas, const Rect.fromLTWH(-0.2, -0.13, 0.24, 0.26), 0.05, shadeColor(teamColor, -0.28));
    _circle(canvas, Offset.zero, 0.58, const Color(0x22E8E8E0));
    for (var i = 0; i < 4; i++) {
      final angle = math.pi / 4 + i * math.pi / 2;
      _line(canvas, Offset(math.cos(angle) * 0.12, math.sin(angle) * 0.12), Offset(math.cos(angle) * 0.58, math.sin(angle) * 0.58), const Color(0x99F0F0E8), 0.03);
    }
    _circle(canvas, Offset.zero, 0.1, const Color(0xFF35342F));
    _circle(canvas, Offset.zero, 0.05, const Color(0xFF8E8B7E));
    for (final y in [-0.27, 0.21]) {
      _line(canvas, Offset(-0.16, y), Offset(0.3, y), const Color(0xFF35342F), 0.045);
    }
    _circle(canvas, const Offset(0.34, -0.16), 0.035, const Color(0xFFE05545));
    _circle(canvas, const Offset(0.34, 0.16), 0.035, const Color(0xFF5FD08A));
  }

  void _harvesterBody(Canvas canvas, Color teamColor, Paint outline) {
    const width = 0.94;
    const height = 0.7;
    _tracks(canvas, width: width, height: height, ratio: 0.22, radius: 0.06);
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: width * 0.86, height: height * 0.7),
      const Radius.circular(0.07),
    );
    canvas.drawRRect(body, brush.solid(teamColor));
    // 前部驾驶室、挡风玻璃与铲斗。
    _round(canvas, const Rect.fromLTWH(0.14, -0.23, 0.24, 0.46), 0.05, shadeColor(teamColor, -0.16));
    _rect(canvas, const Rect.fromLTWH(0.3, -0.18, 0.07, 0.36), const Color(0xFF9CC3CF));
    canvas.drawPath(
      Path()
        ..moveTo(0.38, -0.28)
        ..lineTo(0.48, -0.18)
        ..lineTo(0.48, 0.18)
        ..lineTo(0.38, 0.28)
        ..close(),
      brush.solid(const Color(0xFF6B6A60)),
    );
    // 矿石仓与仓壁加强筋，填充部分由 _harvesterCargo 逐帧绘制。
    _rect(canvas, _cargoBin, const Color(0xFF3C3A33));
    for (var i = 0; i < 3; i++) {
      _rect(canvas, Rect.fromLTWH(_cargoBin.left + 0.04 + i * 0.14, _cargoBin.top, 0.035, _cargoBin.height), const Color(0xFF55534A));
    }
    _rect(canvas, const Rect.fromLTWH(-0.3, -0.36, 0.1, 0.14), const Color(0xFF2B2A26));
    _rect(canvas, const Rect.fromLTWH(-0.42, 0.22, 0.3, 0.05), const Color(0xFFD9A94B));
    canvas.drawRRect(body, outline);
  }

  static const Rect _cargoBin = Rect.fromLTWH(-0.34, -0.2, 0.46, 0.4);

  void _harvesterCargo(Canvas canvas, double ratio) {
    if (ratio <= 0) return;
    _rect(
      canvas,
      Rect.fromLTWH(
        _cargoBin.left + 0.03,
        _cargoBin.bottom - (_cargoBin.height - 0.04) * ratio,
        _cargoBin.width - 0.06,
        (_cargoBin.height - 0.04) * ratio,
      ),
      const Color(0xFFD9A94B),
    );
  }
}
