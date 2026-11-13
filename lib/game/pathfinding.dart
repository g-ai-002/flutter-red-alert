import 'dart:typed_data';

import 'entity.dart';
import 'terrain.dart';

/// A* 寻路：八方向移动，禁止斜穿障碍，返回不含起点的格子路径。
///
/// 距离表、来源表与关闭表在构造时分配一次，每次搜索用代次标记复用，
/// 避免大兵团反复寻路时产生大量短命数组。单次搜索上限 6000 个节点，
/// 超出后放弃并让单位直接朝目标移动，避免极端地图拖慢逻辑帧。
class PathFinder {
  PathFinder({required GameMap map, required this.isBlocked})
    : map = map,
      _gScore = Float64List(map.width * map.height),
      _cameFrom = Int32List(map.width * map.height),
      _discovered = Int32List(map.width * map.height),
      _closed = Int32List(map.width * map.height);

  final GameMap map;
  final bool Function(int x, int y) isBlocked;

  static const double _diagonal = 1.4142135623730951;

  final Float64List _gScore;
  final Int32List _cameFrom;
  final Int32List _discovered;
  final Int32List _closed;
  final _NodeHeap _open = _NodeHeap();
  int _generation = 0;

  List<TilePoint>? find(
    TilePoint start,
    TilePoint goal, {
    int maxNodes = 6000,
  }) {
    if (!map.inBounds(goal.x, goal.y)) return null;
    if (start == goal) return const [];

    final generation = ++_generation;
    final width = map.width;
    final startIndex = start.y * width + start.x;
    final goalIndex = goal.y * width + goal.x;

    _gScore[startIndex] = 0;
    _discovered[startIndex] = generation;
    _cameFrom[startIndex] = -1;
    _open
      ..clear()
      ..push(startIndex, _heuristic(start.x, start.y, goal.x, goal.y), 0);

    var visited = 0;
    while (_open.isNotEmpty) {
      final current = _open.pop();
      if (current == goalIndex) {
        return _reconstruct(startIndex, goalIndex);
      }
      if (_closed[current] == generation) continue;
      _closed[current] = generation;
      if (++visited > maxNodes) return null;

      final cx = current % width;
      final cy = current ~/ width;
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
          final nextIndex = ny * width + nx;
          if (_closed[nextIndex] == generation) continue;
          final cost = dx != 0 && dy != 0 ? _diagonal : 1.0;
          final tentative = _gScore[current] + cost;
          final known = _discovered[nextIndex] == generation;
          if (known && tentative >= _gScore[nextIndex]) continue;
          _discovered[nextIndex] = generation;
          _cameFrom[nextIndex] = current;
          _gScore[nextIndex] = tentative;
          _open.push(
            nextIndex,
            tentative + _heuristic(nx, ny, goal.x, goal.y),
            tentative,
          );
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

  List<TilePoint> _reconstruct(int startIndex, int goalIndex) {
    final width = map.width;
    final path = <TilePoint>[];
    var current = goalIndex;
    while (current != startIndex && current >= 0) {
      path.add(TilePoint(current % width, current ~/ width));
      current = _cameFrom[current];
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

  void clear() => _items.clear();

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
