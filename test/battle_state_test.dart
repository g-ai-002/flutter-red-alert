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
  group('初始布置', () {
    test('双方各有指挥中心、电厂、精炼厂与两辆采矿车', () {
      final state = BattleState.create();
      for (final team in Team.values) {
        expect(state.countBuildings(team, BuildingKind.hq), 1);
        expect(state.countBuildings(team, BuildingKind.power), 1);
        expect(state.countBuildings(team, BuildingKind.refinery), 1);
        expect(state.unitsOf(team).where((u) => u.isHarvester).length, 2);
      }
      expect(state.creditsRed, BattleDifficulty.normal.playerCredits);
      expect(state.result, isNull);
    });

    test('电力收支平衡且初始有盈余', () {
      final state = BattleState.create();
      expect(state.powerProduced(Team.red), greaterThan(state.powerUsed(Team.red)));
      expect(state.powerFactor(Team.red), 1);
    });

    test('建筑数量与电力在生成、阵亡时增量维护', () {
      final state = BattleState.create();
      final produced = state.powerProduced(Team.red);
      final used = state.powerUsed(Team.red);
      expect(state.countBuildings(Team.red, BuildingKind.tower), 0);

      final tower = state.spawnBuildingForTest(Team.red, BuildingKind.tower, 12, 32);
      expect(state.countBuildings(Team.red, BuildingKind.tower), 1);
      expect(state.powerUsed(Team.red), used + 15);

      final power = state
          .buildingsOf(Team.red)
          .firstWhere((b) => b.spec.kind == BuildingKind.power);
      power.applyDamage(999999);
      tower.applyDamage(999999);
      state.update(0.016);
      expect(state.countBuildings(Team.red, BuildingKind.tower), 0);
      expect(state.powerUsed(Team.red), used);
      expect(state.powerProduced(Team.red), produced - 120);
    });
  });

  group('生产与建造', () {
    test('兵营可以生产，战车工厂缺少前置时锁定', () {
      final state = BattleState.create();
      expect(state.canProduce(Team.red, ProductionCategory.structure, 'barracks'), isTrue);
      expect(
        state.canProduce(Team.red, ProductionCategory.structure, 'factory'),
        isTrue,
        reason: '精炼厂已就绪，战车工厂可以排产',
      );
      expect(state.canProduce(Team.red, ProductionCategory.armor, 'lightTank'), isFalse);
    });

    test('资金在开工时扣除，完成后建筑进入待放置', () {
      final state = BattleState.create();
      final before = state.creditsRed;
      expect(state.startProduction(Team.red, ProductionCategory.structure, 'barracks'), isTrue);
      expect(state.creditsRed, before - 500);
      expect(state.jobOf(Team.red, ProductionCategory.structure), isNotNull);
      simulate(state, 13);
      expect(state.jobOf(Team.red, ProductionCategory.structure), isNull);
      expect(state.readyStructuresOf(Team.red), contains(BuildingKind.barracks));
    });

    test('建筑放置校验地形、重叠与基地距离', () {
      final state = BattleState.create();
      final spec = buildingSpecs[BuildingKind.barracks]!;
      expect(state.canPlaceBuilding(spec, 11, 32, team: Team.red), isTrue);
      expect(state.canPlaceBuilding(spec, 0, 0, team: Team.red), isFalse);
      expect(state.canPlaceBuilding(spec, 30, 30, team: Team.red), isFalse, reason: '远离己方建筑不能放置');
      expect(state.canPlaceBuilding(spec, 36, 8, team: Team.red), isFalse, reason: '不能与敌方指挥中心重叠');
    });

    test('取消生产返还资金', () {
      final state = BattleState.create();
      final before = state.creditsRed;
      state.startProduction(Team.red, ProductionCategory.structure, 'tower');
      state.cancelProduction(Team.red, ProductionCategory.structure);
      expect(state.creditsRed, before);
      expect(state.jobOf(Team.red, ProductionCategory.structure), isNull);
    });

    test('步兵在兵营完成后可以训练并出厂', () {
      final state = BattleState.create();
      final barracks = state.spawnBuildingForTest(Team.red, BuildingKind.barracks, 12, 32);
      expect(barracks.alive, isTrue);
      final unitsBefore = state.unitsOf(Team.red).length;
      expect(state.startProduction(Team.red, ProductionCategory.infantry, 'rifle'), isTrue);
      simulate(state, 8);
      expect(state.unitsOf(Team.red).length, unitsBefore + 1);
      expect(state.unitsOf(Team.red).any((u) => u.spec.kind == UnitKind.rifle), isTrue);
    });

    test('指挥中心被摧毁后只要有其他建筑即可重建', () {
      final state = BattleState.create();
      final hq = state.buildingsOf(Team.red).firstWhere((b) => b.spec.kind == BuildingKind.hq);
      hq.applyDamage(99999);
      state.update(0.016);
      expect(state.hasBuilding(Team.red, BuildingKind.hq), isFalse);
      expect(state.canProduce(Team.red, ProductionCategory.structure, 'hq'), isTrue);
      expect(state.canProduce(Team.red, ProductionCategory.structure, 'power'), isFalse);
    });
  });

  group('战斗与胜负', () {
    test('火箭兵持续攻击敌方建筑', () {
      final state = BattleState.create();
      final target = state.spawnBuildingForTest(Team.blue, BuildingKind.tower, 14, 30);
      final attacker = state.spawnUnitForTest(Team.red, UnitKind.rocket, const Offset(10.5, 30.5));
      state.issueAttack([attacker], target.id);
      final hpBefore = target.hp;
      simulate(state, 2.2);
      expect(target.hp, lessThan(hpBefore));
    });

    test('防御塔自动攻击射程内敌军', () {
      final state = BattleState.create();
      final tower = state.spawnBuildingForTest(Team.blue, BuildingKind.tower, 16, 30);
      final victim = state.spawnUnitForTest(Team.red, UnitKind.rifle, const Offset(11.5, 30.5));
      final hpBefore = victim.hp;
      simulate(state, 1.2);
      expect(victim.hp, lessThan(hpBefore));
      expect(tower.alive, isTrue);
    });

    test('蓝军建筑全部摧毁后判胜', () {
      final state = BattleState.create();
      for (final building in List.of(state.buildingsOf(Team.blue))) {
        building.applyDamage(99999);
      }
      state.update(0.016);
      expect(state.result, BattleResult.victory);
    });

    test('赤军建筑全部摧毁后判负', () {
      final state = BattleState.create();
      for (final building in List.of(state.buildingsOf(Team.red))) {
        building.applyDamage(99999);
      }
      state.update(0.016);
      expect(state.result, BattleResult.defeat);
    });

    test('阵亡单位从战场移除', () {
      final state = BattleState.create();
      final unit = state.spawnUnitForTest(Team.red, UnitKind.rifle, const Offset(10.5, 30.5));
      expect(state.actorById(unit.id), same(unit));
      unit.applyDamage(99999);
      state.update(0.016);
      expect(state.unitsOf(Team.red).contains(unit), isFalse);
      expect(state.actorById(unit.id), isNull);
    });

    test('单位索引在批量阵亡后保持一致', () {
      final state = BattleState.create();
      final units = [
        for (var i = 0; i < 6; i++)
          state.spawnUnitForTest(Team.red, UnitKind.rifle, Offset(9.5 + i, 30.5)),
      ];
      for (final unit in units) {
        expect(state.actorById(unit.id), same(unit));
      }
      for (final unit in units.take(3)) {
        unit.applyDamage(99999);
      }
      state.update(0.016);
      for (final unit in units.take(3)) {
        expect(state.actorById(unit.id), isNull);
      }
      for (final unit in units.skip(3)) {
        expect(state.actorById(unit.id), same(unit));
      }
      expect(state.actors.where((actor) => actor.alive).length, state.actors.length);
    });
  });

  group('经济', () {
    test('采矿车自动往返矿区并带来资金', () {
      final state = BattleState.create();
      final before = state.creditsRed;
      simulate(state, 45);
      expect(state.creditsRed, greaterThan(before));
      final harvester = state.unitsOf(Team.red).firstWhere((u) => u.isHarvester);
      expect(harvester.phase, isNot(HarvesterPhase.idle));
    });

    test('手动移动采矿车后仍会恢复自动采矿', () {
      final state = BattleState.create();
      final harvester = state.unitsOf(Team.red).firstWhere((u) => u.isHarvester);
      state.issueMove([harvester], const Offset(12.5, 32.5));
      expect(harvester.phase, HarvesterPhase.moving);
      simulate(state, 20);
      expect(harvester.phase, isNot(HarvesterPhase.moving));
    });
  });
}
