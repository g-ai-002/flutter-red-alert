import 'package:flutter_red_alert/game/battle_state.dart';
import 'package:flutter_red_alert/game/battle_types.dart';
import 'package:flutter_red_alert/game/entity.dart';
import 'package:flutter_test/flutter_test.dart';

/// 追击与后撤按周期重算路径；目标格与地图都没变时应复用已有路径。
void main() {
  BattleState chasingState() {
    final state = BattleState.create();
    state.spawnBuildingForTest(Team.blue, BuildingKind.tower, 33, 12);
    final target = state
        .buildingsOf(Team.blue)
        .firstWhere((building) => building.spec.kind == BuildingKind.tower);
    final unit = state.spawnUnitForTest(Team.red, UnitKind.lightTank, const Offset(12.5, 30.5));
    state.issueAttack([unit], target.id);
    state.update(1 / 60);
    return state;
  }

  Unit chasingUnit(BattleState state) =>
      state.unitsOf(Team.red).firstWhere((unit) => unit.spec.kind == UnitKind.lightTank);

  test('目标格未变时追击复用上一次的路径', () {
    final state = chasingState();
    final unit = chasingUnit(state);
    expect(unit.hasPath, isTrue);
    final path = unit.path;

    unit.repathTimer = 0;
    state.update(1 / 60);
    expect(identical(unit.path, path), isTrue, reason: '重算计时到期但目标未变，不应重新寻路');
  });

  test('建筑增减让缓存路径失效', () {
    final state = chasingState();
    final unit = chasingUnit(state);
    final path = unit.path;

    state.spawnBuildingForTest(Team.red, BuildingKind.tower, 12, 34);
    unit.repathTimer = 0;
    state.update(1 / 60);
    expect(identical(unit.path, path), isFalse, reason: '占位表变化后必须重新寻路');
  });

  test('地形变化让缓存路径失效', () {
    final state = chasingState();
    final unit = chasingUnit(state);
    final path = unit.path;

    state.map.setTerrain(20, 20, TerrainKind.rock);
    unit.repathTimer = 0;
    state.update(1 / 60);
    expect(identical(unit.path, path), isFalse, reason: '地形变化后必须重新寻路');
  });
}
