import 'package:flutter_red_alert/game/ai_commander.dart';
import 'package:flutter_red_alert/game/battle_state.dart';
import 'package:flutter_red_alert/game/battle_types.dart';
import 'package:flutter_test/flutter_test.dart';

/// 让双方都由 AI 指挥，验证战斗能在合理时间内分出胜负。
void main() {
  test('双方 AI 对战可在 20 分钟内结束', () {
    final state = BattleState.create();
    final red = AiCommander(team: Team.red, difficulty: BattleDifficulty.normal);
    final blue = AiCommander(team: Team.blue, difficulty: BattleDifficulty.normal);
    state.onAiTick = (state, dt) {
      red.update(state, dt);
      blue.update(state, dt);
    };
    const step = 1 / 30;
    var seconds = 0.0;
    while (state.result == null && seconds < 20 * 60) {
      state.update(step);
      seconds += step;
    }
    // ignore: avoid_print
    print(
      '模拟结束: result=${state.result}, 用时=${seconds.toStringAsFixed(0)}s, '
      '赤军建筑=${state.buildingsOf(Team.red).length}, '
      '蓝军建筑=${state.buildingsOf(Team.blue).length}, '
      '赤军部队=${state.armySize(Team.red)}, '
      '蓝军部队=${state.armySize(Team.blue)}',
    );
    expect(state.result, isNotNull);
  }, timeout: const Timeout(Duration(minutes: 5)));
}
