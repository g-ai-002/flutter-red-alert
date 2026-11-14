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

  test('资金增减不会低于零', () {
    final state = BattleState.create();
    final before = state.creditsOf(Team.red);
    state.addCredits(Team.red, -before * 2);
    expect(state.creditsOf(Team.red), 0);
    state.addCredits(Team.red, 300);
    expect(state.creditsOf(Team.red), 300);
  });
}
