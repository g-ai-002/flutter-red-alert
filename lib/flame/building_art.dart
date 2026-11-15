import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../game/battle_types.dart';
import '../game/entity.dart';
import 'paint_utils.dart';

/// 建筑造型：按「类型 + 阵营」录制成 [ui.Picture] 复用；
/// 只有炮塔的炮管随朝向转动，仍逐帧绘制。
class BuildingArt {
  BuildingArt(this.brush);

  final ArtBrush brush;
  final Map<int, ui.Picture> _cache = {};

  @visibleForTesting
  int get cachedPictures => _cache.length;

  void paint(Canvas canvas, Building building, Paint outline) {
    if (building.spec.kind == BuildingKind.tower) {
      _draw(canvas, building, outline);
      return;
    }
    final key = building.spec.kind.index * 2 + building.team.index;
    final picture = _cache[key] ??= _record(building, outline);
    canvas.save();
    canvas.translate(building.tileX.toDouble(), building.tileY.toDouble());
    canvas.drawPicture(picture);
    canvas.restore();
  }

  void dispose() {
    for (final picture in _cache.values) {
      picture.dispose();
    }
    _cache.clear();
  }

  void _rect(Canvas c, Rect r, Color color) => c.drawRect(r, brush.solid(color));

  void _round(Canvas c, Rect r, double radius, Color color) =>
      c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(radius)), brush.solid(color));

  void _circle(Canvas c, Offset o, double radius, Color color) =>
      c.drawCircle(o, radius, brush.solid(color));

  void _line(Canvas c, Offset a, Offset b, Color color, double width) =>
      c.drawLine(a, b, brush.outlined(color, width));

  ui.Picture _record(Building building, Paint outline) {
    final recorder = ui.PictureRecorder();
    _draw(
      Canvas(recorder),
      Building(id: 0, team: building.team, spec: building.spec, tileX: 0, tileY: 0),
      outline,
    );
    return recorder.endRecording();
  }

  void _draw(Canvas canvas, Building building, Paint outline) {
    final rect = building.bounds.deflate(0.05);
    final body = RRect.fromRectAndRadius(rect, const Radius.circular(0.12));
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.translate(0.08, 0.1), const Radius.circular(0.12)),
      brush.solid(const Color(0x66000000)),
    );
    canvas.drawRRect(body, brush.solid(const Color(0xFF3F423D)));
    final roof = rect.deflate(0.08);
    _round(canvas, roof, 0.08, const Color(0xFF5B5E58));
    // 屋面分缝、边缘高光与四角铆钉。
    _line(canvas, Offset(roof.left, roof.center.dy), Offset(roof.right, roof.center.dy), const Color(0x22504F47), 0.03);
    _line(canvas, Offset(roof.center.dx, roof.top), Offset(roof.center.dx, roof.bottom), const Color(0x22504F47), 0.03);
    _line(canvas, Offset(roof.left + 0.05, roof.top + 0.06), Offset(roof.right - 0.05, roof.top + 0.06), const Color(0x336E7168), 0.03);
    for (final x in [roof.left + 0.1, roof.right - 0.1]) {
      for (final y in [roof.top + 0.1, roof.bottom - 0.1]) {
        _circle(canvas, Offset(x, y), 0.032, const Color(0xFF9A9D92));
      }
    }
    // 阵营色条
    _rect(canvas, Rect.fromLTWH(rect.left + 0.1, rect.bottom - 0.18, rect.width - 0.2, 0.1), building.team.color);
    _detail(canvas, building, rect, roof);
    canvas.drawRRect(body, outline);
  }

  /// 选中建筑的地面高亮框。
  void paintSelection(Canvas canvas, Building building) {
    final rect = building.bounds.deflate(0.05);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.inflate(0.08), const Radius.circular(0.14)),
      brush.outlined(const Color(0xFFF2D27A), 0.06),
    );
  }

  void _detail(Canvas canvas, Building building, Rect rect, Rect roof) {
    final center = roof.center;
    const dark = Color(0xFF353732);
    const metal = Color(0xFF787B70);
    switch (building.spec.kind) {
      case BuildingKind.hq:
        // 指挥中心：雷达碟、天线与停机坪标线。
        _circle(canvas, center, rect.width * 0.16, dark);
        _circle(canvas, center, rect.width * 0.11, const Color(0xFF4B4E48));
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: rect.width * 0.3),
          math.pi * 1.08,
          math.pi * 0.84,
          false,
          brush.outlined(const Color(0xFFC3C8B9), 0.055),
        );
        _line(canvas, Offset(center.dx, roof.top + 0.08), Offset(center.dx, center.dy - rect.width * 0.16), const Color(0xFFC3C8B9), 0.04);
        _circle(canvas, Offset(center.dx, roof.top + 0.08), 0.055, const Color(0xFFE05545));
        for (final x in [roof.left + 0.16, roof.right - 0.16]) {
          _rect(canvas, Rect.fromLTWH(x - 0.07, roof.top + 0.12, 0.14, 0.08), const Color(0xFF9CC3CF));
        }
        _line(canvas, Offset(roof.left + 0.16, roof.bottom - 0.22), Offset(roof.right - 0.16, roof.bottom - 0.22), const Color(0xFF8C9085), 0.04);
        break;
      case BuildingKind.power:
        // 电厂：双冷却塔、变压器与闪电标识。
        for (final dx in [-rect.width * 0.22, rect.width * 0.22]) {
          _circle(canvas, Offset(center.dx + dx, center.dy - 0.05), rect.height * 0.2, dark);
          _circle(canvas, Offset(center.dx + dx, center.dy - 0.05), rect.height * 0.14, const Color(0xFF6B6E64));
          _circle(canvas, Offset(center.dx + dx, center.dy - 0.05), rect.height * 0.08, const Color(0xFF3F423C));
        }
        canvas.drawPath(
          Path()
            ..moveTo(center.dx - 0.1, rect.top + 0.16)
            ..lineTo(center.dx + 0.06, rect.top + 0.16)
            ..lineTo(center.dx - 0.01, center.dy)
            ..lineTo(center.dx + 0.11, center.dy)
            ..lineTo(center.dx - 0.08, rect.bottom - 0.24)
            ..lineTo(center.dx - 0.02, center.dy + 0.05)
            ..lineTo(center.dx - 0.14, center.dy + 0.05)
            ..close(),
          brush.solid(const Color(0xFFE8C36A)),
        );
        _rect(canvas, Rect.fromLTWH(roof.left + 0.1, roof.bottom - 0.2, 0.12, 0.08), metal);
        _rect(canvas, Rect.fromLTWH(roof.right - 0.22, roof.bottom - 0.2, 0.12, 0.08), metal);
        break;
      case BuildingKind.refinery:
        // 精炼厂：储油罐、连接管线与警示条。
        for (final dx in [rect.left + rect.width * 0.26, rect.right - rect.width * 0.26]) {
          _circle(canvas, Offset(dx, center.dy), rect.height * 0.23, dark);
          _circle(canvas, Offset(dx, center.dy), rect.height * 0.16, const Color(0xFF8A7A55));
          _circle(canvas, Offset(dx, center.dy), rect.height * 0.07, const Color(0xFF6B5E40));
          _line(canvas, Offset(dx, center.dy - rect.height * 0.16), Offset(dx, center.dy + rect.height * 0.16), const Color(0xFFB6A273), 0.035);
        }
        _line(canvas, Offset(rect.left + rect.width * 0.32, center.dy), Offset(rect.right - rect.width * 0.32, center.dy), const Color(0xFF9A9D92), 0.12);
        for (var i = 0; i < 4; i++) {
          _rect(canvas, Rect.fromLTWH(rect.left + 0.14 + i * 0.18, roof.top + 0.1, 0.08, 0.06), const Color(0xFFD9A94B));
        }
        break;
      case BuildingKind.barracks:
        // 兵营：屋脊、大门、窗口与旗杆。
        _line(canvas, Offset(roof.left + 0.1, roof.top + 0.18), Offset(roof.right - 0.1, roof.top + 0.18), const Color(0xFF6D6F66), 0.08);
        _line(canvas, Offset(center.dx, roof.top + 0.18), Offset(center.dx, roof.bottom - 0.24), const Color(0xFF6D6F66), 0.05);
        _rect(canvas, Rect.fromLTWH(center.dx - 0.18, roof.bottom - 0.34, 0.36, 0.2), dark);
        _rect(canvas, Rect.fromLTWH(center.dx - 0.12, roof.bottom - 0.3, 0.24, 0.12), const Color(0xFF8D9085));
        for (var i = 0; i < 3; i++) {
          _rect(canvas, Rect.fromLTWH(roof.left + 0.14 + i * 0.24, roof.top + 0.28, 0.14, 0.09), const Color(0xFF9CC3CF));
        }
        _line(canvas, Offset(roof.right - 0.16, roof.top + 0.12), Offset(roof.right - 0.16, roof.top - 0.02), const Color(0xFF8C9085), 0.03);
        _rect(canvas, Rect.fromLTWH(roof.right - 0.16, roof.top - 0.02, 0.14, 0.08), building.team.color);
        break;
      case BuildingKind.factory:
        // 战车工厂：锯齿屋顶、烟囱、卷帘门与货箱。
        for (var i = 0; i < 3; i++) {
          final left = roof.left + 0.12 + i * (roof.width - 0.24) / 3;
          _line(canvas, Offset(left, roof.top + 0.2), Offset(left + 0.16, roof.top + 0.06), const Color(0xFF8C9085), 0.045);
          _line(canvas, Offset(left + 0.16, roof.top + 0.06), Offset(left + 0.16, roof.top + 0.2), const Color(0xFF8C9085), 0.03);
        }
        _rect(canvas, Rect.fromLTWH(roof.right - 0.24, roof.top + 0.08, 0.12, 0.24), dark);
        _rect(canvas, Rect.fromLTWH(roof.right - 0.27, roof.top + 0.06, 0.18, 0.05), const Color(0xFF4A4C45));
        _rect(canvas, Rect.fromLTWH(center.dx - 0.26, roof.bottom - 0.38, 0.52, 0.26), dark);
        for (var i = 0; i < 4; i++) {
          _line(canvas, Offset(center.dx - 0.22, roof.bottom - 0.34 + i * 0.06), Offset(center.dx + 0.22, roof.bottom - 0.34 + i * 0.06), const Color(0xFF6D6F66), 0.025);
        }
        _rect(canvas, Rect.fromLTWH(roof.left + 0.1, roof.bottom - 0.3, 0.16, 0.14), const Color(0xFFD9A94B));
        break;
      case BuildingKind.tower:
        // 哨戒炮塔：底座、旋转炮塔、主炮与弹药箱。
        _circle(canvas, center, rect.width * 0.34, dark);
        _circle(canvas, center, rect.width * 0.27, metal);
        _circle(canvas, center, rect.width * 0.2, building.team.color);
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(building.facing);
        _rect(canvas, const Rect.fromLTWH(-0.06, -0.09, 0.24, 0.18), const Color(0xFF4B4A42));
        _rect(canvas, Rect.fromLTWH(0.1, -0.05, rect.width * 0.44, 0.1), const Color(0xFF2B2A26));
        _rect(canvas, Rect.fromLTWH(0.1 + rect.width * 0.44, -0.075, 0.08, 0.15), const Color(0xFF1F1E1B));
        canvas.restore();
        _rect(canvas, Rect.fromLTWH(center.dx - 0.3, center.dy + 0.22, 0.14, 0.09), const Color(0xFF6B6E64));
        break;
      case BuildingKind.airDefense:
        // 防空炮塔：雷达、双联装发射箱与警示圈。
        _circle(canvas, center, rect.width * 0.34, dark);
        _circle(canvas, center, rect.width * 0.25, metal);
        _circle(canvas, center, rect.width * 0.16, building.team.color);
        _rect(canvas, Rect.fromLTWH(center.dx - 0.22, center.dy - 0.18, 0.44, 0.22), const Color(0xFF4B4A42));
        for (final dx in [-0.16, -0.02, 0.12]) {
          _circle(canvas, Offset(center.dx + dx, center.dy - 0.11), 0.045, const Color(0xFF1F1E1B));
          _circle(canvas, Offset(center.dx + dx, center.dy - 0.11), 0.018, const Color(0xFFC8382B));
        }
        _line(canvas, Offset(center.dx, center.dy - 0.18), Offset(center.dx + 0.18, center.dy - 0.4), const Color(0xFF8C9085), 0.035);
        _circle(canvas, Offset(center.dx + 0.18, center.dy - 0.4), 0.05, const Color(0xFFC3C8B9));
        break;
      case BuildingKind.silo:
        // 导弹发射井：井盖环、待发导弹、尾翼与警示条。
        _circle(canvas, center, rect.width * 0.32, dark);
        _circle(canvas, center, rect.width * 0.26, const Color(0xFF5B5E58));
        for (var i = 0; i < 8; i++) {
          final angle = i * math.pi / 4;
          _line(
            canvas,
            Offset(center.dx + math.cos(angle) * rect.width * 0.27, center.dy + math.sin(angle) * rect.width * 0.27),
            Offset(center.dx + math.cos(angle) * rect.width * 0.31, center.dy + math.sin(angle) * rect.width * 0.31),
            i.isEven ? const Color(0xFFD9A94B) : const Color(0xFF35342F),
            0.04,
          );
        }
        _rect(canvas, Rect.fromLTWH(center.dx - 0.1, center.dy - 0.7, 0.2, 1.0), const Color(0xFFE8E2D2));
        canvas.drawPath(
          Path()
            ..moveTo(center.dx, center.dy - 0.94)
            ..lineTo(center.dx + 0.1, center.dy - 0.68)
            ..lineTo(center.dx - 0.1, center.dy - 0.68)
            ..close(),
          brush.solid(const Color(0xFFC8382B)),
        );
        _rect(canvas, Rect.fromLTWH(center.dx - 0.12, center.dy + 0.12, 0.24, 0.12), const Color(0xFF35342F));
        for (final dx in [-0.18, 0.12]) {
          _rect(canvas, Rect.fromLTWH(center.dx + dx, center.dy + 0.16, 0.06, 0.18), const Color(0xFF8C9085));
        }
        break;
    }
  }
}
