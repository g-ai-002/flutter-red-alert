import 'package:flutter_red_alert/game/logic_rate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('刷新率回退到 60Hz', () {
    expect(LogicRate.byName('hz30'), LogicRate.hz30);
    expect(LogicRate.byName('unknown'), LogicRate.hz60);
    expect(LogicRate.byName(null), LogicRate.hz60);
  });

  test('固定步长累加器按步长推进', () {
    final clock = FixedStepClock(1 / 60);
    var total = 0.0;
    var steps = 0;
    for (var i = 0; i < 60; i++) {
      steps += clock.advance(1 / 60, (span) => total += span);
    }
    expect(steps, 60);
    expect(total, closeTo(1, 0.001));
  });

  test('卡顿后单帧最多推进 maxSteps 步', () {
    final clock = FixedStepClock(1 / 60, maxSteps: 4);
    var calls = 0;
    clock.advance(0.5, (_) => calls++);
    expect(calls, 1);
  });
}
