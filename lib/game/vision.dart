import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'battle_types.dart';
import 'entity.dart';

/// 单位的视野半径（格）：建筑看得更远，采矿车略差。
double sightRadiusOf(Actor actor) {
  if (actor is Building) {
    return switch (actor.spec.kind) {
      BuildingKind.hq => 11,
      BuildingKind.tower => 9,
      _ => 8,
    };
  }
  if (actor is Unit) return actor.isHarvester ? 6 : 7;
  return 6;
}

/// 战争迷雾：按格记录「当前可见」与「曾经探索」。
///
/// 每 0.2 秒由 [BattleState] 用己方单位与建筑重建一次可见范围：新范围先写入
/// 缓冲区，提交时与上一帧比较，只有真正变化才递增 [version]，渲染层据此
/// 决定是否重建迷雾图层。敌方 AI 不受迷雾限制。
class VisionMap {
  VisionMap({required this.width, required this.height})
    : _visible = Uint8List(width * height),
      _next = Uint8List(width * height),
      _explored = Uint8List(width * height);

  final int width;
  final int height;
  final Uint8List _visible;
  final Uint8List _next;
  final Uint8List _explored;

  /// 可见或已探索范围变化时递增。
  int version = 0;

  bool inBounds(int x, int y) =>
      x >= 0 && y >= 0 && x < width && y < height;

  bool isVisible(int x, int y) =>
      inBounds(x, y) && _visible[y * width + x] != 0;

  bool isExplored(int x, int y) =>
      inBounds(x, y) && _explored[y * width + x] != 0;

  /// 目标是否处在视野内：建筑任意一格可见即视为可见。
  bool sees(Actor actor) {
    if (actor is Building) {
      final rect = actor.bounds;
      final left = math.max(0, rect.left.floor());
      final top = math.max(0, rect.top.floor());
      final right = math.min(width, rect.right.ceil());
      final bottom = math.min(height, rect.bottom.ceil());
      for (var y = top; y < bottom; y++) {
        for (var x = left; x < right; x++) {
          if (isVisible(x, y)) return true;
        }
      }
      return false;
    }
    return isVisible(actor.x.floor(), actor.y.floor());
  }

  /// 开始重建：清空缓冲区，不触碰当前生效的可见范围。
  void beginFrame() => _next.fillRange(0, _next.length, 0);

  void reveal(Actor actor) => revealCircle(actor.position, sightRadiusOf(actor));

  void revealCircle(Offset center, double radius) {
    final minX = math.max(0, (center.dx - radius).floor());
    final maxX = math.min(width - 1, (center.dx + radius).ceil());
    final minY = math.max(0, (center.dy - radius).floor());
    final maxY = math.min(height - 1, (center.dy + radius).ceil());
    final radiusSquared = radius * radius;
    for (var y = minY; y <= maxY; y++) {
      final dy = y + 0.5 - center.dy;
      final dySquared = dy * dy;
      for (var x = minX; x <= maxX; x++) {
        final dx = x + 0.5 - center.dx;
        if (dx * dx + dySquared > radiusSquared) continue;
        _next[y * width + x] = 1;
      }
    }
  }

  /// 提交缓冲区，返回是否发生变化。
  bool commit() {
    var changed = false;
    for (var index = 0; index < _visible.length; index++) {
      final value = _next[index];
      if (_visible[index] != value) {
        _visible[index] = value;
        changed = true;
      }
      if (value != 0 && _explored[index] == 0) {
        _explored[index] = 1;
        changed = true;
      }
    }
    if (changed) version++;
    return changed;
  }

  /// 已探索但当前不可见的格数，用于 HUD 与测试。
  int countExploredHidden() {
    var count = 0;
    for (var index = 0; index < _explored.length; index++) {
      if (_explored[index] != 0 && _visible[index] == 0) count++;
    }
    return count;
  }
}
