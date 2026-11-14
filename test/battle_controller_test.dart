import 'dart:ui';

import 'package:flutter_red_alert/game/battle_controller.dart';
import 'package:flutter_red_alert/game/battle_state.dart';
import 'package:flutter_red_alert/game/battle_types.dart';
import 'package:flutter_red_alert/game/entity.dart';
import 'package:flutter_red_alert/game/logic_rate.dart';
import 'package:flutter_red_alert/game/terrain.dart';
import 'package:flutter_red_alert/services/sound_service.dart';
import 'package:flutter_test/flutter_test.dart';

void simulate(BattleController controller, double seconds, {double step = 1 / 60}) {
  var remaining = seconds;
  while (remaining > 0) {
    final dt = remaining < step ? remaining : step;
    controller.tick(dt);
    remaining -= dt;
  }
}

BattleController makeController() {
  final state = BattleState.create();
  final controller = BattleController(state: state, logicRate: LogicRate.hz60);
  controller.camera.updateViewport(const Size(900, 600));
  controller.camera.focusOn(GameMap.redBase);
  return controller;
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SoundService.sink = (_) {};
    SoundService.hapticsEnabled = false;
    SoundService.soundEnabled = false;
  });

  test('点击己方单位即可选中', () {
    final controller = makeController();
    final unit = controller.state.spawnUnitForTest(
      Team.red,
      UnitKind.rifle,
      const Offset(11.5, 32.5),
    );
    controller.camera.focusOn(unit.position);
    controller.tap(controller.camera.worldToScreen(unit.position));
    expect(controller.selectedIds, contains(unit.id));
    expect(controller.selection?.name, '步兵');
  });

  test('选中部队后点击地面下达移动指令', () {
    final controller = makeController();
    final unit = controller.state.spawnUnitForTest(
      Team.red,
      UnitKind.rifle,
      const Offset(11.5, 32.5),
    );
    controller.camera.focusOn(unit.position);
    controller.tap(controller.camera.worldToScreen(unit.position));
    final target = unit.position + const Offset(4, 0);
    controller.tap(controller.camera.worldToScreen(target));
    expect(unit.order, UnitOrder.move);
    expect(controller.canCommandSelection, isTrue);
  });

  test('框选选中矩形内的己方单位', () {
    final controller = makeController();
    final a = controller.state.spawnUnitForTest(Team.red, UnitKind.rifle, const Offset(11.5, 32.5));
    final b = controller.state.spawnUnitForTest(Team.red, UnitKind.rifle, const Offset(12.5, 33.5));
    controller.camera.focusOn(const Offset(12, 33));
    final topLeft = controller.camera.worldToScreen(const Offset(10, 31));
    final bottomRight = controller.camera.worldToScreen(const Offset(14, 35));
    controller.selectRect(Rect.fromPoints(topLeft, bottomRight));
    expect(controller.selectedIds, containsAll([a.id, b.id]));
  });

  test('生产建筑完成后可进入放置模式并落地', () {
    final controller = makeController();
    final before = controller.state.buildingsOf(Team.red).length;
    controller.requestProduction(ProductionCategory.structure, 'barracks');
    expect(controller.state.jobOf(Team.red, ProductionCategory.structure), isNotNull);
    simulate(controller, 13);
    expect(controller.state.readyStructuresOf(Team.red), contains(BuildingKind.barracks));
    controller.beginPlacement('barracks');
    expect(controller.isPlacing, isTrue);
    expect(controller.ghostTile, isNotNull);
    final tile = controller.ghostTile!;
    controller.camera.focusOn(Offset(tile.x + 1, tile.y + 1));
    final screen = controller.camera.worldToScreen(Offset(tile.x + 1, tile.y + 1));
    controller.tap(screen);
    expect(controller.isPlacing, isFalse);
    expect(controller.state.buildingsOf(Team.red).length, before + 1);
  });

  test('移动放置预览只在落点合法性变化时刷新界面', () {
    final controller = makeController();
    controller.requestProduction(ProductionCategory.structure, 'barracks');
    simulate(controller, 13);
    controller.beginPlacement('barracks');
    expect(controller.isPlacing, isTrue);
    final tile = controller.ghostTile!;
    expect(controller.ghostValid, isTrue);

    var notifications = 0;
    controller.addListener(() => notifications++);
    // 同一格内微调，合法性不变，预览框由渲染层逐帧读取即可。
    controller.updateGhost(controller.camera.worldToScreen(Offset(tile.x + 1.05, tile.y + 1.05)));
    expect(notifications, 0);
    expect(controller.ghostTile, tile);

    // 移出基地范围后合法性翻转为 false，需要刷新提示条。
    controller.updateGhost(controller.camera.worldToScreen(const Offset(1.5, 1.5)));
    expect(notifications, 1);
    expect(controller.ghostValid, isFalse);
    expect(controller.ghostTile, isNot(tile));
  });

  test('暂停与倍速切换', () {
    final controller = makeController();
    expect(controller.paused, isFalse);
    controller.setPaused(true);
    expect(controller.paused, isTrue);
    controller.setPaused(false);
    expect(controller.speed, 1);
    controller.cycleSpeed();
    expect(controller.speed, 2);
    controller.cycleSpeed();
    expect(controller.speed, 1);
  });

  test('全选同类与停止指令', () {
    final controller = makeController();
    final first = controller.state.spawnUnitForTest(
      Team.red,
      UnitKind.lightTank,
      const Offset(11.5, 32.5),
    );
    final second = controller.state.spawnUnitForTest(
      Team.red,
      UnitKind.lightTank,
      const Offset(12.5, 33.5),
    );
    controller.camera.focusOn(first.position);
    controller.tap(controller.camera.worldToScreen(first.position));
    controller.selectAllSameKind();
    expect(controller.selectedIds, containsAll([first.id, second.id]));
    final target = first.position + const Offset(5, 0);
    controller.tap(controller.camera.worldToScreen(target));
    expect(first.order, UnitOrder.move);
    controller.stopSelected();
    expect(first.order, UnitOrder.idle);
  });
}
