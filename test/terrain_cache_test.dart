import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_red_alert/flame/terrain_painter.dart';
import 'package:flutter_red_alert/game/battle_types.dart';
import 'package:flutter_red_alert/game/terrain.dart';
import 'package:material_ui/material_ui.dart';

Canvas _recorder() => Canvas(ui.PictureRecorder());

void main() {
  test('首次绘制只构建视野内的区块', () {
    final map = GameMap.generate();
    final painter = TerrainPainter(map);
    painter.paint(_recorder(), const Rect.fromLTWH(16, 16, 11, 11));
    expect(painter.builtChunks, greaterThan(0));
    expect(painter.builtChunks, lessThan(16));
    painter.dispose();
  });

  test('再次绘制复用区块', () {
    final map = GameMap.generate();
    final painter = TerrainPainter(map);
    painter.paint(_recorder(), const Rect.fromLTWH(0, 0, 44, 44));
    final built = painter.builtChunks;
    expect(built, 16);
    painter.paint(_recorder(), const Rect.fromLTWH(0, 0, 44, 44));
    expect(painter.builtChunks, built);
    painter.dispose();
  });

  test('预热后任意视野都不再录制新区块', () {
    final map = GameMap.generate();
    final painter = TerrainPainter(map);
    painter.warmUp();
    expect(painter.builtChunks, 16);
    painter.paint(_recorder(), const Rect.fromLTWH(0, 0, 11, 11));
    painter.paint(_recorder(), const Rect.fromLTWH(30, 30, 14, 14));
    expect(painter.builtChunks, 16, reason: '预热已覆盖整张地图，平移不应再触发录制');
    painter.dispose();
  });

  test('地形更新后合成图跟随重建', () {
    final map = GameMap.generate();
    final painter = TerrainPainter(map);
    const full = Rect.fromLTWH(0, 0, 44, 44);
    painter.warmUp();
    final built = painter.builtChunks;

    final oreIndex = map.oreIndices.first;
    expect(map.mine(oreIndex % map.width, oreIndex ~/ map.width, 999999), greaterThan(0));

    painter.paint(_recorder(), full);
    expect(painter.builtChunks, built + 1);
    painter.dispose();
  });

  test('矿格采空只重建所在区块', () {
    final map = GameMap.generate();
    final painter = TerrainPainter(map);
    const full = Rect.fromLTWH(0, 0, 44, 44);
    painter.paint(_recorder(), full);
    final built = painter.builtChunks;

    final oreIndex = map.oreIndices.first;
    expect(map.mine(oreIndex % map.width, oreIndex ~/ map.width, 999999), greaterThan(0));

    painter.paint(_recorder(), full);
    expect(painter.builtChunks, built + 1);
    painter.dispose();
  });

  test('没有地形变化时不产生待重绘格子', () {
    final map = GameMap.generate();
    map.takeDirtyTiles();
    map.setTerrain(1, 1, map.terrainAt(1, 1));
    expect(map.takeDirtyTiles(), isEmpty);
    map.setTerrain(1, 1, TerrainKind.water);
    expect(map.takeDirtyTiles(), [map.width + 1]);
  });
}
