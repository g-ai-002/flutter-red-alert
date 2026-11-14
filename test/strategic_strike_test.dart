import 'dart:ui';

import 'package:flutter_red_alert/game/ai_commander.dart';
import 'package:flutter_red_alert/game/battle_controller.dart';
import 'package:flutter_red_alert/game/battle_state.dart';
import 'package:flutter_red_alert/game/battle_types.dart';
import 'package:flutter_red_alert/game/logic_rate.dart';
import 'package:flutter_red_alert/game/production_catalog.dart';
import 'package:flutter_red_alert/services/sound_service.dart';
import 'package:flutter_test/flutter_test.dart';

void simulate(BattleState state, double seconds, {double step = 1 / 60}) {
  var remaining = seconds;
  while (remaining > 0) {
    final dt = remaining < step ? remaining : step;
    state.update(dt);
    remaining -= dt;
  }
}

void simulateController(BattleController controller, double seconds, {double step = 1 / 60}) {
  var remaining = seconds;
  while (remaining > 0) {
    final dt = remaining < step ? remaining : step;
    controller.tick(dt);
    remaining -= dt;
  }
}

BattleState stateWithSilo(Team team) {
  final state = BattleState.create();
  state.spawnBuildingForTest(
    team,
    BuildingKind.silo,
    team == Team.red ? 10 : 31,
    team == Team.red ? 31 : 12,
  );
  return state;
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SoundService.sink = (_) {};
    SoundService.hapticsEnabled = false;
    SoundService.soundEnabled = false;
  });

  group('导弹发射井', () {
    test('参数与建造前置：需要战车工厂，进入建筑建造栏', () {
      final spec = buildingSpecs[BuildingKind.silo]!;
      expect(spec.cost, 3000);
      expect(spec.power, lessThan(0));
      expect(spec.requires, BuildingKind.factory);
      expect(ProductionCatalog.byId('silo')!.isBuilding, isTrue);

      final state = BattleState.create();
      expect(state.productionBlocker(Team.red, ProductionCategory.structure, 'silo'), '需要战车工厂');
      state.spawnBuildingForTest(Team.red, BuildingKind.factory, 20, 30);
      expect(state.productionBlocker(Team.red, ProductionCategory.structure, 'silo'), isNull);
    });

    test('发射井在线时按时间蓄能，充满后可以发射', () {
      final state = stateWithSilo(Team.red);
      expect(state.strikeProgress(Team.red), 0);
      expect(state.strikeReady(Team.red), isFalse);

      simulate(state, BattleState.strikeChargeSeconds / 2);
      expect(state.strikeProgress(Team.red), closeTo(0.5, 0.02));
      expect(state.strikeReady(Team.red), isFalse);

      simulate(state, BattleState.strikeChargeSeconds / 2 + 1);
      expect(state.strikeReady(Team.red), isTrue);
    });

    test('没有发射井不会蓄能，发射井被摧毁后蓄能清零', () {
      final state = BattleState.create();
      simulate(state, BattleState.strikeChargeSeconds + 2);
      expect(state.strikeProgress(Team.red), 0);
      expect(state.launchStrike(Team.red, const Offset(20.5, 20.5)), isFalse);

      final withSilo = stateWithSilo(Team.red);
      simulate(withSilo, BattleState.strikeChargeSeconds + 1);
      expect(withSilo.strikeReady(Team.red), isTrue);

      final silo = withSilo
          .buildingsOf(Team.red)
          .firstWhere((b) => b.spec.kind == BuildingKind.silo);
      silo.applyDamage(999999);
      simulate(withSilo, 0.1);
      expect(withSilo.hasBuilding(Team.red, BuildingKind.silo), isFalse);
      expect(withSilo.strikeProgress(Team.red), 0);
      expect(withSilo.strikeReady(Team.red), isFalse);
    });
  });

  group('东风快递', () {
    test('只杀伤半径内的敌军，友军与远处目标不受影响', () {
      final state = stateWithSilo(Team.red);
      simulate(state, BattleState.strikeChargeSeconds + 1);
      state.drainEvents();

      final enemy = state.spawnUnitForTest(Team.blue, UnitKind.rifle, const Offset(20.5, 20.5));
      final friend = state.spawnUnitForTest(Team.red, UnitKind.rifle, const Offset(19.4, 20.5));
      final far = state.spawnUnitForTest(Team.blue, UnitKind.rifle, const Offset(31.5, 31.5));
      final tower = state.spawnBuildingForTest(Team.blue, BuildingKind.tower, 21, 20);
      final enemyHp = enemy.hp;
      final friendHp = friend.hp;
      final farHp = far.hp;
      final towerHp = tower.hp;

      expect(state.launchStrike(Team.red, const Offset(20.5, 20.5)), isTrue);

      expect(enemy.hp, lessThan(enemyHp));
      expect(tower.hp, lessThan(towerHp));
      expect(friend.hp, friendHp);
      expect(far.hp, farHp);
      expect(state.strikeReady(Team.red), isFalse);
      expect(
        state.drainEvents().where((event) => event.kind == BattleEventKind.missile),
        hasLength(1),
      );
    });

    test('未蓄满或没有发射井时无法发射', () {
      final state = BattleState.create();
      expect(state.launchStrike(Team.red, const Offset(20.5, 20.5)), isFalse);

      final charging = stateWithSilo(Team.red);
      simulate(charging, BattleState.strikeChargeSeconds / 2);
      expect(charging.launchStrike(Team.red, const Offset(20.5, 20.5)), isFalse);
      expect(charging.strikeProgress(Team.red), closeTo(0.5, 0.02), reason: '失败不消耗蓄能');
    });
  });

  group('AI 与操作', () {
    test('蓝军蓄能完成后用导弹打击赤军指挥中心', () {
      final state = stateWithSilo(Team.blue);
      simulate(state, BattleState.strikeChargeSeconds + 1);
      final hq = state.buildingsOf(Team.red).firstWhere((b) => b.spec.kind == BuildingKind.hq);
      final hp = hq.hp;

      AiCommander(team: Team.blue, difficulty: state.difficulty).update(state, 1);

      expect(hq.hp, lessThan(hp));
      expect(state.strikeReady(Team.blue), isFalse);
    });

    test('瞄准模式下点击地图发射，落点即为打击中心', () {
      final state = stateWithSilo(Team.red);
      final controller = BattleController(state: state, logicRate: LogicRate.hz60);
      state.onAiTick = null;
      controller.camera.updateViewport(const Size(900, 600));
      simulateController(controller, BattleState.strikeChargeSeconds + 1);
      expect(controller.strikeReady, isTrue);

      const target = Offset(20.5, 20.5);
      final enemy = state.spawnUnitForTest(Team.blue, UnitKind.rifle, target);
      controller.camera.focusOn(target);
      controller.toggleStrikeAiming();
      expect(controller.strikeAiming, isTrue);

      controller.tap(controller.camera.worldToScreen(target));
      expect(controller.strikeAiming, isFalse);
      expect(enemy.alive, isFalse);
      expect(controller.strikeReady, isFalse);
    });

    test('未蓄能时进入瞄准会给出发射井提示', () {
      final controller = BattleController(state: BattleState.create(), logicRate: LogicRate.hz60);
      controller.camera.updateViewport(const Size(900, 600));

      controller.toggleStrikeAiming();

      expect(controller.strikeAiming, isFalse);
      expect(controller.toasts.map((toast) => toast.text), contains('需要先建造导弹发射井'));
    });

    test('取消瞄准不会消耗蓄能', () {
      final state = stateWithSilo(Team.red);
      final controller = BattleController(state: state, logicRate: LogicRate.hz60);
      state.onAiTick = null;
      controller.camera.updateViewport(const Size(900, 600));
      simulateController(controller, BattleState.strikeChargeSeconds + 1);

      controller.toggleStrikeAiming();
      controller.cancelStrikeAim();

      expect(controller.strikeAiming, isFalse);
      expect(controller.strikeReady, isTrue);
    });
  });
}
