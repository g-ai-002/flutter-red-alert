import 'package:flutter_red_alert/game/battle_types.dart';
import 'package:flutter_red_alert/game/entity.dart';
import 'package:flutter_red_alert/game/pathfinding.dart';
import 'package:flutter_red_alert/game/terrain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  GameMap flatMap() {
    const size = 12;
    return GameMap(
      width: size,
      height: size,
      terrain: List.filled(size * size, TerrainKind.grass),
      ore: List.filled(size * size, 0),
    );
  }

  test('在空地上找到最短八方向路径', () {
    final map = flatMap();
    final finder = PathFinder(map: map, isBlocked: map.blocked);
    final path = finder.find(const TilePoint(0, 0), const TilePoint(5, 5));
    expect(path, isNotNull);
    expect(path!.length, 5);
    expect(path.last, const TilePoint(5, 5));
  });

  test('绕过岩石障碍', () {
    final map = flatMap();
    for (var y = 0; y <= 8; y++) {
      map.setTerrain(4, y, TerrainKind.rock);
    }
    final finder = PathFinder(map: map, isBlocked: map.blocked);
    final path = finder.find(const TilePoint(1, 1), const TilePoint(8, 1));
    expect(path, isNotNull);
    expect(path!.any((p) => p.x == 4 && p.y <= 8), isFalse);
    for (final point in path) {
      expect(map.blocked(point.x, point.y), isFalse);
    }
  });

  test('目标被完全包围时返回 null', () {
    final map = flatMap();
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        if (dx == 0 && dy == 0) continue;
        map.setTerrain(5 + dx, 5 + dy, TerrainKind.water);
      }
    }
    final finder = PathFinder(map: map, isBlocked: map.blocked);
    expect(finder.find(const TilePoint(0, 0), const TilePoint(5, 5)), isNull);
  });

  test('起点即终点返回空路径', () {
    final map = flatMap();
    final finder = PathFinder(map: map, isBlocked: map.blocked);
    expect(finder.find(const TilePoint(2, 2), const TilePoint(2, 2)), isEmpty);
  });

  test('复用寻路缓冲后连续搜索互不影响', () {
    final map = flatMap();
    for (var y = 0; y <= 8; y++) {
      map.setTerrain(4, y, TerrainKind.rock);
    }
    final finder = PathFinder(map: map, isBlocked: map.blocked);
    final queries = [
      (const TilePoint(1, 1), const TilePoint(8, 1)),
      (const TilePoint(0, 0), const TilePoint(5, 5)),
      (const TilePoint(8, 8), const TilePoint(1, 1)),
      (const TilePoint(5, 5), const TilePoint(5, 5)),
    ];
    List<String>? expected;
    for (var round = 0; round < 3; round++) {
      final results = [
        for (final query in queries)
          finder.find(query.$1, query.$2)?.map((point) => '${point.x},${point.y}').toList(),
      ];
      if (expected == null) {
        expected = results.expand((path) => path ?? ['null']).toList();
        continue;
      }
      expect(
        results.expand((path) => path ?? ['null']).toList(),
        expected,
        reason: '第 $round 轮复用了上一轮的缓冲，结果应保持一致',
      );
    }
  });

  test('目标被围死后再搜索可达目标仍能成功', () {
    final map = flatMap();
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        if (dx == 0 && dy == 0) continue;
        map.setTerrain(5 + dx, 5 + dy, TerrainKind.water);
      }
    }
    final finder = PathFinder(map: map, isBlocked: map.blocked);
    expect(finder.find(const TilePoint(0, 0), const TilePoint(5, 5)), isNull);
    final path = finder.find(const TilePoint(0, 0), const TilePoint(8, 8));
    expect(path, isNotNull);
    expect(path!.last, const TilePoint(8, 8));
  });
}
