import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../game/battle_types.dart';
import '../game/terrain.dart';
import '../theme/palette.dart';
import 'paint_utils.dart';

/// 地形图层：按地图版本把 44×44 格切成若干区块缓存 [ui.Picture]。
///
/// 只有矿石被采空导致地形变化时地图版本才会递增，正常对局中每帧只回放
/// 摄像机视野覆盖的区块，缩放到局部时不再重放整张地图的绘制指令。
class TerrainPainter {
  TerrainPainter(this.map) {
    _columns = (map.width + _chunkTiles - 1) ~/ _chunkTiles;
    _rows = (map.height + _chunkTiles - 1) ~/ _chunkTiles;
    _pictures = List<ui.Picture?>.filled(_columns * _rows, null);
  }

  static const int _chunkTiles = 11;

  final GameMap map;

  late final int _columns;
  late final int _rows;
  late final List<ui.Picture?> _pictures;
  int _version = -1;

  void paint(Canvas canvas, Rect visible) {
    if (_version != map.version) _rebuild();
    for (var row = 0; row < _rows; row++) {
      for (var column = 0; column < _columns; column++) {
        final picture = _pictures[row * _columns + column];
        if (picture == null) continue;
        final rect = Rect.fromLTWH(
          column * _chunkTiles.toDouble(),
          row * _chunkTiles.toDouble(),
          _chunkTiles.toDouble(),
          _chunkTiles.toDouble(),
        );
        if (rect.inflate(1).overlaps(visible)) canvas.drawPicture(picture);
      }
    }
  }

  void dispose() {
    for (final picture in _pictures) {
      picture?.dispose();
    }
    _pictures.fillRange(0, _pictures.length, null);
    _version = -1;
  }

  void _rebuild() {
    dispose();
    for (var row = 0; row < _rows; row++) {
      for (var column = 0; column < _columns; column++) {
        _pictures[row * _columns + column] = _buildChunk(column, row);
      }
    }
    _version = map.version;
  }

  ui.Picture _buildChunk(int column, int row) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.012
      ..color = const Color(0x14FFFFFF);
    // 区块向外多画一格，避免相邻区块边界出现 1% 绘制误差造成的接缝。
    final startX = (column * _chunkTiles - 1).clamp(0, map.width - 1);
    final startY = (row * _chunkTiles - 1).clamp(0, map.height - 1);
    final endX = ((column + 1) * _chunkTiles + 1).clamp(0, map.width);
    final endY = ((row + 1) * _chunkTiles + 1).clamp(0, map.height);
    for (var y = startY; y < endY; y++) {
      for (var x = startX; x < endX; x++) {
        _paintTile(canvas, x, y, gridPaint);
      }
    }
    return recorder.endRecording();
  }

  void _paintTile(Canvas canvas, int x, int y, Paint gridPaint) {
    final kind = map.terrainAt(x, y);
    final noise = hashNoise(x, y);
    final base = terrainColor(kind);
    final rect = Rect.fromLTWH(x.toDouble(), y.toDouble(), 1.01, 1.01);
    canvas.drawRect(
      rect,
      Paint()..color = shadeColor(base, noise * 0.12 - 0.06),
    );
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

  void _paintGrass(Canvas canvas, int x, int y, double noise) {
    final paint = Paint()
      ..color = terrainHighlight(TerrainKind.grass).withValues(alpha: 0.45)
      ..strokeWidth = 0.045
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final fx = x + 0.15 + hashNoise(x + i * 7, y + i) * 0.7;
      final fy = y + 0.2 + hashNoise(x + i, y + i * 5) * 0.65;
      canvas.drawLine(Offset(fx, fy), Offset(fx + 0.05, fy - 0.14), paint);
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
          x + 0.2 + hashNoise(x + i * 3, y + 9) * 0.6,
          y + 0.2 + hashNoise(x + 5, y + i * 3) * 0.6,
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
      final cx = x + 0.2 + hashNoise(x + i * 13, y + 3) * 0.6;
      final cy = y + 0.2 + hashNoise(x + 7, y + i * 11) * 0.6;
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
}
