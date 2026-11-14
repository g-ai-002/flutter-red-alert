import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../game/battle_types.dart';
import '../game/terrain.dart';
import '../theme/palette.dart';
import 'paint_utils.dart';

/// 地形图层：把地图切成区块缓存 [ui.Picture]，首次进入视野时才录制；
/// 矿石采空时只重录变化的区块。
///
/// 每帧只绘制一张合并后的整图，避免 Skia 把十几张子图重新展开成上千条指令。
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
  ui.Picture? _composite;
  bool _compositeDirty = true;
  int _version = -1;

  /// 区块与整图共用这几支画笔，避免每个格子都新建 Paint。
  final Paint _fill = Paint();
  final Paint _stroke = Paint()..style = PaintingStyle.stroke;
  final Paint _blade = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final Paint _grid = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.012
    ..color = const Color(0x14FFFFFF);

  Paint _solid(Color color) => _fill..color = color;

  Paint _line(Color color, double width) => _stroke
    ..color = color
    ..strokeWidth = width;

  Paint _bladeOf(Color color, double width) => _blade
    ..color = color
    ..strokeWidth = width;

  @visibleForTesting
  int builtChunks = 0;

  /// 进入战场前预先录制全部区块与整图，避免首次平移时出现整帧卡顿。
  void warmUp() {
    _version = map.version;
    for (var index = 0; index < _pictures.length; index++) {
      _pictures[index] ??= _buildChunk(index % _columns, index ~/ _columns);
    }
    _compositeDirty = true;
    _buildComposite();
  }

  void paint(Canvas canvas, Rect visible) {
    if (_version != map.version) _applyChanges();
    _buildVisibleChunks(visible);
    if (_compositeDirty) _buildComposite();
    canvas.drawPicture(_composite!);
  }

  /// 录制视野内还没缓存的区块，新加入的区块会让整图失效。
  void _buildVisibleChunks(Rect visible) {
    for (var index = 0; index < _pictures.length; index++) {
      if (_pictures[index] != null) continue;
      final column = index % _columns;
      final row = index ~/ _columns;
      if (!_chunkRect(column, row).overlaps(visible)) continue;
      _pictures[index] = _buildChunk(column, row);
      _compositeDirty = true;
    }
  }

  void _buildComposite() {
    _composite?.dispose();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    _pictures.nonNulls.forEach(canvas.drawPicture);
    _composite = recorder.endRecording();
    _compositeDirty = false;
  }

  /// 区块向外扩一格，与录制时多画的一圈接缝范围对应。
  Rect _chunkRect(int column, int row) => Rect.fromLTWH(
    column * _chunkTiles - 1.0,
    row * _chunkTiles - 1.0,
    _chunkTiles + 2.0,
    _chunkTiles + 2.0,
  );

  /// 只让变化格所在的区块失效；没有具体格子时退回整表重建。
  void _applyChanges() {
    final dirty = map.takeDirtyTiles();
    if (dirty.isEmpty) {
      dispose();
    } else {
      for (final tile in dirty) {
        final chunk =
            (tile ~/ map.width ~/ _chunkTiles) * _columns + (tile % map.width ~/ _chunkTiles);
        _pictures[chunk]?.dispose();
        _pictures[chunk] = null;
      }
      _compositeDirty = true;
    }
    _version = map.version;
  }

  void dispose() {
    for (final picture in _pictures) {
      picture?.dispose();
    }
    _pictures.fillRange(0, _pictures.length, null);
    _composite?.dispose();
    _composite = null;
    _compositeDirty = true;
    _version = -1;
  }

  ui.Picture _buildChunk(int column, int row) {
    builtChunks++;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    // 区块向外多画一格，避免相邻区块边界出现 1% 绘制误差造成的接缝。
    final startX = (column * _chunkTiles - 1).clamp(0, map.width - 1);
    final startY = (row * _chunkTiles - 1).clamp(0, map.height - 1);
    final endX = ((column + 1) * _chunkTiles + 1).clamp(0, map.width);
    final endY = ((row + 1) * _chunkTiles + 1).clamp(0, map.height);
    for (var y = startY; y < endY; y++) {
      for (var x = startX; x < endX; x++) {
        _paintTile(canvas, x, y);
      }
    }
    return recorder.endRecording();
  }

  void _paintTile(Canvas canvas, int x, int y) {
    final kind = map.terrainAt(x, y);
    final noise = hashNoise(x, y);
    final base = terrainColor(kind);
    final rect = Rect.fromLTWH(x.toDouble(), y.toDouble(), 1.01, 1.01);
    canvas.drawRect(rect, _solid(shadeColor(base, noise * 0.12 - 0.06)));
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
    canvas.drawRect(rect, _grid);
  }

  void _paintGrass(Canvas canvas, int x, int y, double noise) {
    final paint = _bladeOf(terrainHighlight(TerrainKind.grass).withValues(alpha: 0.45), 0.045);
    for (var i = 0; i < 3; i++) {
      final fx = x + 0.15 + hashNoise(x + i * 7, y + i) * 0.7;
      final fy = y + 0.2 + hashNoise(x + i, y + i * 5) * 0.65;
      canvas.drawLine(Offset(fx, fy), Offset(fx + 0.05, fy - 0.14), paint);
    }
    if (noise > 0.85) {
      canvas.drawCircle(Offset(x + 0.7, y + 0.3), 0.12, _solid(const Color(0x22552F1E)));
    }
  }

  void _paintDirt(Canvas canvas, int x, int y, double noise) {
    final paint = _solid(const Color(0x33604A33));
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
    canvas.drawRect(Rect.fromLTWH(x + 0.1, y + 0.47, 0.8, 0.045), _solid(const Color(0x55E7DCC2)));
  }

  void _paintWater(Canvas canvas, int x, int y, double noise) {
    final paint = _bladeOf(terrainHighlight(TerrainKind.water).withValues(alpha: 0.6), 0.05);
    final yOffset = 0.3 + noise * 0.3;
    canvas.drawLine(Offset(x + 0.2, y + yOffset), Offset(x + 0.55, y + yOffset), paint);
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
    canvas.drawPath(path, _solid(terrainColor(TerrainKind.rock)));
    canvas.drawPath(path, _line(terrainHighlight(TerrainKind.rock), 0.035));
  }

  void _paintOre(Canvas canvas, int x, int y, int amount, double noise) {
    _paintDirt(canvas, x, y, noise);
    final ratio = (amount / 2600).clamp(0.25, 1.0);
    canvas.drawCircle(Offset(x + 0.5, y + 0.5), 0.3 * ratio, _solid(const Color(0x66D9A94B)));
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
      canvas.drawPath(path, _solid(const Color(0xFFE7C065)));
      canvas.drawPath(path, _line(const Color(0xFF8A6420), 0.018));
    }
  }
}
