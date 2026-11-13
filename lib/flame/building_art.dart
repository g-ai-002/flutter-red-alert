import 'dart:ui' as ui;

import 'package:flutter/material.dart';

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

  ui.Picture _record(Building building, Paint outline) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    _draw(
      canvas,
      Building(
        id: 0,
        team: building.team,
        spec: building.spec,
        tileX: 0,
        tileY: 0,
      ),
      outline,
    );
    return recorder.endRecording();
  }

  void _draw(Canvas canvas, Building building, Paint outline) {
    final rect = building.bounds.deflate(0.05);
    final body = RRect.fromRectAndRadius(rect, const Radius.circular(0.12));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.translate(0.08, 0.1),
        const Radius.circular(0.12),
      ),
      brush.solid(const Color(0x66000000)),
    );
    canvas.drawRRect(body, brush.solid(const Color(0xFF4B4E4A)));
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
      brush.solid(const Color(0xFF5B5E58)),
    );
    // 阵营色条
    canvas.drawRect(
      Rect.fromLTWH(rect.left + 0.1, rect.bottom - 0.18, rect.width - 0.2, 0.1),
      brush.solid(building.team.color),
    );
    _detail(canvas, building, rect);
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

  void _detail(Canvas canvas, Building building, Rect rect) {
    final center = rect.center;
    final dark = brush.solid(const Color(0xFF353732));
    switch (building.spec.kind) {
      case BuildingKind.hq:
        canvas.drawCircle(center, rect.width * 0.16, dark);
        canvas.drawCircle(
          center,
          rect.width * 0.1,
          brush.solid(building.team.color),
        );
        canvas.drawLine(
          Offset(center.dx, rect.top + 0.1),
          Offset(center.dx, center.dy - rect.width * 0.16),
          brush.outlined(const Color(0xFFCCC3AE), 0.045),
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
        canvas.drawPath(bolt, brush.solid(const Color(0xFFE8C36A)));
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
            brush.solid(const Color(0xFF8A7A55)),
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
            brush.solid(const Color(0xFF6D6F66)),
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
          brush.outlined(const Color(0xFFD9A94B), 0.07),
        );
        break;
      case BuildingKind.tower:
        canvas.drawCircle(center, rect.width * 0.3, dark);
        canvas.drawCircle(
          center,
          rect.width * 0.2,
          brush.solid(building.team.color),
        );
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(building.facing);
        canvas.drawRect(
          Rect.fromLTWH(0, -0.05, rect.width * 0.42, 0.1),
          brush.solid(const Color(0xFF2B2A26)),
        );
        canvas.restore();
        break;
    }
  }
}
