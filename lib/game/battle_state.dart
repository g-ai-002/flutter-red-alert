import 'dart:math' as math;
import 'dart:ui';

import 'battle_types.dart';
import 'entity.dart';
import 'pathfinding.dart';
import 'terrain.dart';

/// 生产任务：建筑或单位在队列中的进度。
class ProductionJob {
  ProductionJob({
    required this.id,
    required this.category,
    required this.cost,
    required this.totalSeconds,
  });

  final String id;
  final ProductionCategory category;
  final int cost;
  final double totalSeconds;
  double progress = 0;

  String get name {
    final building = buildingKindFromId(id);
    if (building != null) return building.label;
    final unit = unitKindFromId(id);
    return unit?.label ?? id;
  }

  String get icon {
    final building = buildingKindFromId(id);
    if (building != null) return building.icon;
    return unitKindFromId(id)?.icon ?? '?';
  }

  bool get isStructure => category == ProductionCategory.structure;
}

BuildingKind? buildingKindFromId(String id) {
  for (final kind in BuildingKind.values) {
    if (kind.name == id) return kind;
  }
  return null;
}

UnitKind? unitKindFromId(String id) {
  for (final kind in UnitKind.values) {
    if (kind.name == id) return kind;
  }
  return null;
}

/// 战场提示级别。
enum NoticeLevel { info, warning, success }

class BattleNotice {
  const BattleNotice(this.text, this.level);

  final String text;
  final NoticeLevel level;
}

/// 一次性视觉事件，由渲染层消费。
enum BattleEventKind { bullet, shell, explosion, build, spawn, unload, move }

class BattleEvent {
  const BattleEvent(
    this.kind,
    this.x,
    this.y, {
    this.tx,
    this.ty,
    this.team,
    this.radius = 0.5,
  });

  final BattleEventKind kind;
  final double x;
  final double y;
  final double? tx;
  final double? ty;
  final Team? team;
  final double radius;
}

/// 战场模拟核心：不依赖 Flutter 组件，可在纯 Dart 测试中运行。
///
/// 所有坐标为格子单位；逻辑以固定步长推进，渲染层只读取状态。
class BattleState {
  BattleState({
    required this.map,
    this.difficulty = BattleDifficulty.normal,
    int seed = 7,
  }) {
    _occupancy = List<Building?>.filled(map.width * map.height, null);
    _random = math.Random(seed);
    _finder = PathFinder(
      map: map,
      isBlocked: (x, y) =>
          map.blocked(x, y) || _occupancy[y * map.width + x] != null,
    );
  }

  /// 创建一张新地图并布置双方初始基地。
  factory BattleState.create({
    BattleDifficulty difficulty = BattleDifficulty.normal,
    int mapSeed = 20261114,
    int setupSeed = 7,
  }) {
    final state = BattleState(
      map: GameMap.generate(seed: mapSeed),
      difficulty: difficulty,
      seed: setupSeed,
    );
    state._setupBases();
    return state;
  }

  final GameMap map;
  final BattleDifficulty difficulty;

  final List<Actor> actors = [];
  final List<Unit> redUnits = [];
  final List<Unit> blueUnits = [];
  final List<Building> redBuildings = [];
  final List<Building> blueBuildings = [];

  int creditsRed = 0;
  int creditsBlue = 0;
  double elapsed = 0;
  BattleResult? result;

  final List<BattleNotice> notices = [];
  final List<BattleEvent> events = [];

  /// 由外部（AI 指挥官）注入的每秒回调。
  void Function(BattleState state, double dt)? onAiTick;

  int _nextId = 1;
  late final PathFinder _finder;
  late final math.Random _random;
  late final List<Building?> _occupancy;
  final Map<Team, Map<ProductionCategory, ProductionJob?>> _queues = {
    for (final team in Team.values)
      team: {for (final category in ProductionCategory.values) category: null},
  };
  final Map<Team, List<BuildingKind>> _readyStructures = {
    for (final team in Team.values) team: <BuildingKind>[],
  };

  // ===== 查询 =====

  List<Unit> unitsOf(Team team) => team == Team.red ? redUnits : blueUnits;

  List<Building> buildingsOf(Team team) =>
      team == Team.red ? redBuildings : blueBuildings;

  int creditsOf(Team team) => team == Team.red ? creditsRed : creditsBlue;

  Map<ProductionCategory, ProductionJob?> queuesOf(Team team) => _queues[team]!;

  ProductionJob? jobOf(Team team, ProductionCategory category) =>
      _queues[team]![category];

  List<BuildingKind> readyStructuresOf(Team team) =>
      List.unmodifiable(_readyStructures[team]!);

  Actor? actorById(int id) {
    for (final actor in actors) {
      if (actor.id == id && actor.alive) return actor;
    }
    return null;
  }

  Building? buildingAt(int x, int y) {
    if (x < 0 || y < 0 || x >= map.width || y >= map.height) return null;
    return _occupancy[y * map.width + x];
  }

  bool isBlocked(int x, int y) =>
      map.blocked(x, y) || buildingAt(x, y) != null;

  int countBuildings(Team team, BuildingKind kind) =>
      buildingsOf(team).where((b) => b.spec.kind == kind).length;

  bool hasBuilding(Team team, BuildingKind kind) =>
      countBuildings(team, kind) > 0;

  int powerProduced(Team team) => buildingsOf(
    team,
  ).where((b) => b.spec.power > 0).fold(0, (sum, b) => sum + b.spec.power);

  int powerUsed(Team team) => buildingsOf(
    team,
  ).where((b) => b.spec.power < 0).fold(0, (sum, b) => sum - b.spec.power);

  /// 电力充足时为 1，不足时生产与防御效率减半。
  double powerFactor(Team team) =>
      powerUsed(team) > powerProduced(team) ? 0.5 : 1.0;

  /// 战斗单位数量（不含采矿车）。
  int armySize(Team team) =>
      unitsOf(team).where((u) => !u.isHarvester).length;

  // ===== 初始布置 =====

  void _setupBases() {
    creditsRed = difficulty.playerCredits;
    creditsBlue = difficulty.aiCredits;
    _spawnBuilding(Team.red, BuildingKind.hq, 6, 33);
    _spawnBuilding(Team.red, BuildingKind.power, 10, 36);
    _spawnBuilding(Team.red, BuildingKind.refinery, 3, 34);
    _spawnBuilding(Team.blue, BuildingKind.hq, 35, 8);
    _spawnBuilding(Team.blue, BuildingKind.power, 32, 6);
    _spawnBuilding(Team.blue, BuildingKind.refinery, 38, 8);
    for (var i = 0; i < 2; i++) {
      _spawnUnit(Team.red, UnitKind.harvester, GameMap.redBase + Offset(0, 2.2 + i));
      _spawnUnit(Team.blue, UnitKind.harvester, GameMap.blueBase + Offset(0, -2.2 - i));
    }
    addNotice('指挥中心已就位，先建兵营再图进取');
  }

  // ===== 提示与事件 =====

  void addNotice(String text, {NoticeLevel level = NoticeLevel.info}) {
    notices.add(BattleNotice(text, level));
    if (notices.length > 20) notices.removeRange(0, notices.length - 20);
  }

  void _emit(BattleEvent event) {
    events.add(event);
    if (events.length > 240) events.removeRange(0, events.length - 240);
  }

  List<BattleEvent> drainEvents() {
    if (events.isEmpty) return const [];
    final drained = List<BattleEvent>.of(events);
    events.clear();
    return drained;
  }

  List<BattleNotice> drainNotices() {
    if (notices.isEmpty) return const [];
    final drained = List<BattleNotice>.of(notices);
    notices.clear();
    return drained;
  }

  // ===== 生产 =====

  bool canProduce(Team team, ProductionCategory category, String id) {
    final buildingKind = buildingKindFromId(id);
    final unitKind = unitKindFromId(id);
    if (category == ProductionCategory.structure) {
      if (buildingKind == null) return false;
      // 指挥中心被摧毁后，只要有其他建筑就允许重建。
      if (!hasBuilding(team, BuildingKind.hq)) {
        return buildingKind == BuildingKind.hq && buildingsOf(team).isNotEmpty;
      }
      final requires = buildingSpecs[buildingKind]!.requires;
      if (requires != null && !hasBuilding(team, requires)) return false;
      return true;
    }
    if (unitKind == null) return false;
    if (!hasBuilding(team, producerForCategory[category]!)) return false;
    final requires = unitSpecs[unitKind]!.requires;
    if (requires != null && !hasBuilding(team, requires)) return false;
    if (category == ProductionCategory.armor &&
        unitKind != UnitKind.harvester &&
        !hasBuilding(team, BuildingKind.factory)) {
      return false;
    }
    return true;
  }

  int costOf(String id) {
    final building = buildingKindFromId(id);
    if (building != null) return buildingSpecs[building]!.cost;
    return unitSpecs[unitKindFromId(id) ?? UnitKind.rifle]!.cost;
  }

  String nameOf(String id) {
    final building = buildingKindFromId(id);
    if (building != null) return building.label;
    return unitKindFromId(id)?.label ?? id;
  }

  /// 开始生产；资金立即扣除，队列已有任务或条件不足时返回 false。
  bool startProduction(
    Team team,
    ProductionCategory category,
    String id, {
    bool announce = true,
  }) {
    if (result != null) return false;
    final queue = _queues[team]!;
    if (queue[category] != null) {
      if (announce) addNotice('${category.label}队列正在生产', level: NoticeLevel.warning);
      return false;
    }
    if (!canProduce(team, category, id)) {
      if (announce) {
        addNotice('缺少前置建筑，暂时无法生产${nameOf(id)}', level: NoticeLevel.warning);
      }
      return false;
    }
    final cost = costOf(id);
    if (creditsOf(team) < cost) {
      if (announce) addNotice('资金不足，无法生产${nameOf(id)}', level: NoticeLevel.warning);
      return false;
    }
    final seconds = category == ProductionCategory.structure
        ? buildingSpecs[buildingKindFromId(id)!]!.buildSeconds
        : unitSpecs[unitKindFromId(id)!]!.buildSeconds;
    _addCredits(team, -cost);
    queue[category] = ProductionJob(
      id: id,
      category: category,
      cost: cost,
      totalSeconds: seconds,
    );
    return true;
  }

  void cancelProduction(Team team, ProductionCategory category) {
    final job = _queues[team]![category];
    if (job == null) return;
    _addCredits(team, job.cost);
    _queues[team]![category] = null;
    if (team == Team.red) {
      addNotice('已取消${job.name}，资金已返还');
    }
  }

  void _updateProduction(double dt) {
    for (final team in Team.values) {
      for (final category in ProductionCategory.values) {
        final job = _queues[team]![category];
        if (job == null) continue;
        final speed =
            powerFactor(team) *
            (team == Team.blue ? difficulty.aiBuildSpeed : 1.0);
        job.progress += dt * speed / job.totalSeconds;
        if (job.progress < 1) continue;
        job.progress = 1;
        if (category == ProductionCategory.structure) {
          final kind = buildingKindFromId(job.id)!;
          _readyStructures[team]!.add(kind);
          _queues[team]![category] = null;
          if (team == Team.red) {
            addNotice(
              '${kind.label}已就绪，点击建造栏放置',
              level: NoticeLevel.success,
            );
          }
        } else {
          if (!_trySpawnUnit(team, job.id)) {
            // 出兵口被占满时保持 100%，等待空位；生产者被摧毁则中止并退款。
            if (!hasBuilding(team, producerForCategory[category]!)) {
              _addCredits(team, job.cost);
              _queues[team]![category] = null;
              if (team == Team.red) {
                addNotice('生产建筑被摧毁，${job.name}生产中止', level: NoticeLevel.warning);
              }
            }
          }
        }
      }
    }
  }

  bool _trySpawnUnit(Team team, String unitId) {
    final kind = unitKindFromId(unitId);
    if (kind == null) return true;
    final category = unitSpecs[kind]!.category;
    final producerKind = producerForCategory[category]!;
    final producers = buildingsOf(
      team,
    ).where((b) => b.spec.kind == producerKind).toList();
    if (producers.isEmpty) return false;
    for (final producer in producers) {
      final tile = findSpawnTile(producer);
      if (tile == null) continue;
      _spawnUnit(team, kind, tile.center);
      final job = _queues[team]![category];
      if (job != null) _queues[team]![category] = null;
      _emit(
        BattleEvent(
          BattleEventKind.spawn,
          tile.x + 0.5,
          tile.y + 0.5,
          team: team,
        ),
      );
      if (team == Team.red) {
        addNotice('${kind.label}已出厂', level: NoticeLevel.success);
      }
      return true;
    }
    return false;
  }

  // ===== 建造 =====

  /// 放置校验：地形可建、无重叠、且不远离己方建筑。
  bool canPlaceBuilding(
    BuildingSpec spec,
    int tileX,
    int tileY, {
    Team? team,
    bool requireNearBase = true,
  }) {
    if (tileX < 0 || tileY < 0) return false;
    if (tileX + spec.width > map.width || tileY + spec.height > map.height) {
      return false;
    }
    for (var y = tileY; y < tileY + spec.height; y++) {
      for (var x = tileX; x < tileX + spec.width; x++) {
        if (!map.buildable(x, y)) return false;
        if (buildingAt(x, y) != null) return false;
      }
    }
    if (!requireNearBase || team == null) return true;
    final center = Offset(tileX + spec.width / 2, tileY + spec.height / 2);
    for (final building in buildingsOf(team)) {
      if (building.spec.kind == BuildingKind.hq) {
        if (_rectGap(center, building.bounds) <= 9) return true;
        continue;
      }
      if (_rectGap(center, building.bounds) <= 7) return true;
    }
    return false;
  }

  double _rectGap(Offset point, Rect rect) {
    final dx = math.max(
      math.max(rect.left - point.dx, 0.0),
      point.dx - rect.right,
    );
    final dy = math.max(
      math.max(rect.top - point.dy, 0.0),
      point.dy - rect.bottom,
    );
    return math.max(dx, dy);
  }

  /// 找到离己方基地最近的可放置位置，供 AI 与「自动选址」使用。
  TilePoint? findPlacement(BuildingSpec spec, Team team, {int maxRadius = 12}) {
    final base = map.baseOf(team);
    for (var radius = 0; radius <= maxRadius; radius++) {
      for (var dy = -radius; dy <= radius; dy++) {
        for (var dx = -radius; dx <= radius; dx++) {
          if (math.max(dx.abs(), dy.abs()) != radius) continue;
          final tileX = (base.dx + dx).floor();
          final tileY = (base.dy + dy).floor();
          if (canPlaceBuilding(spec, tileX, tileY, team: team)) {
            return TilePoint(tileX, tileY);
          }
        }
      }
    }
    return null;
  }

  Building? placeReadyStructure(Team team, BuildingKind kind) {
    final ready = _readyStructures[team]!;
    if (!ready.contains(kind)) return null;
    final spec = buildingSpecs[kind]!;
    final spot = findPlacement(spec, team);
    if (spot == null) return null;
    ready.remove(kind);
    final building = _spawnBuilding(team, kind, spot.x, spot.y);
    _emit(BattleEvent(BattleEventKind.build, building.x, building.y, team: team, radius: building.radius));
    if (team == Team.red) {
      addNotice('${kind.label}建造完成', level: NoticeLevel.success);
    }
    return building;
  }

  /// 尝试在指定格放置已就绪的建筑。
  Building? placeStructureAt(Team team, BuildingKind kind, int tileX, int tileY) {
    final ready = _readyStructures[team]!;
    if (!ready.contains(kind)) return null;
    final spec = buildingSpecs[kind]!;
    if (!canPlaceBuilding(spec, tileX, tileY, team: team)) return null;
    ready.remove(kind);
    final building = _spawnBuilding(team, kind, tileX, tileY);
    _emit(BattleEvent(BattleEventKind.build, building.x, building.y, team: team, radius: building.radius));
    if (team == Team.red) {
      addNotice('${kind.label}建造完成', level: NoticeLevel.success);
    }
    return building;
  }

  Building _spawnBuilding(Team team, BuildingKind kind, int tileX, int tileY) {
    final building = Building(
      id: _nextId++,
      team: team,
      spec: buildingSpecs[kind]!,
      tileX: tileX,
      tileY: tileY,
    );
    actors.add(building);
    buildingsOf(team).add(building);
    for (var y = tileY; y < tileY + building.spec.height; y++) {
      for (var x = tileX; x < tileX + building.spec.width; x++) {
        if (!map.inBounds(x, y)) continue;
        _occupancy[y * map.width + x] = building;
      }
    }
    return building;
  }

  Unit _spawnUnit(Team team, UnitKind kind, Offset at) {
    final tile = _nearestFreeTile(at, radius: 6) ?? TilePoint(at.dx.floor(), at.dy.floor());
    final unit = Unit(
      id: _nextId++,
      team: team,
      spec: unitSpecs[kind]!,
      x: tile.x + 0.5,
      y: tile.y + 0.5,
    );
    unit.facing = team == Team.red ? -math.pi / 4 : math.pi * 3 / 4;
    actors.add(unit);
    unitsOf(team).add(unit);
    return unit;
  }

  /// 在建筑周围寻找空位，优先朝基地外侧（地图中心方向）。
  TilePoint? findSpawnTile(Building building) {
    final center = Offset(building.tileX + building.spec.width / 2, building.tileY + building.spec.height / 2);
    for (var radius = 1; radius <= 6; radius++) {
      for (var dy = -radius; dy <= radius; dy++) {
        for (var dx = -radius; dx <= radius; dx++) {
          if (math.max(dx.abs(), dy.abs()) != radius) continue;
          final x = (center.dx + dx).floor();
          final y = (center.dy + dy).floor();
          if (!map.inBounds(x, y) || isBlocked(x, y)) continue;
          return TilePoint(x, y);
        }
      }
    }
    return null;
  }

  // ===== 指令 =====

  List<Unit> selectableUnits(Team team, Iterable<int> ids) => unitsOf(
    team,
  ).where((u) => ids.contains(u.id) && u.alive).toList();

  /// 下达移动指令，按网格阵型分配落点。
  void issueMove(List<Unit> units, Offset destination) {
    final ordered = units.where((u) => u.alive).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    if (ordered.isEmpty) return;
    final offsets = _formationOffsets(ordered.length);
    final baseTile = TilePoint(destination.dx.floor(), destination.dy.floor());
    var placed = 0;
    for (var i = 0; i < ordered.length; i++) {
      final unit = ordered[i];
      final offset = offsets[i];
      final slot = _nearestFreeTile(
        Offset(baseTile.x + 0.5 + offset.dx, baseTile.y + 0.5 + offset.dy),
        radius: 2,
      );
      if (slot == null) continue;
      final path = _finder.find(TilePoint(unit.x.floor(), unit.y.floor()), slot);
      if (path == null) continue;
      unit
        ..order = UnitOrder.move
        ..targetId = null
        ..destination = slot.center
        ..setPath(path);
      if (unit.isHarvester) {
        unit.phase = HarvesterPhase.moving;
      }
      placed++;
    }
    if (placed > 0) {
      _emit(
        BattleEvent(
          BattleEventKind.move,
          destination.dx,
          destination.dy,
          team: ordered.first.team,
          radius: 0.5,
        ),
      );
    }
  }

  /// 下达攻击指令：目标可以是单位或建筑。
  void issueAttack(List<Unit> units, int targetId) {
    final target = actorById(targetId);
    if (target == null) return;
    for (final unit in units) {
      if (!unit.alive || unit.isHarvester) continue;
      unit
        ..order = UnitOrder.attack
        ..targetId = targetId
        ..repathTimer = 0
        ..clearPath();
    }
  }

  void issueHarvest(List<Unit> units) {
    for (final unit in units) {
      if (!unit.alive || !unit.isHarvester) continue;
      unit
        ..phase = HarvesterPhase.idle
        ..order = UnitOrder.idle
        ..targetId = null
        ..clearPath();
    }
  }

  void stopUnits(List<Unit> units) {
    for (final unit in units) {
      if (!unit.alive) continue;
      if (unit.isHarvester) {
        unit.phase = HarvesterPhase.idle;
      }
      unit.clearOrders();
    }
  }

  List<Offset> _formationOffsets(int count) {
    final result = <Offset>[Offset.zero];
    var ring = 1;
    while (result.length < count) {
      for (var dy = -ring; dy <= ring; dy++) {
        for (var dx = -ring; dx <= ring; dx++) {
          if (math.max(dx.abs(), dy.abs()) != ring) continue;
          result.add(Offset(dx.toDouble(), dy.toDouble()));
          if (result.length >= count) break;
        }
        if (result.length >= count) break;
      }
      ring++;
    }
    return result;
  }

  // ===== 主循环 =====

  void update(double dt) {
    if (result != null) return;
    elapsed += dt;
    _updateProduction(dt);
    for (final unit in List<Unit>.of(redUnits)) {
      if (unit.alive) _updateUnit(unit, dt);
    }
    for (final unit in List<Unit>.of(blueUnits)) {
      if (unit.alive) _updateUnit(unit, dt);
    }
    _updateBuildings(dt);
    _cleanupDead();
    onAiTick?.call(this, dt);
    _checkVictory();
  }

  void _updateUnit(Unit unit, double dt) {
    unit.advanceFlash(dt);
    unit.fireCooldown = math.max(0, unit.fireCooldown - dt);
    unit.repathTimer = math.max(0, unit.repathTimer - dt);
    if (unit.isHarvester) {
      _updateHarvester(unit, dt);
      return;
    }
    final target = unit.targetId == null ? null : actorById(unit.targetId!);
    if (unit.order == UnitOrder.attack) {
      if (target == null) {
        unit.clearOrders();
      } else {
        _engage(unit, target, dt);
        return;
      }
    }
    if (unit.order == UnitOrder.move) {
      if (unit.hasPath) {
        _followPath(unit, dt);
      } else {
        unit.order = UnitOrder.idle;
        unit.destination = null;
      }
      // 行军途中只打射程内的临时目标，不为它停下脚步。
      final autoTarget = unit.targetId == null
          ? null
          : actorById(unit.targetId!);
      if (autoTarget != null &&
          _distanceTo(unit, autoTarget) <= unit.spec.range) {
        _fireAt(unit, autoTarget);
      } else {
        unit.targetId = null;
      }
      _acquireIfIdle(unit);
      return;
    }
    // 待命：有目标就原地开火，目标消失在射程外则清空。
    if (target != null) {
      final distance = _distanceTo(unit, target);
      if (distance <= unit.spec.range) {
        _fireAt(unit, target);
      } else {
        unit.targetId = null;
      }
    }
    _acquireIfIdle(unit);
  }

  void _acquireIfIdle(Unit unit) {
    if (unit.spec.attack <= 0) return;
    if (unit.targetId != null) return;
    if (unit.repathTimer > 0) return;
    unit.repathTimer = 0.4;
    final target = nearestEnemy(
      unit.team,
      unit.position,
      maxDistance: unit.spec.range + 1.2,
    );
    if (target == null) return;
    unit.targetId = target.id;
  }

  void _engage(Unit unit, Actor target, double dt) {
    final distance = _distanceTo(unit, target);
    if (distance <= unit.spec.range) {
      unit.clearPath();
      _fireAt(unit, target);
      return;
    }
    if (unit.repathTimer <= 0 || !unit.hasPath) {
      final goal = _approachTile(target);
      final path = goal == null
          ? null
          : _finder.find(TilePoint(unit.x.floor(), unit.y.floor()), goal);
      if (path != null) unit.setPath(path);
      unit.repathTimer = 0.9;
    }
    if (unit.hasPath) {
      _followPath(unit, dt);
    }
  }

  void _followPath(Unit unit, double dt) {
    final waypoint = unit.nextWaypoint;
    if (waypoint == null) return;
    final tx = waypoint.x + 0.5;
    final ty = waypoint.y + 0.5;
    final dx = tx - unit.x;
    final dy = ty - unit.y;
    final distance = math.sqrt(dx * dx + dy * dy);
    final speed =
        unit.spec.speed * map.speedFactor(waypoint.x, waypoint.y) * dt;
    if (distance <= speed || distance < 0.02) {
      unit
        ..x = tx
        ..y = ty
        ..pathIndex = unit.pathIndex + 1;
      return;
    }
    unit
      ..x += dx / distance * speed
      ..y += dy / distance * speed
      ..facing = math.atan2(dy, dx);
  }

  void _updateHarvester(Unit unit, double dt) {
    switch (unit.phase) {
      case HarvesterPhase.moving:
        _followPath(unit, dt);
        if (!unit.hasPath) {
          unit
            ..phase = HarvesterPhase.idle
            ..repathTimer = 0;
        }
        break;
      case HarvesterPhase.idle:
        if (unit.repathTimer > 0) return;
        unit.repathTimer = 0.8;
        final refinery = nearestRefinery(unit.team, unit.position);
        if (refinery == null) {
          unit.repathTimer = 3;
          return;
        }
        final ore = nearestOre(unit.position);
        if (ore == null) {
          unit.repathTimer = 4;
          return;
        }
        unit
          ..oreTile = ore
          ..phase = HarvesterPhase.toOre;
        _pathTo(unit, ore.center);
        break;
      case HarvesterPhase.toOre:
        _followPath(unit, dt);
        if (unit.hasPath) return;
        final ore = unit.oreTile;
        if (ore == null || map.oreAt(ore.x, ore.y) <= 0) {
          unit.phase = HarvesterPhase.idle;
          unit.repathTimer = 0;
          return;
        }
        if ((unit.position - ore.center).distance > 1.6) {
          unit
            ..phase = HarvesterPhase.idle
            ..repathTimer = 0.6;
          return;
        }
        unit
          ..phase = HarvesterPhase.mining
          ..miningTimer = 1.4;
        break;
      case HarvesterPhase.mining:
        final ore = unit.oreTile;
        if (ore == null) {
          unit.phase = HarvesterPhase.idle;
          return;
        }
        unit.miningCarry += 180 * dt;
        final amount = unit.miningCarry.floor();
        unit.miningCarry -= amount;
        final mined = map.mine(ore.x, ore.y, amount);
        unit.cargo = math.min(unit.spec.capacity, unit.cargo + mined);
        if (unit.full) {
          _sendToRefinery(unit);
          return;
        }
        if (mined <= 0) {
          // 当前矿格采空，换最近的矿。
          final next = nearestOre(unit.position);
          if (next == null) {
            _sendToRefinery(unit);
          } else {
            unit.oreTile = next;
            unit.phase = HarvesterPhase.toOre;
            _pathTo(unit, next.center);
          }
        }
        break;
      case HarvesterPhase.toRefinery:
        _followPath(unit, dt);
        if (unit.hasPath) return;
        unit
          ..phase = HarvesterPhase.unloading
          ..miningTimer = 0.5;
        break;
      case HarvesterPhase.unloading:
        unit.miningTimer -= dt;
        if (unit.miningTimer > 0) return;
        final refinery = unit.refineryId == null
            ? null
            : actorById(unit.refineryId!);
        if (refinery == null) {
          unit.phase = HarvesterPhase.idle;
          unit.repathTimer = 0;
          return;
        }
        final earned = unit.unload();
        if (earned > 0) {
          final multiplier = unit.team == Team.blue
              ? difficulty.aiIncome
              : 1.0;
          _addCredits(unit.team, (earned * multiplier).round());
          _emit(
            BattleEvent(
              BattleEventKind.unload,
              unit.x,
              unit.y,
              team: unit.team,
              radius: 0.4,
            ),
          );
          if (unit.team == Team.red) {
            addNotice('采矿车入库 +${(earned * multiplier).round()}', level: NoticeLevel.success);
          }
        }
        final ore = nearestOre(unit.position);
        if (ore == null) {
          unit.phase = HarvesterPhase.idle;
          unit.repathTimer = 2;
        } else {
          unit
            ..oreTile = ore
            ..phase = HarvesterPhase.toOre
            ..repathTimer = 0;
          _pathTo(unit, ore.center);
        }
        break;
    }
  }

  void _sendToRefinery(Unit unit) {
    final refinery = nearestRefinery(unit.team, unit.position);
    if (refinery == null) {
      unit.phase = HarvesterPhase.idle;
      return;
    }
    unit
      ..refineryId = refinery.id
      ..phase = HarvesterPhase.toRefinery;
    final spot = findSpawnTile(refinery);
    if (spot != null) {
      _pathTo(unit, spot.center);
    } else {
      unit.clearPath();
    }
  }

  void _pathTo(Unit unit, Offset target) {
    final goal = _nearestFreeTile(target, radius: 3);
    if (goal == null) {
      unit.clearPath();
      return;
    }
    final path = _finder.find(TilePoint(unit.x.floor(), unit.y.floor()), goal);
    if (path == null) {
      unit.clearPath();
    } else {
      unit.setPath(path);
    }
  }

  void _fireAt(Unit unit, Actor target) {
    if (unit.fireCooldown > 0) return;
    final spec = unit.spec;
    unit.fireCooldown = spec.cooldown / powerFactor(unit.team);
    unit.facing = math.atan2(target.y - unit.y, target.x - unit.x);
    _applyDamage(
      attacker: unit,
      target: target,
      attack: spec.attack,
      multiplier: spec.multiplierAgainst(target.armor),
      shell: spec.armor == ArmorClass.vehicle,
    );
  }

  void _applyDamage({
    required Actor attacker,
    required Actor target,
    required int attack,
    required double multiplier,
    required bool shell,
  }) {
    final damage = math.max(1, (attack * multiplier).round());
    target.applyDamage(damage);
    _emit(
      BattleEvent(
        shell ? BattleEventKind.shell : BattleEventKind.bullet,
        attacker.x,
        attacker.y,
        tx: target.x,
        ty: target.y,
        team: attacker.team,
      ),
    );
    if (!target.alive) {
      _emit(
        BattleEvent(
          BattleEventKind.explosion,
          target.x,
          target.y,
          team: attacker.team,
          radius: target.isBuilding ? 1.5 : 0.8,
        ),
      );
    }
  }

  void _updateBuildings(double dt) {
    for (final building in List<Building>.of(redBuildings)) {
      if (building.alive) _updateDefense(building, dt);
    }
    for (final building in List<Building>.of(blueBuildings)) {
      if (building.alive) _updateDefense(building, dt);
    }
  }

  void _updateDefense(Building building, double dt) {
    building.advanceFlash(dt);
    if (!building.spec.isDefense) return;
    building.fireCooldown = math.max(0, building.fireCooldown - dt);
    if (building.fireCooldown > 0) return;
    final target = nearestEnemy(
      building.team,
      building.position,
      maxDistance: building.spec.range,
      building: building,
    );
    if (target == null) return;
    building.fireCooldown = building.spec.cooldown / powerFactor(building.team);
    building.facing = math.atan2(target.y - building.y, target.x - building.x);
    _applyDamage(
      attacker: building,
      target: target,
      attack: building.spec.attack,
      multiplier: building.spec.multiplierAgainst(target.armor),
      shell: true,
    );
  }

  void _cleanupDead() {
    for (final actor in List<Actor>.of(actors)) {
      if (actor.alive) continue;
      actors.remove(actor);
      if (actor is Unit) {
        unitsOf(actor.team).remove(actor);
      } else if (actor is Building) {
        buildingsOf(actor.team).remove(actor);
        for (var y = actor.tileY; y < actor.tileY + actor.spec.height; y++) {
          for (var x = actor.tileX; x < actor.tileX + actor.spec.width; x++) {
            if (!map.inBounds(x, y)) continue;
            if (_occupancy[y * map.width + x] == actor) {
              _occupancy[y * map.width + x] = null;
            }
          }
        }
        if (actor.team == Team.red) {
          addNotice('${actor.spec.kind.label}被摧毁', level: NoticeLevel.warning);
        }
      }
    }
  }

  void _checkVictory() {
    if (result != null) return;
    if (blueBuildings.isEmpty) {
      result = BattleResult.victory;
      addNotice('蓝军基地已被摧毁，战斗胜利', level: NoticeLevel.success);
    } else if (redBuildings.isEmpty) {
      result = BattleResult.defeat;
      addNotice('赤军基地失守，战斗失败', level: NoticeLevel.warning);
    }
  }

  // ===== 空间查询 =====

  double _distanceTo(Actor from, Actor to) {
    if (to is Building) {
      final rect = to.bounds;
      final dx = math.max(math.max(rect.left - from.x, 0), from.x - rect.right);
      final dy = math.max(math.max(rect.top - from.y, 0), from.y - rect.bottom);
      return math.sqrt(dx * dx + dy * dy) - 0.25;
    }
    return (from.position - to.position).distance - to.radius * 0.4;
  }

  TilePoint? _approachTile(Actor target) {
    if (target is! Building) {
      return TilePoint(target.x.floor(), target.y.floor());
    }
    for (var radius = 1; radius <= 5; radius++) {
      for (var dy = -radius; dy <= radius; dy++) {
        for (var dx = -radius; dx <= radius; dx++) {
          if (math.max(dx.abs(), dy.abs()) != radius) continue;
          final x = (target.x + dx).floor();
          final y = (target.y + dy).floor();
          if (x < 0 || y < 0 || x >= map.width || y >= map.height) continue;
          if (isBlocked(x, y)) continue;
          if (_rectGap(Offset(x + 0.5, y + 0.5), target.bounds) <= 0.6) {
            return TilePoint(x, y);
          }
        }
      }
    }
    return null;
  }

  TilePoint? _nearestFreeTile(Offset point, {int radius = 4}) {
    final cx = point.dx.floor();
    final cy = point.dy.floor();
    for (var r = 0; r <= radius; r++) {
      for (var dy = -r; dy <= r; dy++) {
        for (var dx = -r; dx <= r; dx++) {
          if (r > 0 && math.max(dx.abs(), dy.abs()) != r) continue;
          final x = cx + dx;
          final y = cy + dy;
          if (!map.inBounds(x, y) || isBlocked(x, y)) continue;
          return TilePoint(x, y);
        }
      }
    }
    return null;
  }

  TilePoint? nearestOre(Offset from, {int maxDistance = 80}) {
    TilePoint? best;
    var bestDistance = double.infinity;
    for (var y = 0; y < map.height; y++) {
      for (var x = 0; x < map.width; x++) {
        if (map.oreAt(x, y) <= 0) continue;
        final distance = (Offset(x + 0.5, y + 0.5) - from).distance;
        if (distance > maxDistance) continue;
        if (distance < bestDistance) {
          bestDistance = distance;
          best = TilePoint(x, y);
        }
      }
    }
    return best;
  }

  Building? nearestRefinery(Team team, Offset from) {
    Building? best;
    var bestDistance = double.infinity;
    for (final building in buildingsOf(team)) {
      if (building.spec.kind != BuildingKind.refinery) continue;
      final distance = (building.position - from).distance;
      if (distance < bestDistance) {
        bestDistance = distance;
        best = building;
      }
    }
    return best;
  }

  Actor? nearestEnemy(
    Team team,
    Offset from, {
    double? maxDistance,
    Building? building,
  }) {
    Actor? best;
    var bestScore = double.infinity;
    final enemies = actors.where((actor) => actor.team != team && actor.alive);
    for (final actor in enemies) {
      final distance = building == null
          ? (actor.position - from).distance - actor.radius * 0.5
          : _distanceTo(building, actor);
      if (maxDistance != null && distance > maxDistance) continue;
      // 优先攻击单位，其次建筑。
      final score = actor.isBuilding ? distance + 2.5 : distance;
      if (score < bestScore) {
        bestScore = score;
        best = actor;
      }
    }
    return best;
  }

  Actor? actorAt(Offset tile, {bool preferUnits = true}) {
    if (preferUnits) {
      Actor? best;
      var bestDistance = double.infinity;
      for (final actor in actors) {
        if (!actor.alive || actor.isBuilding) continue;
        final distance = (actor.position - tile).distance;
        if (distance <= actor.radius + 0.35 && distance < bestDistance) {
          bestDistance = distance;
          best = actor;
        }
      }
      if (best != null) return best;
    }
    return buildingAt(tile.dx.floor(), tile.dy.floor());
  }

  // ===== 资金 =====

  void _addCredits(Team team, int amount) {
    if (team == Team.red) {
      creditsRed = math.max(0, creditsRed + amount);
    } else {
      creditsBlue = math.max(0, creditsBlue + amount);
    }
  }

  void addCredits(Team team, int amount) => _addCredits(team, amount);

  /// 供 AI 使用的随机源，保证测试可复现。
  int randomInt(int max) => max <= 0 ? 0 : _random.nextInt(max);

  /// 测试辅助：直接生成单位与建筑，绕过生产与放置校验。
  Unit spawnUnitForTest(Team team, UnitKind kind, Offset at) =>
      _spawnUnit(team, kind, at);

  Building spawnBuildingForTest(
    Team team,
    BuildingKind kind,
    int tileX,
    int tileY,
  ) => _spawnBuilding(team, kind, tileX, tileY);
}
