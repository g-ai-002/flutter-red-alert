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
  final Map<int, ui.Picture> _cache = {};

  static const int _weaponKey = 32;

  @visibleForTesting
  int get cachedPictures => _cache.length;

  void paint(Canvas canvas, Unit unit, Paint outline) {
    final spec = unit.spec;
    final team = unit.team;
    final key = spec.kind.index * 2 + team.index;
    canvas.save();
    canvas.translate(unit.x, unit.y);
    if (spec.kind == UnitKind.rifle || spec.kind == UnitKind.rocket) {
      _drawBody(canvas, key, spec, team, outline);
      canvas.rotate(unit.facing);
      canvas.drawPicture(
        _cache[key + _weaponKey] ??= _recordWeapon(spec, team),
      );
    } else {
      canvas.rotate(unit.facing);
      _drawBody(canvas, key, spec, team, outline);
      if (spec.isHarvester) _harvesterCargo(canvas, unit.cargoRatio);
    }
    canvas.restore();
  }

  void _drawBody(
    Canvas canvas,
    int key,
    UnitSpec spec,
    Team team,
    Paint outline,
  ) {
    canvas.drawPicture(_cache[key] ??= _recordBody(spec, team, outline));
  }

  void dispose() {
    for (final picture in _cache.values) {
      picture.dispose();
    }
    _cache.clear();
  }

  ui.Picture _recordBody(UnitSpec spec, Team team, Paint outline) {
    return _record((canvas) {
      switch (spec.kind) {
        case UnitKind.rifle:
        case UnitKind.rocket:
          _infantryBody(canvas, team.color, outline);
          break;
        case UnitKind.harvester:
          _harvesterBody(canvas, team.color, outline);
          break;
        case UnitKind.lightTank:
        case UnitKind.heavyTank:
          _tankBody(canvas, spec, team.color, outline);
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

  void _infantryWeapon(Canvas canvas, UnitSpec spec, Color teamColor) {
    final rocket = spec.kind == UnitKind.rocket;
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
      brush.solid(rocket ? const Color(0xFF2C2B28) : const Color(0xFF4A4A45)),
    );
    if (rocket) {
      canvas.drawCircle(
        const Offset(0.55, 0),
        0.055,
        brush.solid(const Color(0xFF8E241B)),
      );
    }
  }

  void _tankBody(Canvas canvas, UnitSpec spec, Color teamColor, Paint outline) {
    final heavy = spec.kind == UnitKind.heavyTank;
    final width = heavy ? 0.86 : 0.74;
    final height = heavy ? 0.72 : 0.62;
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
  }

  void _harvesterBody(Canvas canvas, Color teamColor, Paint outline) {
    final body = Rect.fromCenter(center: Offset.zero, width: 0.9, height: 0.66);
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(0.08)),
      brush.solid(teamColor),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(0.08)),
      outline,
    );
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
