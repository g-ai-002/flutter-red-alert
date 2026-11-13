/// 战场逻辑更新速率：以固定步长推进单位移动、战斗与生产，渲染仍按刷新率逐帧绘制。
enum LogicRate {
  hz30('30 Hz 省电', 30),
  hz60('60 Hz 均衡', 60),
  hz120('120 Hz 顺滑', 120);

  const LogicRate(this.label, this.hz);
  final String label;
  final int hz;

  double get step => 1 / hz;

  /// 未设置或未知值时回退到默认 60Hz。
  static LogicRate byName(String? name) => values.firstWhere(
    (item) => item.name == name,
    orElse: () => LogicRate.hz60,
  );
}

/// 固定步长累加器：把不稳定的渲染帧间隔折算成固定数量的逻辑步。
class FixedStepClock {
  FixedStepClock(this.step, {this.maxSteps = 4})
    : assert(step > 0),
      assert(maxSteps > 0);

  final double step;
  final int maxSteps;
  double _remainder = 0;

  /// 消费 [dt] 并回调一次合并后的逻辑步长，返回本帧推进的步数。
  ///
  /// 单帧最多推进 [maxSteps] 步；切后台或严重卡顿后积压的时间合并成一次
  /// 大步推进，避免模拟被永久拖慢。不足一步的余量留到下一帧。
  int advance(double dt, void Function(double span) onStep) {
    if (dt <= 0) return 0;
    _remainder += dt;
    if (_remainder + 1e-9 < step) return 0;
    final span = _remainder;
    final steps = (span / step).floor();
    if (steps > maxSteps) {
      _remainder = 0;
      onStep(span);
      return maxSteps;
    }
    _remainder = span - steps * step;
    onStep(steps * step);
    return steps;
  }
}
