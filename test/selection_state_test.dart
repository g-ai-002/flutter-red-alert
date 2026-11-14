import 'dart:ui';

import 'package:flutter_red_alert/game/battle_state.dart';
import 'package:flutter_red_alert/game/battle_types.dart';
import 'package:flutter_red_alert/game/selection_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SelectionState selectionOf(BattleState state) => SelectionState(state: state, team: Team.red);

  test('替换与追加选择，再次追加会取消', () {
    final state = BattleState.create();
    final a = state.spawnUnitForTest(Team.red, UnitKind.rifle, const Offset(11.5, 32.5));
    final b = state.spawnUnitForTest(Team.red, UnitKind.rifle, const Offset(12.5, 33.5));
    final selection = selectionOf(state);
    selection.selectActor(a);
    expect(selection.ids, {a.id});
    selection.selectActor(b, additive: true);
    expect(selection.ids, {a.id, b.id});
    selection.selectActor(b, additive: true);
    expect(selection.ids, {a.id});
  });

  test('多选摘要汇总生命值，混编显示统称', () {
    final state = BattleState.create();
    final rifle = state.spawnUnitForTest(Team.red, UnitKind.rifle, const Offset(11.5, 32.5));
    final rifle2 = state.spawnUnitForTest(Team.red, UnitKind.rifle, const Offset(12.5, 32.5));
    final selection = selectionOf(state)
      ..selectActor(rifle)
      ..selectActor(rifle2, additive: true);
    final summary = selection.summary!;
    expect(summary.name, '步兵');
    expect(summary.count, 2);
    expect(summary.hp, rifle.hp + rifle2.hp);

    final tank = state.spawnUnitForTest(Team.red, UnitKind.lightTank, const Offset(13.5, 32.5));
    selection.selectActor(tank, additive: true);
    expect(selection.summary!.name, '混编部队');
    expect(selection.summary!.icon, '编');
  });

  test('框选只包含己方单位，不改变非追加选择的旧结果', () {
    final state = BattleState.create();
    final inside = state.spawnUnitForTest(Team.red, UnitKind.rifle, const Offset(12.5, 33.5));
    state.spawnUnitForTest(Team.red, UnitKind.rifle, const Offset(30.5, 10.5));
    final enemy = state.spawnUnitForTest(Team.blue, UnitKind.rifle, const Offset(13.5, 33.5));
    final selection = selectionOf(state)..selectRect(const Rect.fromLTRB(11, 32, 15, 35));
    expect(selection.ids, {inside.id});
    expect(selection.ids, isNot(contains(enemy.id)));
  });

  test('全选同类按兵种、采矿车与建筑分别处理', () {
    final state = BattleState.create();
    final tank = state.spawnUnitForTest(Team.red, UnitKind.lightTank, const Offset(11.5, 32.5));
    final tank2 = state.spawnUnitForTest(Team.red, UnitKind.lightTank, const Offset(12.5, 32.5));
    final heavy = state.spawnUnitForTest(Team.red, UnitKind.heavyTank, const Offset(13.5, 32.5));
    final selection = selectionOf(state)..selectActor(tank);
    selection.selectAllSameKind();
    expect(selection.ids, {tank.id, tank2.id});
    expect(selection.ids, isNot(contains(heavy.id)));

    final building = state.buildingsOf(Team.red).first;
    selection.selectActor(building);
    selection.selectAllSameKind();
    expect(selection.ids.length, state.unitsOf(Team.red).length);
  });

  test('选中的是建筑时不能下达单位指令', () {
    final state = BattleState.create();
    final building = state.buildingsOf(Team.red).first;
    final selection = selectionOf(state)..selectActor(building);
    expect(selection.canCommand, isFalse);
    final summary = selection.summary!;
    expect(summary.isBuilding, isTrue);
    expect(summary.icon, building.icon);
    expect(summary.name, building.displayName);

    final unit = state.spawnUnitForTest(Team.red, UnitKind.rifle, const Offset(11.5, 32.5));
    selection.selectActor(unit);
    expect(selection.canCommand, isTrue);
    expect(selection.summary!.isBuilding, isFalse);
  });

  test('清除与裁剪失效目标', () {
    final state = BattleState.create();
    final unit = state.spawnUnitForTest(Team.red, UnitKind.rifle, const Offset(11.5, 32.5));
    final selection = selectionOf(state)..selectActor(unit);
    unit.applyDamage(99999);
    state.update(1 / 60);
    expect(selection.actors, isEmpty);
    expect(selection.summary, isNull);
    expect(selection.canCommand, isFalse);
    selection.prune();
    expect(selection.ids, isEmpty);
    selection.clear();
    expect(selection.ids, isEmpty);
  });
}
