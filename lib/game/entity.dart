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
  bool operator ==(Object other) =>
      other is TilePoint && other.x == x && other.y == y;

  @override
  int get hashCode => x * 100003 + y;
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

  /// 朝向，弧度，0 指向 +x。
  double facing = 0;

  /// 受击闪白剩余时间，由渲染层推进。
  double hitFlash = 0;

  bool get alive => hp > 0;

  bool get isBuilding => this is Building;

  String get displayName;

  double get radius;

  ArmorClass get armor;

  Offset get position => Offset(x, y);

  void applyDamage(int amount) {
    if (amount <= 0) return;
    hp = math.max(0, hp - amount);
    hitFlash = 0.2;
  }

  void advanceFlash(double dt) {
    if (hitFlash > 0) hitFlash = math.max(0, hitFlash - dt);
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
  }) : super(
         x: tileX + spec.width / 2,
         y: tileY + spec.height / 2,
         maxHp: spec.maxHp,
       );

  final BuildingSpec spec;
  final int tileX;
  final int tileY;

  /// 建造完成标记；AI 与玩家放置的建筑均为 true，保留字段供后续建造动画使用。
  bool ready = true;

  /// 防御建筑的开火冷却。
  double fireCooldown = 0;

  String get name => spec.name;

  @override
  String get displayName => spec.name;

  @override
  double get radius => math.max(spec.width, spec.height) / 2;

  @override
  ArmorClass get armor => ArmorClass.structure;

  int get right => tileX + spec.width - 1;
  int get bottom => tileY + spec.height - 1;

  Rect get tileRect =>
      Rect.fromLTWH(tileX.toDouble(), tileY.toDouble(), spec.width.toDouble(), spec.height.toDouble());

  Rect get bounds => Rect.fromLTRB(
    tileX.toDouble(),
    tileY.toDouble(),
    tileX + spec.width.toDouble(),
    tileY + spec.height.toDouble(),
  );

  bool covers(int x, int y) =>
      x >= tileX && x <= right && y >= tileY && y <= bottom;

  /// 建筑中心的格子（用于瞄准与出兵）。
  TilePoint get centerTile =>
      TilePoint(tileX + spec.width ~/ 2, tileY + spec.height ~/ 2);
}

/// 作战单位：持续朝路径点移动，进入射程后开火。
class Unit extends Actor {
  Unit({
    required super.id,
    required super.team,
    required this.spec,
    required super.x,
    required super.y,
  }) : super(maxHp: spec.maxHp);

  final UnitSpec spec;

  /// 当前移动路径（不含起点），[pathIndex] 指向下一个目标点。
  List<TilePoint> path = const [];
  int pathIndex = 0;

  UnitOrder order = UnitOrder.idle;

  /// 攻击或移动的最终目标点。
  Offset? destination;

  /// 攻击目标 id。
  int? targetId;

  /// 开火冷却与追击重算计时。
  double fireCooldown = 0;
  double repathTimer = 0;

  /// 采矿车状态。
  int cargo = 0;
  HarvesterPhase phase = HarvesterPhase.idle;
  TilePoint? oreTile;
  int? refineryId;
  double miningTimer = 0;

  /// 采集余量：把每秒产量按逻辑步累计，保证 30/60/120Hz 下收益一致。
  double miningCarry = 0;

  @override
  String get displayName => spec.name;

  @override
  double get radius => spec.radius;

  @override
  ArmorClass get armor => spec.armor;

  bool get isHarvester => spec.isHarvester;

  bool get hasPath => pathIndex < path.length;

  TilePoint? get nextWaypoint =>
      pathIndex < path.length ? path[pathIndex] : null;

  bool get full => cargo >= spec.capacity;

  double get cargoRatio => spec.capacity <= 0 ? 0 : cargo / spec.capacity;

  void setPath(List<TilePoint> next) {
    path = next;
    pathIndex = 0;
  }

  void clearPath() {
    path = const [];
    pathIndex = 0;
  }

  void clearOrders() {
    order = UnitOrder.idle;
    targetId = null;
    destination = null;
    clearPath();
  }

  /// 卸载矿石，返回本次入库的资金。
  int unload() {
    final amount = cargo;
    cargo = 0;
    return amount;
  }
}
