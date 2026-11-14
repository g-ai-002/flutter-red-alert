import 'package:flutter/material.dart';
import 'package:flutter_red_alert/game/battle_controller.dart';
import 'package:flutter_red_alert/game/battle_state.dart';
import 'package:flutter_red_alert/game/battle_types.dart';
import 'package:flutter_red_alert/game/logic_rate.dart';
import 'package:flutter_red_alert/game/production_catalog.dart';
import 'package:flutter_red_alert/pages/widgets/minimap.dart';
import 'package:flutter_red_alert/services/sound_service.dart';
import 'package:flutter_test/flutter_test.dart';

BattleController _controller() {
  final state = BattleState.create();
  final controller = BattleController(state: state, logicRate: LogicRate.hz60);
  controller.camera.updateViewport(const Size(900, 600));
  return controller;
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SoundService.sink = (_) {};
    SoundService.hapticsEnabled = false;
    SoundService.soundEnabled = false;
  });

  group('HUD 刷新节拍', () {
    test('暂停时显示值不变则不再重建 HUD', () {
      final controller = _controller();
      controller.setPaused(true);
      controller.tick(0.16);
      var notifications = 0;
      controller.addListener(() => notifications++);
      for (var i = 0; i < 10; i++) {
        controller.tick(0.16);
      }
      expect(notifications, 0, reason: '暂停且没有任何显示值变化时不应重绘 HUD');
      expect(controller.hudPulse.value, 11, reason: '迷你地图仍需按 6Hz 节拍刷新');
      controller.dispose();
    });

    test('资金变化会立刻触发一次重建', () {
      final controller = _controller();
      controller.setPaused(true);
      controller.tick(0.16);
      var notifications = 0;
      controller.addListener(() => notifications++);
      controller.state.addCredits(playerTeam, 250);
      controller.tick(0.16);
      controller.tick(0.16);
      expect(notifications, 1);
      controller.dispose();
    });

    test('生产进度变化会持续刷新建造栏', () {
      final controller = _controller();
      final state = controller.state;
      state.addCredits(playerTeam, 5000);
      final item = ProductionCatalog.of(ProductionCategory.structure).first;
      state.startProduction(playerTeam, ProductionCategory.structure, item.id);
      var notifications = 0;
      controller.addListener(() => notifications++);
      for (var i = 0; i < 30; i++) {
        controller.tick(0.16);
      }
      expect(notifications, greaterThan(0));
      controller.dispose();
    });
  });

  testWidgets('迷你地图在 HUD 静止时仍按节拍重绘', (tester) async {
    final controller = _controller();
    controller.setPaused(true);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 160,
            height: 160,
            child: BattleMinimap(controller: controller, size: 160),
          ),
        ),
      ),
    );
    final minimapPaint = find.descendant(
      of: find.byType(BattleMinimap),
      matching: find.byType(CustomPaint),
    );
    controller.tick(0.16);
    await tester.pump();
    final before = tester.widget<CustomPaint>(minimapPaint).painter;
    var notifications = 0;
    controller.addListener(() => notifications++);
    controller.tick(0.16);
    await tester.pump();
    final after = tester.widget<CustomPaint>(minimapPaint).painter;
    expect(notifications, 0);
    expect(identical(before, after), isFalse, reason: '单位光点需要独立于 HUD 刷新');
    controller.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
