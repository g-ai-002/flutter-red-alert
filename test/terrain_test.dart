import 'package:flutter_red_alert/game/battle_types.dart';
import 'package:flutter_red_alert/game/terrain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GameMap', () {
    test('固定尺寸与基础地形分布', () {
      final map = GameMap.generate();
      expect(map.width, 44);
      expect(map.height, 44);
      expect(map.countOf(TerrainKind.water), greaterThan(10));
      expect(map.countOf(TerrainKind.ore), greaterThan(60));
      expect(map.countOf(TerrainKind.rock), greaterThan(10));
    });

    test('双方基地核心区域平坦可建造', () {
      final map = GameMap.generate();
      for (final base in [GameMap.redBase, GameMap.blueBase]) {
        for (var dy = -2; dy <= 2; dy++) {
          for (var dx = -2; dx <= 2; dx++) {
            final x = base.dx.floor() + dx;
            final y = base.dy.floor() + dy;
            expect(map.blocked(x, y), isFalse, reason: '基地 ($x,$y) 不应被阻挡');
            expect(map.buildable(x, y), isTrue, reason: '基地 ($x,$y) 应可建造');
          }
        }
      }
    });

    test('矿区关于地图中心对称', () {
      final map = GameMap.generate();
      for (var y = 0; y < map.height; y++) {
        for (var x = 0; x < map.width; x++) {
          final mx = map.width - 1 - x;
          final my = map.height - 1 - y;
          expect(
            map.terrainAt(x, y) == TerrainKind.ore,
            map.terrainAt(mx, my) == TerrainKind.ore,
            reason: '($x,$y) 与 ($mx,$my) 的矿脉应镜像',
          );
        }
      }
    });

    test('矿石采空后变为泥地并递增版本号', () {
      final map = GameMap.generate();
      var oreTile = const (0, 0);
      outer:
      for (var y = 0; y < map.height; y++) {
        for (var x = 0; x < map.width; x++) {
          if (map.oreAt(x, y) > 0) {
            oreTile = (x, y);
            break outer;
          }
        }
      }
      final beforeVersion = map.version;
      final beforeOreTiles = map.oreIndices.length;
      final amount = map.oreAt(oreTile.$1, oreTile.$2);
      final mined = map.mine(oreTile.$1, oreTile.$2, amount);
      expect(mined, amount);
      expect(map.oreAt(oreTile.$1, oreTile.$2), 0);
      expect(map.terrainAt(oreTile.$1, oreTile.$2), TerrainKind.dirt);
      expect(map.version, greaterThan(beforeVersion));
      expect(map.oreIndices.length, beforeOreTiles - 1);
      expect(map.oreIndices.contains(oreTile.$2 * map.width + oreTile.$1), isFalse);
    });

    test('矿点索引覆盖全部矿石格且采空后移除', () {
      final map = GameMap.generate();
      final indices = map.oreIndices.toList();
      expect(indices.length, map.countOf(TerrainKind.ore));
      for (final index in indices.take(10)) {
        expect(map.oreAt(index % map.width, index ~/ map.width), greaterThan(0));
      }
      final first = indices.first;
      map.mine(first % map.width, first ~/ map.width, 999999);
      expect(map.oreIndices.contains(first), isFalse);
    });

    test('道路提升移动速度', () {
      final map = GameMap.generate();
      var roadFound = false;
      var grassFound = false;
      for (var y = 0; y < map.height && !(roadFound && grassFound); y++) {
        for (var x = 0; x < map.width; x++) {
          final kind = map.terrainAt(x, y);
          if (kind == TerrainKind.road && !roadFound) {
            expect(map.speedFactor(x, y), 1.3);
            roadFound = true;
          }
          if (kind == TerrainKind.grass && !grassFound) {
            expect(map.speedFactor(x, y), 1.0);
            grassFound = true;
          }
        }
      }
      expect(roadFound, isTrue);
      expect(grassFound, isTrue);
    });
  });
}
