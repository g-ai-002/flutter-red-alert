import 'dart:math' as math;

import 'package:flutter_red_alert/game/battle_state.dart';
import 'package:flutter_red_alert/game/battle_types.dart';
import 'package:flutter_red_alert/game/entity.dart';
import 'package:flutter_test/flutter_test.dart';

BattleState openField() {
  final state = BattleState.create();
  for (var y = 17; y <= 29; y++) {
    for (var x = 17; x <= 37; x++) {
      state.map.setTerrain(x, y, TerrainKind.grass);
    }
  }
  return state;
}

void main() {
  group('待命自动迎敌', () {
    test('警戒圈内的敌军会被主动追击并消灭，随后返回驻守点', () {
      final state = openField();
      final tank = state.spawnUnitForTest(Team.red, UnitKind.lightTank, const Offset(20.5, 22.5));
      final enemy = state.spawnUnitForTest(Team.blue, UnitKind.rifle, const Offset(27.5, 22.5));
      final post = tank.position;
      var moved = 0.0;
      var engaged = false;
      var seconds = 0.0;
      while (enemy.alive && seconds < 12) {
        state.update(1 / 30);
        seconds += 1 / 30;
        moved = math.max(moved, tank.distanceToPoint(post));
        engaged = engaged || tank.targetId == enemy.id;
      }

      expect(engaged, isTrue, reason: '待命部队应主动锁定警戒圈内的敌军');
      expect(enemy.alive, isFalse, reason: '待命坦克应主动追击并消灭警戒圈内的步兵');
      expect(moved, greaterThan(0.15), reason: '射程外的敌军应被主动追击');
      expect(tank.order, UnitOrder.idle);

      for (var i = 0; i < 30 * 8; i++) {
        state.update(1 / 30);
      }
      expect(tank.distanceToPoint(post), lessThan(1.5), reason: '清空目标后应回到驻守点');
    });

    test('警戒圈外的敌军不会被主动追击', () {
      final state = openField();
      final tank = state.spawnUnitForTest(Team.red, UnitKind.lightTank, const Offset(20.5, 22.5));
      final enemy = state.spawnUnitForTest(Team.blue, UnitKind.rifle, const Offset(34.5, 22.5));
      final post = tank.position;
      final enemyPost = enemy.position;

      for (var i = 0; i < 30 * 4; i++) {
        state.update(1 / 30);
      }

      expect(tank.targetId, isNull);
      expect(enemy.targetId, isNull);
      expect(tank.distanceToPoint(post), lessThan(0.1));
      expect(enemy.distanceToPoint(enemyPost), lessThan(0.1));
    });

    test('手动攻击不受警戒圈限制，消灭目标后就地驻守', () {
      final state = openField();
      final tank = state.spawnUnitForTest(Team.red, UnitKind.heavyTank, const Offset(20.5, 22.5));
      final enemy = state.spawnUnitForTest(Team.blue, UnitKind.rifle, const Offset(34.5, 22.5));
      final start = tank.position;
      state.issueAttack([tank], enemy.id);

      for (var i = 0; i < 30 * 16 && enemy.alive; i++) {
        state.update(1 / 30);
      }

      expect(enemy.alive, isFalse);
      expect(tank.distanceToPoint(start), greaterThan(6), reason: '手动攻击应能跨图追击');
      final killedAt = tank.position;
      for (var i = 0; i < 30 * 5; i++) {
        state.update(1 / 30);
      }
      expect(tank.distanceToPoint(killedAt), lessThan(1.5), reason: '消灭目标后就地驻守');
    });
  });
}
