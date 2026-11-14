import 'package:flutter_red_alert/game/battle_state.dart';
import 'package:flutter_red_alert/game/battle_types.dart';
import 'package:flutter_red_alert/game/mission.dart';
import 'package:flutter_red_alert/game/production_catalog.dart';
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
  group('工程兵', () {
    test('自动维修附近的己方建筑', () {
      final state = BattleState.create();
      final hq = state.redBuildings.firstWhere((building) => building.spec.kind == BuildingKind.hq);
      hq.applyDamage(500);
      final damaged = hq.hp;
      state.spawnUnitForTest(Team.red, UnitKind.engineer, const Offset(9.5, 34.5));

      simulate(state, 4);

      expect(hq.hp, greaterThan(damaged + 100));
      expect(hq.hp, lessThanOrEqualTo(hq.maxHp));
    });

    test('不会维修敌方建筑', () {
      final state = BattleState.create();
      final enemy = state.blueBuildings.firstWhere(
        (building) => building.spec.kind == BuildingKind.hq,
      );
      enemy.applyDamage(400);
      final damaged = enemy.hp;
      state.spawnUnitForTest(Team.red, UnitKind.engineer, const Offset(36.5, 12.5));

      simulate(state, 3);

      expect(enemy.hp, damaged);
    });

    test('空闲扫描节流后仍能发现新出现的损伤', () {
      final state = BattleState.create();
      final hq = state.redBuildings.firstWhere((building) => building.spec.kind == BuildingKind.hq);
      state.spawnUnitForTest(Team.red, UnitKind.engineer, const Offset(9.5, 34.5));
      // 先空转一段时间，让扫描节拍处于等待状态，再制造新的损伤。
      simulate(state, 1);
      hq.applyDamage(300);
      final damaged = hq.hp;

      simulate(state, 3);

      expect(hq.hp, greaterThan(damaged));
    });

    test('没有武器，攻击指令不会让它开火', () {
      final state = BattleState.create();
      final target = state.spawnUnitForTest(Team.blue, UnitKind.rifle, const Offset(12.5, 34.5));
      final engineer = state.spawnUnitForTest(
        Team.red,
        UnitKind.engineer,
        const Offset(14.5, 34.5),
      );
      final hp = target.hp;
      state.issueAttack([engineer], target.id);

      simulate(state, 1);

      expect(target.hp, hp);
    });
  });

  group('自行火炮', () {
    test('炮弹会溅射伤害落点附近的敌军', () {
      final state = BattleState.create();
      final front = state.spawnUnitForTest(Team.blue, UnitKind.rifle, const Offset(20.5, 20.5))
        ..x = 20.5
        ..y = 20.5;
      final back = state.spawnUnitForTest(Team.blue, UnitKind.rifle, const Offset(21.2, 20.5))
        ..x = 21.2
        ..y = 20.5;
      final gun = state.spawnUnitForTest(Team.red, UnitKind.artillery, const Offset(27.5, 20.5))
        ..x = 27.5
        ..y = 20.5;
      final frontHp = front.hp;
      final backHp = back.hp;

      simulate(state, 0.4);

      expect(front.hp, lessThan(frontHp));
      expect(back.hp, lessThan(backHp), reason: '副目标应受到一半溅射伤害');
      expect(gun.fireCooldown, greaterThan(0));
    });

    test('目标进入最小射程后无法开火，并会向后拉开距离', () {
      final state = BattleState.create();
      final target = state.spawnUnitForTest(Team.blue, UnitKind.rifle, const Offset(22, 20.5))
        ..x = 22.0
        ..y = 20.5;
      final gun = state.spawnUnitForTest(Team.red, UnitKind.artillery, const Offset(20.5, 20.5))
        ..x = 20.5
        ..y = 20.5;
      final hp = target.hp;
      state.issueAttack([gun], target.id);

      simulate(state, 0.3);

      expect(target.hp, hp);
      expect(gun.x, lessThan(20.5));
    });
  });

  group('生产目录与战役', () {
    test('新兵种进入建造栏且参数正确', () {
      final engineer = ProductionCatalog.byId('engineer');
      final artillery = ProductionCatalog.byId('artillery');
      expect(engineer?.category, ProductionCategory.infantry);
      expect(artillery?.category, ProductionCategory.armor);
      expect(
        ProductionCatalog.of(ProductionCategory.infantry).map((i) => i.id),
        contains('engineer'),
      );
      expect(unitSpecs[UnitKind.engineer]!.isEngineer, isTrue);
      expect(unitSpecs[UnitKind.engineer]!.attack, 0);
      expect(unitSpecs[UnitKind.artillery]!.minRange, greaterThan(0));
      expect(unitSpecs[UnitKind.artillery]!.splash, greaterThan(0));
    });

    test('五关战役依次解锁且都能正常开局', () {
      expect(campaignMissions.length, 5);
      expect(campaignMissions.first.objective, MissionObjective.eradicate);
      expect(campaignMissions.last.objective, MissionObjective.decapitate);
      expect(missionById('ironflood')?.title, contains('铁流'));
      expect(missionById('dawn')?.title, contains('黎明总攻'));

      for (final mission in campaignMissions) {
        final state = BattleState.create(mission: mission);
        expect(state.mission?.id, mission.id);
        expect(state.redUnits.length, 2 + mission.startingArmy.length);
        expect(state.blueUnits.length, 2 + mission.enemyArmy.length);
        expect(state.creditsRed, mission.difficulty.playerCredits + mission.bonusCredits);
        expect(state.blueBuildings.length, greaterThanOrEqualTo(3 + mission.enemyBuildings.length));
      }
    });

    test('工程兵与火炮可以按科技前置生产', () {
      final state = BattleState.create();
      state.spawnBuildingForTest(Team.red, BuildingKind.barracks, 12, 33);
      state.spawnBuildingForTest(Team.red, BuildingKind.factory, 13, 36);
      expect(
        state.canProduce(Team.red, ProductionCategory.infantry, UnitKind.engineer.name),
        isTrue,
      );
      expect(state.canProduce(Team.red, ProductionCategory.armor, UnitKind.artillery.name), isTrue);
      expect(
        state.startProduction(Team.red, ProductionCategory.infantry, UnitKind.engineer.name),
        isTrue,
      );
      expect(
        state.startProduction(Team.red, ProductionCategory.armor, UnitKind.artillery.name),
        isTrue,
      );
      simulate(state, 20);
      expect(state.redUnits.where((u) => u.spec.isEngineer), isNotEmpty);
      expect(state.redUnits.where((u) => u.spec.kind == UnitKind.artillery), isNotEmpty);
    });
  });
}
