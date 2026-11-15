import 'dart:math' as math;
import 'dart:ui';

import 'battle_types.dart';

/// 格子坐标，用作路径与矿点的轻量值类型。
class TilePoint {
  const TilePoint(this.x, this.y);

  final int x;
  final int y;

  Offset get center => Offset(x + 0.5, y + 0.5);

  @override
  bool operator ==(Object other) => other is TilePoint && other.x == x && other.y == y;

  @override
  int get hashCode => x * 100003 + y;
}

/// 遍历矩形占格区域；[visit] 返回 false 时提前结束，返回是否全部访问完毕。
bool forEachBuildingTile(
  int tileX,
  int tileY,
  int width,
  int height,
  bool Function(int x, int y) visit,
) {
  for (var y = tileY; y < tileY + height; y++) {
    for (var x = tileX; x < tileX + width; x++) {
      if (!visit(x, y)) return false;
    }
  }
  return true;
}

/// 遍历以 [cx]/[cy] 为中心、半径 [radius] 的圆内格子。
/// 地形生成与战争迷雾共用同一套边界裁剪与格心距离判定。
void forEachTileInDisc({
  required int mapWidth,
  required int mapHeight,
  required double cx,
  required double cy,
  required double radius,
  required void Function(int x, int y) visit,
}) {
  final minX = math.max(0, (cx - radius).floor());
  final maxX = math.min(mapWidth - 1, (cx + radius).ceil());
  final minY = math.max(0, (cy - radius).floor());
  final maxY = math.min(mapHeight - 1, (cy + radius).ceil());
  final radiusSquared = radius * radius;
  for (var y = minY; y <= maxY; y++) {
    final dy = y + 0.5 - cy;
    final dySquared = dy * dy;
    for (var x = minX; x <= maxX; x++) {
      final dx = x + 0.5 - cx;
      if (dx * dx + dySquared > radiusSquared) continue;
      visit(x, y);
    }
  }
}

/// 以 [centerX]/[centerY] 格为中心、按半径由内向外环形扫描，返回第一个通过
/// [accept] 的格子。同一圈内先扫上边、再扫左右、最后扫下边，结果稳定可复现。
TilePoint? searchTile({
  required int centerX,
  required int centerY,
  required int maxRadius,
  required bool Function(int x, int y) accept,
}) {
  if (accept(centerX, centerY)) return TilePoint(centerX, centerY);
  for (var radius = 1; radius <= maxRadius; radius++) {
    for (var dy = -radius; dy <= radius; dy++) {
      for (var dx = -radius; dx <= radius; dx++) {
        if (math.max(dx.abs(), dy.abs()) != radius) continue;
        final x = centerX + dx;
        final y = centerY + dy;
        if (accept(x, y)) return TilePoint(x, y);
      }
    }
  }
  return null;
}

/// 点到矩形的两个轴向间距，框内为 0；欧氏距离与轴向间距共用。
(double, double) _rectGaps(Offset point, Rect rect) {
  final dx = math.max(math.max(rect.left - point.dx, 0.0), point.dx - rect.right);
  final dy = math.max(math.max(rect.top - point.dy, 0.0), point.dy - rect.bottom);
  return (dx, dy);
}

/// 点到矩形的最短欧氏距离，点在框内返回 0；射程判定与放置预览共用。
double distanceToRect(Offset point, Rect rect) {
  final (dx, dy) = _rectGaps(point, rect);
  return math.sqrt(dx * dx + dy * dy);
}

/// 点到矩形的最短轴向间距，点在框内返回 0；建造选址与贴近判定共用。
double rectGap(Offset point, Rect rect) {
  final (dx, dy) = _rectGaps(point, rect);
  return math.max(dx, dy);
}

/// 单位指令。
enum UnitOrder { idle, move, attack }

/// 采矿车的自动作业阶段。
enum HarvesterPhase { idle, moving, toOre, mining, toRefinery, unloading }

/// 战场上所有可攻击目标的共同基类。
abstract class Actor {
  Actor({
    required this.id,
    required this.team,
    required this.x,
    required this.y,
    required this.maxHp,
  }) : hp = maxHp;

  final int id;
  final Team team;
  double x;
  double y;
  int hp;
  final int maxHp;

  double facing = 0;

  double hitFlash = 0;

  double fireCooldown = 0;

  bool get alive => hp > 0;

  bool get isBuilding => this is Building;

  /// 空中单位不受地面阻挡，且只能被对空武器命中。
  bool get isAir => false;

  String get displayName;

  /// 单字图标，用于迷你地图标签、选中卡片与建造栏。
  String get icon;

  double get radius;

  ArmorClass get armor;

  Offset get position => Offset(x, y);

  /// 与给定点的距离；用标量计算避免索敌与维修扫描为每个候选创建 [Offset]。
  double distanceToPoint(Offset point) {
    final dx = x - point.dx;
    final dy = y - point.dy;
    return math.sqrt(dx * dx + dy * dy);
  }

  double distanceToActor(Actor other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  void applyDamage(int amount) {
    if (amount <= 0) return;
    hp = math.max(0, hp - amount);
    hitFlash = 0.2;
  }

  /// 推进受击闪白与开火冷却，每个逻辑步调用一次。
  void advanceCombatTimers(double dt) {
    if (hitFlash > 0) hitFlash = math.max(0, hitFlash - dt);
    if (fireCooldown > 0) fireCooldown = math.max(0, fireCooldown - dt);
  }
}

/// 建筑：占据整数格，生命值归零后被移除。
class Building extends Actor {
  Building({
    required super.id,
    required super.team,
    required this.spec,
    required this.tileX,
    required this.tileY,
  }) : super(x: tileX + spec.width / 2, y: tileY + spec.height / 2, maxHp: spec.maxHp);

  final BuildingSpec spec;
  final int tileX;
  final int tileY;

  String get name => spec.name;

  @override
  String get displayName => spec.name;

  @override
  String get icon => spec.icon;

  @override
  double get radius => math.max(spec.width, spec.height) / 2;

  @override
  ArmorClass get armor => ArmorClass.structure;

  /// 占据的格子矩形，建筑落地后不再变化，缓存一份供裁剪、射程与迷你地图复用。
  late final Rect bounds = Rect.fromLTRB(
    tileX.toDouble(),
    tileY.toDouble(),
    tileX + spec.width.toDouble(),
    tileY + spec.height.toDouble(),
  );

  /// 遍历建筑占据的每一格，占位表登记与拆除共用。
  bool forEachTile(bool Function(int x, int y) visit) =>
      forEachBuildingTile(tileX, tileY, spec.width, spec.height, visit);
}

/// 作战单位：持续朝路径点移动，进入射程后开火。
class Unit extends Actor {
  Unit({
    required super.id,
    required super.team,
    required this.spec,
    required super.x,
    required super.y,
  }) : guardPost = Offset(x, y),
       super(maxHp: spec.maxHp);

  final UnitSpec spec;

  /// 待命时驻守的位置：自动迎敌只在警戒圈内追击，清空目标后回到这里。
  Offset guardPost;

  /// 自动迎敌的警戒半径：以武器射程为主，保证远程单位能主动进入射界。
  double get guardRadius => math.max(7, spec.range + 2);

  /// 当前移动路径（不含起点），[pathIndex] 指向下一个目标点。
  List<TilePoint> path = const [];
  int pathIndex = 0;

  /// 上次寻路的目标与地形 / 建筑版本，用于跳过重复计算。
  TilePoint? pathGoal;
  int pathMapVersion = -1;
  int pathStructureVersion = -1;

  UnitOrder order = UnitOrder.idle;

  /// 攻击或移动的最终目标点。
  Offset? destination;

  /// 攻击目标 id。
  int? targetId;

  /// 追击重算计时。
  double repathTimer = 0;

  /// 采矿车状态。
  int cargo = 0;
  HarvesterPhase phase = HarvesterPhase.idle;
  TilePoint? oreTile;
  int? refineryId;
  double miningTimer = 0;

  /// 采集余量：把每秒产量按逻辑步累计，保证 30/60/120Hz 下收益一致。
  double miningCarry = 0;

  /// 工程兵的维修余量，按整数生命值结算。
  double workCarry = 0;

  @override
  String get displayName => spec.name;

  @override
  String get icon => spec.icon;

  @override
  double get radius => spec.radius;

  @override
  ArmorClass get armor => spec.armor;

  bool get isHarvester => spec.isHarvester;

  /// 是否计入部队数量：采矿车与工程兵属于支援单位，不算战斗部队。
  bool get isCombat => !isHarvester && !spec.isEngineer;

  @override
  bool get isAir => spec.isAir;

  bool get hasPath => pathIndex < path.length;

  TilePoint? get nextWaypoint => pathIndex < path.length ? path[pathIndex] : null;

  bool get full => cargo >= spec.capacity;

  double get cargoRatio => spec.capacity <= 0 ? 0 : cargo / spec.capacity;

  void setPath(List<TilePoint> next) {
    path = next;
    pathIndex = 0;
    pathGoal = null;
  }

  void clearPath() {
    path = const [];
    pathIndex = 0;
    pathGoal = null;
  }

  void clearOrders() {
    order = UnitOrder.idle;
    targetId = null;
    destination = null;
    guardPost = position;
    clearPath();
  }

  /// 卸载矿石，返回本次入库的资金。
  int unload() {
    final amount = cargo;
    cargo = 0;
    return amount;
  }
}
