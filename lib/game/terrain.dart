import 'dart:math' as math;
import 'dart:ui';

import 'battle_types.dart';

/// 战场地图：固定格子的地形与矿石分布，由固定种子生成，保证同一难度下开局一致。
///
/// 坐标以格子为单位，左上角为 (0,0)；地图按 180° 旋转对称，双方基地与
/// 矿区机会均等。
class GameMap {
  GameMap({
    required this.width,
    required this.height,
    required List<TerrainKind> terrain,
    required List<int> ore,
  }) : assert(terrain.length == width * height),
       assert(ore.length == width * height),
       _terrain = List<TerrainKind>.of(terrain),
       _ore = List<int>.of(ore);

  factory GameMap.generate({int size = 44, int seed = 20261114}) {
    final map = GameMap(
      width: size,
      height: size,
      terrain: List<TerrainKind>.filled(
        size * size,
        TerrainKind.grass,
        growable: false,
      ),
      ore: List<int>.filled(size * size, 0, growable: false),
    );
    map._decorate(seed);
    return map;
  }

  final int width;
  final int height;
  final List<TerrainKind> _terrain;
  final List<int> _ore;

  /// 地形变化计数，渲染层据此判断是否需要重绘地形缓存。
  int version = 0;

  /// 赤军基地中心（格）。
  static const Offset redBase = Offset(8, 35);

  /// 蓝军基地中心，与赤军基地关于地图中心对称。
  static const Offset blueBase = Offset(35, 8);

  Offset baseOf(Team team) => team == Team.red ? redBase : blueBase;

  bool inBounds(int x, int y) => x >= 0 && y >= 0 && x < width && y < height;

  TerrainKind terrainAt(int x, int y) {
    if (!inBounds(x, y)) return TerrainKind.rock;
    return _terrain[y * width + x];
  }

  TerrainKind terrainAtOffset(Offset tile) =>
      terrainAt(tile.dx.floor(), tile.dy.floor());

  void setTerrain(int x, int y, TerrainKind kind) {
    if (!inBounds(x, y)) return;
    if (_terrain[y * width + x] == kind) return;
    _terrain[y * width + x] = kind;
    version++;
  }

  int oreAt(int x, int y) {
    if (!inBounds(x, y)) return 0;
    return _ore[y * width + x];
  }

  /// 采集矿石，返回实际采出的数量；采空后地形变为泥地。
  int mine(int x, int y, int amount) {
    if (!inBounds(x, y) || amount <= 0) return 0;
    final index = y * width + x;
    final mined = math.min(amount, _ore[index]);
    if (mined <= 0) return 0;
    _ore[index] -= mined;
    if (_ore[index] <= 0) {
      _ore[index] = 0;
      _terrain[index] = TerrainKind.dirt;
      version++;
    }
    return mined;
  }

  /// 该格是否适合建造：平地、泥地与公路可以，矿石、水域与岩石不行。
  bool buildable(int x, int y) {
    if (!inBounds(x, y)) return false;
    final kind = terrainAt(x, y);
    return kind == TerrainKind.grass ||
        kind == TerrainKind.dirt ||
        kind == TerrainKind.road;
  }

  /// 该格是否阻挡地面单位通行。
  bool blocked(int x, int y) {
    if (!inBounds(x, y)) return true;
    final kind = terrainAt(x, y);
    return kind == TerrainKind.water || kind == TerrainKind.rock;
  }

  /// 地形对移动速度的影响倍率。
  double speedFactor(int x, int y) {
    return switch (terrainAt(x, y)) {
      TerrainKind.road => 1.3,
      TerrainKind.dirt => 0.95,
      TerrainKind.ore => 0.85,
      TerrainKind.grass => 1.0,
      TerrainKind.water || TerrainKind.rock => 0.6,
    };
  }

  /// 统计某类地形的格数，用于测试与 HUD 概要。
  int countOf(TerrainKind kind) => _terrain.where((t) => t == kind).length;

  void _decorate(int seed) {
    final random = math.Random(seed);
    _stampDisc(13, 21, 3.2, TerrainKind.water);
    _stampDisc(width - 14, height - 22, 3.2, TerrainKind.water);
    _stampDisc(21.5, 21.5, 2.2, TerrainKind.rock);

    for (var i = 0; i < 16; i++) {
      final x = random.nextDouble() * width;
      final y = random.nextDouble() * height;
      if (_nearBase(x, y, 8)) continue;
      final radius = 1.0 + random.nextDouble() * 1.8;
      _stampDisc(x, y, radius, TerrainKind.rock);
    }

    _orePatch(14.5, 29.5, 2.6, 2000);
    _orePatch(4.5, 27.5, 2.2, 1800);
    _orePatch(13.5, 13.5, 2.4, 2600);
    _orePatch(21.5, 27.5, 2.2, 2400);
    _mirrorOre();

    _road(const [
      Offset(8, 35),
      Offset(13, 32),
      Offset(19, 28),
      Offset(22, 22),
      Offset(27, 18),
      Offset(32, 14),
      Offset(35, 8),
    ], width: 1.6, kind: TerrainKind.road);

    _road(const [Offset(8, 35), Offset(4, 30), Offset(4.5, 27.5)], width: 1.2);
    _road(const [Offset(35, 8), Offset(39, 13), Offset(38.5, 15.5)], width: 1.2);
    _road(const [Offset(19, 28), Offset(14, 24), Offset(13, 21)], width: 1.1);
    _road(const [Offset(27, 18), Offset(31, 22), Offset(32, 25)], width: 1.1);

    _flattenBase(redBase, 7.0);
    _flattenBase(blueBase, 7.0);
    _forceSymmetric();
    version++;
  }

  /// 把右下半区镜像到左上半区，保证公路、矿区与障碍完全对称。
  void _forceSymmetric() {
    final sourceTerrain = List<TerrainKind>.of(_terrain);
    final sourceOre = List<int>.of(_ore);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final mx = width - 1 - x;
        final my = height - 1 - y;
        final takeLower = y > my || (y == my && x > mx);
        final src = takeLower ? y * width + x : my * width + mx;
        _terrain[y * width + x] = sourceTerrain[src];
        _ore[y * width + x] = sourceOre[src];
      }
    }
  }

  /// 基地范围强制平整为泥地，避免随机岩石或水域压住初始建筑。
  void _flattenBase(Offset base, double radius) {
    final minX = math.max(0, (base.dx - radius).floor());
    final maxX = math.min(width - 1, (base.dx + radius).ceil());
    final minY = math.max(0, (base.dy - radius).floor());
    final maxY = math.min(height - 1, (base.dy + radius).ceil());
    for (var y = minY; y <= maxY; y++) {
      for (var x = minX; x <= maxX; x++) {
        final dx = x + 0.5 - base.dx;
        final dy = y + 0.5 - base.dy;
        if (dx * dx + dy * dy > radius * radius) continue;
        final index = y * width + x;
        _terrain[index] = TerrainKind.dirt;
        _ore[index] = 0;
      }
    }
  }

  bool _nearBase(double x, double y, double radius) {
    final red = (Offset(x, y) - redBase).distance;
    final blue = (Offset(x, y) - blueBase).distance;
    return red < radius || blue < radius;
  }

  void _stampDisc(double cx, double cy, double radius, TerrainKind kind) {
    final minX = math.max(0, (cx - radius).floor());
    final maxX = math.min(width - 1, (cx + radius).ceil());
    final minY = math.max(0, (cy - radius).floor());
    final maxY = math.min(height - 1, (cy + radius).ceil());
    for (var y = minY; y <= maxY; y++) {
      for (var x = minX; x <= maxX; x++) {
        final dx = x + 0.5 - cx;
        final dy = y + 0.5 - cy;
        if (dx * dx + dy * dy > radius * radius) continue;
        final index = y * width + x;
        if (kind == TerrainKind.ore) {
          _terrain[index] = TerrainKind.ore;
          _ore[index] = math.max(_ore[index], 2000);
        } else if (kind == TerrainKind.dirt) {
          // 基地平整不覆盖水域与岩石，保留天然屏障。
          if (_terrain[index] == TerrainKind.water ||
              _terrain[index] == TerrainKind.rock) {
            continue;
          }
          _terrain[index] = TerrainKind.dirt;
          _ore[index] = 0;
        } else {
          _terrain[index] = kind;
          _ore[index] = 0;
        }
      }
    }
  }

  void _orePatch(double cx, double cy, double radius, int amount) {
    _stampDisc(cx, cy, radius, TerrainKind.ore);
    final minX = math.max(0, (cx - radius).floor());
    final maxX = math.min(width - 1, (cx + radius).ceil());
    final minY = math.max(0, (cy - radius).floor());
    final maxY = math.min(height - 1, (cy + radius).ceil());
    for (var y = minY; y <= maxY; y++) {
      for (var x = minX; x <= maxX; x++) {
        final index = y * width + x;
        if (_terrain[index] != TerrainKind.ore) continue;
        final dist = (Offset(x + 0.5, y + 0.5) - Offset(cx, cy)).distance;
        final ratio = (1 - dist / (radius + 0.4)).clamp(0.45, 1.0);
        _ore[index] = (amount * ratio).round();
      }
    }
  }

  /// 把已生成的矿区与地形按 180° 旋转镜像到对侧。
  void _mirrorOre() {
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final index = y * width + x;
        if (_terrain[index] != TerrainKind.ore) continue;
        final mx = width - 1 - x;
        final my = height - 1 - y;
        final target = my * width + mx;
        if (_terrain[target] == TerrainKind.ore) continue;
        _terrain[target] = TerrainKind.ore;
        _ore[target] = _ore[index];
      }
    }
  }

  void _road(
    List<Offset> points, {
    double width = 1.0,
    TerrainKind kind = TerrainKind.road,
  }) {
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      final distance = (b - a).distance;
      final steps = math.max(1, (distance * 3).ceil());
      for (var s = 0; s <= steps; s++) {
        final t = s / steps;
        final x = a.dx + (b.dx - a.dx) * t;
        final y = a.dy + (b.dy - a.dy) * t;
        _stampDisc(x, y, width / 2, kind);
      }
    }
  }
}
