import 'package:flutter_red_alert/game/ai_commander.dart';
import 'package:flutter_red_alert/game/battle_state.dart';
import 'package:flutter_red_alert/game/battle_types.dart';
import 'package:flutter_red_alert/game/entity.dart';
import 'package:flutter_test/flutter_test.dart';

void simulate(BattleState state, double seconds, {double step = 1 / 60}) {
  var remaining = seconds;
  while (remaining > 0) {
    final dt = remaining < step ? remaining : step;
    state.update(dt);
    remaining -= dt;
  }
}

void main() {
  group('武装直升机', () {
    test('无视地形直飞并抵达目标', () {
      final state = BattleState.create();
      for (var y = 18; y <= 22; y++) {
        for (var x = 14; x <= 16; x++) {
          state.map.setTerrain(x, y, TerrainKind.water);
        }
      }
      final gunship = state.spawnUnitForTest(Team.red, UnitKind.gunship, const Offset(10.5, 20.5));
      state.issueMove([gunship], const Offset(21.5, 20.5));

      simulate(state, 4);

      expect(gunship.x, closeTo(21.5, 0.4));
      expect(gunship.y, closeTo(20.5, 0.4));
      expect(gunship.order, UnitOrder.idle);
    });

    test('地面步兵无法锁定直升机，火箭兵可以将其击伤', () {
      final state = BattleState.create();
      final gunship = state.spawnUnitForTest(Team.blue, UnitKind.gunship, const Offset(21.5, 20.5));
      final rifle = state.spawnUnitForTest(Team.red, UnitKind.rifle, const Offset(19.5, 20.5));
      final rocket = state.spawnUnitForTest(Team.red, UnitKind.rocket, const Offset(18.5, 20.5));
      final hp = gunship.hp;

      state.issueAttack([rifle], gunship.id);
      expect(rifle.targetId, isNull, reason: '步枪打不到空中目标');

      state.issueAttack([rocket], gunship.id);
      simulate(state, 2);

      expect(rocket.targetId, gunship.id);
      expect(gunship.hp, lessThan(hp));
    });

    test('直升机会追击远处的地面目标', () {
      final state = BattleState.create();
      final target = state.spawnUnitForTest(Team.blue, UnitKind.rifle, const Offset(28.5, 20.5));
      final gunship = state.spawnUnitForTest(Team.red, UnitKind.gunship, const Offset(18.5, 20.5));
      final hp = target.hp;
      final startX = gunship.x;

      state.issueAttack([gunship], target.id);
      simulate(state, 2.5);

      expect(gunship.x, greaterThan(startX));
      expect(target.hp, lessThan(hp));
    });

    test('地面炮火的溅射不会误伤直升机', () {
      final state = BattleState.create();
      final target = state.spawnUnitForTest(Team.blue, UnitKind.rifle, const Offset(25.5, 20.5));
      final gunship = state.spawnUnitForTest(Team.blue, UnitKind.gunship, const Offset(25.9, 20.5));
      final gun = state.spawnUnitForTest(Team.red, UnitKind.artillery, const Offset(20.5, 20.5));
      final targetHp = target.hp;
      final gunshipHp = gunship.hp;

      state.issueAttack([gun], target.id);
      simulate(state, 0.4);

      expect(target.hp, lessThan(targetHp));
      expect(gunship.hp, gunshipHp, reason: '地面炮弹的溅射不应命中低空目标');
    });
  });

  group('防空炮塔', () {
    test('只攻击空中目标，地面部队可以安全通过', () {
      final state = BattleState.create();
      final tower = state.spawnBuildingForTest(Team.blue, BuildingKind.airDefense, 20, 20);
      final rifle = state.spawnUnitForTest(Team.red, UnitKind.rifle, const Offset(21.5, 21.5));
      final gunship = state.spawnUnitForTest(Team.red, UnitKind.gunship, const Offset(24.5, 20.5));
      final rifleHp = rifle.hp;
      final gunshipHp = gunship.hp;

      simulate(state, 1.5);

      expect(rifle.hp, rifleHp, reason: '防空炮塔不能对地');
      expect(gunship.hp, lessThan(gunshipHp));
      expect(tower.alive, isTrue);
    });

    test('哨戒炮塔无法攻击直升机', () {
      final state = BattleState.create();
      state.spawnBuildingForTest(Team.blue, BuildingKind.tower, 20, 20);
      final gunship = state.spawnUnitForTest(Team.red, UnitKind.gunship, const Offset(23.5, 20.5));
      final hp = gunship.hp;

      simulate(state, 2);

      expect(gunship.hp, hp);
    });

    test('参数表标注对空与对地能力', () {
      final aa = buildingSpecs[BuildingKind.airDefense]!;
      expect(aa.canHitAir, isTrue);
      expect(aa.canHitGround, isFalse);
      expect(aa.range, greaterThan(unitSpecs[UnitKind.gunship]!.range));
      expect(unitSpecs[UnitKind.gunship]!.isAir, isTrue);
      expect(unitSpecs[UnitKind.rifle]!.canHitAir, isFalse);
      expect(unitSpecs[UnitKind.rocket]!.canHitAir, isTrue);
    });
  });

  group('生产与 AI', () {
    test('直升机与防空炮塔可在对应建筑生产', () {
      final state = BattleState.create();
      state.spawnBuildingForTest(Team.red, BuildingKind.factory, 12, 32);
      expect(state.canProduce(Team.red, ProductionCategory.armor, 'gunship'), isTrue);
      expect(state.canProduce(Team.red, ProductionCategory.structure, 'airDefense'), isTrue);

      expect(state.startProduction(Team.red, ProductionCategory.armor, 'gunship'), isTrue);
      expect(state.startProduction(Team.red, ProductionCategory.structure, 'airDefense'), isTrue);
      simulate(state, 17);

      expect(state.unitsOf(Team.red).any((u) => u.isAir), isTrue);
      expect(state.readyStructuresOf(Team.red), contains(BuildingKind.airDefense));
    });

    test('敌方空军出现时 AI 会优先补防空并生产直升机', () {
      final state = BattleState.create();
      state.spawnUnitForTest(Team.red, UnitKind.gunship, const Offset(32.5, 30.5));
      // 给蓝军补齐生产建筑与资金，验证 AI 的选择而不是攒钱速度。
      state.spawnBuildingForTest(Team.blue, BuildingKind.factory, 30, 13);
      state.spawnBuildingForTest(Team.blue, BuildingKind.barracks, 31, 15);
      state.spawnUnitForTest(Team.blue, UnitKind.harvester, const Offset(38.5, 6.5));
      state.addCredits(Team.blue, 10000);
      final ai = AiCommander(team: Team.blue, difficulty: BattleDifficulty.normal);
      state.onAiTick = ai.update;

      simulate(state, 60);

      expect(
        state.countBuildings(Team.blue, BuildingKind.airDefense),
        greaterThan(0),
        reason: '敌方空军出现后应补防空',
      );
      expect(state.unitsOf(Team.blue).any((u) => u.isAir), isTrue, reason: 'AI 应生产武装直升机');
    });
  });
}
