import 'dart:typed_data';

import 'entity.dart';
import 'terrain.dart';

/// A* 寻路：八方向移动，禁止斜穿障碍，返回不含起点的格子路径。
///
/// 路径查找只在下达指令或目标移动时触发，单次搜索上限 6000 个节点，
/// 超出后放弃并让单位直接朝目标移动，避免极端地图拖慢逻辑帧。
class PathFinder {
  PathFinder({required this.map, required this.isBlocked});

  final GameMap map;
  final bool Function(int x, int y) isBlocked;

  static const double _diagonal = 1.4142135623730951;

  List<TilePoint>? find(TilePoint start, TilePoint goal, {int maxNodes = 6000}) {
    if (!map.inBounds(goal.x, goal.y)) return null;
    if (start == goal) return const [];

    final size = map.width * map.height;
    final gScore = Float64List(size)..fillRange(0, size, double.infinity);
    final fScore = Float64List(size)..fillRange(0, size, double.infinity);
    final cameFrom = Int32List(size)..fillRange(0, size, -1);
    final closed = List<bool>.filled(size, false);

    final startIndex = start.y * map.width + start.x;
    final goalIndex = goal.y * map.width + goal.x;
    gScore[startIndex] = 0;
    fScore[startIndex] = _heuristic(start.x, start.y, goal.x, goal.y);

    final open = _NodeHeap();
    open.push(startIndex, fScore[startIndex], 0);
    var visited = 0;

    while (open.isNotEmpty) {
      final current = open.pop();
      if (current == goalIndex) {
        return _reconstruct(cameFrom, startIndex, goalIndex);
      }
      if (closed[current]) continue;
      closed[current] = true;
      if (++visited > maxNodes) return null;

      final cx = current % map.width;
      final cy = current ~/ map.width;
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          if (dx == 0 && dy == 0) continue;
          final nx = cx + dx;
          final ny = cy + dy;
          if (!map.inBounds(nx, ny)) continue;
          if (isBlocked(nx, ny)) continue;
          if (dx != 0 && dy != 0) {
            // 斜向移动不能贴着障碍拐角穿过去。
            if (isBlocked(cx + dx, cy) || isBlocked(cx, cy + dy)) continue;
          }
          final nextIndex = ny * map.width + nx;
          if (closed[nextIndex]) continue;
          final cost = dx != 0 && dy != 0 ? _diagonal : 1.0;
          final tentative = gScore[current] + cost;
          if (tentative >= gScore[nextIndex]) continue;
          cameFrom[nextIndex] = current;
          gScore[nextIndex] = tentative;
          fScore[nextIndex] = tentative + _heuristic(nx, ny, goal.x, goal.y);
          open.push(nextIndex, fScore[nextIndex], tentative);
        }
      }
    }
    return null;
  }

  double _heuristic(int x, int y, int gx, int gy) {
    final dx = (x - gx).abs().toDouble();
    final dy = (y - gy).abs().toDouble();
    return (dx + dy) + (_diagonal - 2) * (dx < dy ? dx : dy);
  }

  List<TilePoint> _reconstruct(
    Int32List cameFrom,
    int startIndex,
    int goalIndex,
  ) {
    final path = <TilePoint>[];
    var current = goalIndex;
    while (current != startIndex && current >= 0) {
      path.add(TilePoint(current % map.width, current ~/ map.width));
      current = cameFrom[current];
    }
    return path.reversed.toList(growable: false);
  }
}

class _HeapEntry {
  _HeapEntry(this.index, this.f, this.g);

  final int index;
  final double f;
  final double g;
}

/// 以 f 值为优先级的二叉最小堆，f 相同时优先 g 更大的节点（更靠近目标）。
class _NodeHeap {
  final List<_HeapEntry> _items = [];

  bool get isNotEmpty => _items.isNotEmpty;

  void push(int index, double f, double g) {
    _items.add(_HeapEntry(index, f, g));
    var child = _items.length - 1;
    while (child > 0) {
      final parent = (child - 1) >> 1;
      if (_better(_items[parent], _items[child])) break;
      final temp = _items[parent];
      _items[parent] = _items[child];
      _items[child] = temp;
      child = parent;
    }
  }

  int pop() {
    final top = _items.first;
    final last = _items.removeLast();
    if (_items.isNotEmpty) {
      _items[0] = last;
      var parent = 0;
      while (true) {
        final left = parent * 2 + 1;
        final right = left + 1;
        var best = parent;
        if (left < _items.length && !_better(_items[best], _items[left])) {
          best = left;
        }
        if (right < _items.length && !_better(_items[best], _items[right])) {
          best = right;
        }
        if (best == parent) break;
        final temp = _items[parent];
        _items[parent] = _items[best];
        _items[best] = temp;
        parent = best;
      }
    }
    return top.index;
  }

  bool _better(_HeapEntry a, _HeapEntry b) {
    if (a.f != b.f) return a.f < b.f;
    return a.g > b.g;
  }
}
