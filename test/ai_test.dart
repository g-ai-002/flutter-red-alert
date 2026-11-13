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
  test('AI 会补齐兵营与战车工厂并扩军', () {
    final state = BattleState.create();
    final ai = AiCommander(team: Team.blue, difficulty: BattleDifficulty.normal);
    state.onAiTick = ai.update;
    simulate(state, 90);
    expect(
      state.countBuildings(Team.blue, BuildingKind.barracks),
      greaterThan(0),
      reason: 'AI 应建造兵营',
    );
    expect(
      state.countBuildings(Team.blue, BuildingKind.factory),
      greaterThan(0),
      reason: 'AI 应建造战车工厂',
    );
    expect(
      state.armySize(Team.blue),
      greaterThan(2),
      reason: 'AI 应持续扩军',
    );
  });

  test('AI 在积累足够部队后发起进攻', () {
    final state = BattleState.create();
    final ai = AiCommander(team: Team.blue, difficulty: BattleDifficulty.easy);
    state.onAiTick = ai.update;
    simulate(state, 150);
    final attackers = state
        .unitsOf(Team.blue)
        .where((u) => u.order == UnitOrder.attack)
        .length;
    expect(attackers, greaterThan(0), reason: 'AI 应下达进攻指令');
  });

  test('难度影响初始资金', () {
    final easy = BattleState.create(difficulty: BattleDifficulty.easy);
    final hard = BattleState.create(difficulty: BattleDifficulty.hard);
    expect(easy.creditsRed, greaterThan(hard.creditsRed));
    expect(hard.creditsBlue, greaterThan(easy.creditsBlue));
  });
}
