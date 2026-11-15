import 'package:flutter_red_alert/game/battle_state.dart';
import 'package:flutter_red_alert/game/battle_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('索敌网格', () {
    test('只返回射程内最近的敌军', () {
      final state = BattleState.create();
      final near = state.spawnUnitForTest(Team.blue, UnitKind.rifle, const Offset(9.5, 35.5));
      state.spawnUnitForTest(Team.blue, UnitKind.rifle, const Offset(14.5, 35.5));
      state.update(0.1);

      final target = state.nearestEnemy(
        Team.red,
        const Offset(10.5, 35.5),
        weapon: unitSpecs[UnitKind.heavyTank]!,
        maxDistance: 7,
      );

      expect(target, same(near));
    });

    test('超出射程与同阵营目标不会入选', () {
      final state = BattleState.create();
      state.spawnUnitForTest(Team.red, UnitKind.rifle, const Offset(9.5, 35.5));
      state.spawnUnitForTest(Team.blue, UnitKind.rifle, const Offset(32.5, 35.5));
      state.update(0.1);

      final target = state.nearestEnemy(
        Team.red,
        const Offset(10.5, 35.5),
        weapon: unitSpecs[UnitKind.heavyTank]!,
        maxDistance: 7,
      );

      expect(target, isNull);
    });

    test('新增敌军在下一次更新重建网格后可被索敌', () {
      final state = BattleState.create();
      state.update(0.01);
      const from = Offset(10.5, 35.5);
      final weapon = unitSpecs[UnitKind.heavyTank]!;

      expect(state.nearestEnemy(Team.red, from, weapon: weapon, maxDistance: 7), isNull);

      final enemy = state.spawnUnitForTest(Team.blue, UnitKind.rifle, const Offset(9.5, 35.5));
      expect(
        state.nearestEnemy(Team.red, from, weapon: weapon, maxDistance: 7),
        isNull,
        reason: '网格还没重建',
      );

      state.update(0.01);
      expect(state.nearestEnemy(Team.red, from, weapon: weapon, maxDistance: 7), same(enemy));
    });
  });
}
