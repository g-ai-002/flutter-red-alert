import 'dart:ui';

import 'package:flutter_red_alert/game/battle_state.dart';
import 'package:flutter_red_alert/game/battle_types.dart';
import 'package:flutter_red_alert/game/entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('枚举 id 还原建筑与单位，未知 id 返回 null', () {
    expect(buildingKindFromId('airDefense'), BuildingKind.airDefense);
    expect(unitKindFromId('gunship'), UnitKind.gunship);
    expect(buildingKindFromId('gunship'), isNull);
    expect(unitKindFromId('barracks'), isNull);
    expect(unitKindFromId('nope'), isNull);
  });

  test('单位与建筑都能给出单字图标', () {
    final state = BattleState.create();
    final tank = state.spawnUnitForTest(Team.red, UnitKind.heavyTank, const Offset(11.5, 32.5));
    final tower = state.spawnBuildingForTest(Team.red, BuildingKind.tower, 13, 32);
    expect(tank.icon, unitSpecs[UnitKind.heavyTank]!.icon);
    expect(tower.icon, buildingSpecs[BuildingKind.tower]!.icon);
  });

  test('矩形间距：框内为 0，框外取两个轴向间距的较大值', () {
    const rect = Rect.fromLTWH(4, 6, 3, 2);
    expect(rectGap(const Offset(5, 7), rect), 0);
    expect(rectGap(const Offset(9, 7), rect), 2);
    expect(rectGap(const Offset(5, 1), rect), 5);
    expect(rectGap(const Offset(9, 9), rect), 2);
    expect(distanceToRect(const Offset(9, 9), rect), closeTo(2.236, 0.001));
  });

  test('建筑占格遍历覆盖地基，并可提前结束', () {
    final tiles = <(int, int)>[];
    final completed = forEachBuildingTile(2, 3, 2, 2, (x, y) {
      tiles.add((x, y));
      return tiles.length < 3;
    });
    expect(completed, isFalse);
    expect(tiles, [(2, 3), (3, 3), (2, 4)]);
  });

  test('建筑放置后占满地基，拆除后释放全部占位', () {
    final state = BattleState.create();
    final refinery = state.spawnBuildingForTest(Team.red, BuildingKind.refinery, 12, 34);
    final covered = <(int, int)>[];
    refinery.forEachTile((x, y) {
      covered.add((x, y));
      expect(state.buildingAt(x, y), same(refinery));
      return true;
    });
    expect(covered.length, 6);

    refinery.hp = 0;
    state.update(1 / 60);
    for (final (x, y) in covered) {
      expect(state.buildingAt(x, y), isNull);
    }
  });

  test('圆形格扫描按格心距离裁剪并限制在地图内', () {
    final centerOnly = <(int, int)>[];
    forEachTileInDisc(
      mapWidth: 5,
      mapHeight: 5,
      cx: 2.5,
      cy: 2.5,
      radius: 0.6,
      visit: (x, y) => centerOnly.add((x, y)),
    );
    expect(centerOnly, [(2, 2)]);

    final cross = <(int, int)>[];
    forEachTileInDisc(
      mapWidth: 5,
      mapHeight: 5,
      cx: 2.5,
      cy: 2.5,
      radius: 1.1,
      visit: (x, y) => cross.add((x, y)),
    );
    expect(cross.toSet(), {(2, 1), (1, 2), (2, 2), (3, 2), (2, 3)});

    final corner = <(int, int)>[];
    forEachTileInDisc(
      mapWidth: 4,
      mapHeight: 4,
      cx: 0.5,
      cy: 0.5,
      radius: 1.1,
      visit: (x, y) => corner.add((x, y)),
    );
    expect(corner.toSet(), {(0, 0), (1, 0), (0, 1)});
  });

  test('采矿车与工程兵不计入战斗部队', () {
    final state = BattleState.create();
    expect(state.armySize(Team.red), 0);
    final harvester = state.spawnUnitForTest(Team.red, UnitKind.harvester, const Offset(11.5, 32.5));
    final engineer = state.spawnUnitForTest(Team.red, UnitKind.engineer, const Offset(11.5, 32.5));
    final rifle = state.spawnUnitForTest(Team.red, UnitKind.rifle, const Offset(11.5, 32.5));

    expect(harvester.isCombat, isFalse);
    expect(engineer.isCombat, isFalse);
    expect(rifle.isCombat, isTrue);
    expect(state.armySize(Team.red), 1);
  });

  test('资金增减不会低于零', () {
    final state = BattleState.create();
    final before = state.creditsOf(Team.red);
    state.addCredits(Team.red, -before * 2);
    expect(state.creditsOf(Team.red), 0);
    state.addCredits(Team.red, 300);
    expect(state.creditsOf(Team.red), 300);
  });
}
