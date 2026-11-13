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
    final clock = FixedStepClock(1 / 60);
    var calls = 0;
    clock.advance(0.5, (_) => calls++);
    expect(calls, 1);
  });

  test('不足一步的余量留到下一帧', () {
    final clock = FixedStepClock(1 / 60);
    var total = 0.0;
    var steps = 0;
    steps += clock.advance(1 / 120, (span) => total += span);
    expect(steps, 0);
    expect(total, 0);
    steps += clock.advance(1 / 120, (span) => total += span);
    expect(steps, 1);
    expect(total, closeTo(1 / 60, 1e-9));
  });

  test('积压超过上限时一次推进全部时间并清空缓存', () {
    final clock = FixedStepClock(1 / 60);
    var total = 0.0;
    expect(clock.advance(1.0, (span) => total += span), 4);
    expect(total, closeTo(1.0, 1e-9));
    // 积压已清空，下一帧只推进新来的时间。
    expect(clock.advance(1 / 60, (span) => total += span), 1);
    expect(total, closeTo(1 + 1 / 60, 1e-9));
  });
}
