import 'package:flutter_red_alert/game/battle_state.dart';
import 'package:flutter_red_alert/game/vision.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('视野区分可见与已探索，撤出视野后只保留记忆', () {
    final vision = VisionMap(width: 20, height: 20);
    vision.beginFrame();
    vision.revealCircle(const Offset(5, 5), 3);
    vision.commit();

    expect(vision.isVisible(5, 5), isTrue);
    expect(vision.isExplored(5, 5), isTrue);
    expect(vision.isVisible(15, 15), isFalse);
    expect(vision.isExplored(15, 15), isFalse);

    vision.beginFrame();
    vision.revealCircle(const Offset(15, 15), 2);
    vision.commit();

    expect(vision.isVisible(5, 5), isFalse);
    expect(vision.isExplored(5, 5), isTrue);
    expect(vision.isVisible(15, 15), isTrue);
    expect(vision.countExploredHidden(), greaterThan(0));
  });

  test('视野未变化时不递增版本号，避免重复重建迷雾图层', () {
    final vision = VisionMap(width: 16, height: 16);
    vision.beginFrame();
    vision.revealCircle(const Offset(8, 8), 3);
    vision.commit();
    final version = vision.version;

    vision.beginFrame();
    vision.revealCircle(const Offset(8, 8), 3);
    vision.commit();

    expect(vision.version, version);
  });

  test('敌方基地位于迷雾中，己方部队与视野随模拟推进保持可见', () {
    final state = BattleState.create();
    final own = state.redUnits.first;
    final enemy = state.blueUnits.first;

    expect(state.isVisibleToPlayer(own), isTrue);
    expect(state.isVisibleToPlayer(enemy), isFalse);

    state.update(0.25);
    expect(state.isVisibleToPlayer(own), isTrue);
    expect(state.vision.isExplored(own.x.floor(), own.y.floor()), isTrue);
  });

  test('雷达扫描会进入冷却并随时间恢复', () {
    final state = BattleState.create();
    expect(state.radarReady, isTrue);
    expect(state.triggerRadar(), isTrue);
    expect(state.radarActive, isTrue);
    expect(state.triggerRadar(), isFalse);

    for (var i = 0; i < 10; i++) {
      state.update(0.5);
    }
    expect(state.radarActive, isFalse);
    expect(state.radarReady, isFalse);

    for (var i = 0; i < 85; i++) {
      state.update(0.5);
    }
    expect(state.radarReady, isTrue);
  });
}
