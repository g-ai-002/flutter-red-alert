import 'dart:math' as math;
import 'dart:ui';

import 'battle_types.dart';
import 'entity.dart';
import 'pathfinding.dart';
import 'terrain.dart';

part 'battle_construction.dart';
part 'battle_combat.dart';
part 'battle_movement.dart';
part 'battle_production.dart';

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
/// 生产、建造、机动与战斗的实现分别在同库的 part 文件中。
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

  List<Unit> selectableUnits(Team team, Iterable<int> ids) => unitsOf(
    team,
  ).where((u) => ids.contains(u.id) && u.alive).toList();

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
      _spawnUnit(
        Team.red,
        UnitKind.harvester,
        GameMap.redBase + Offset(0, 2.2 + i),
      );
      _spawnUnit(
        Team.blue,
        UnitKind.harvester,
        GameMap.blueBase + Offset(0, -2.2 - i),
      );
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

  // ===== 主循环 =====

  void update(double dt) {
    if (result != null) return;
    elapsed += dt;
    _updateProduction(dt);
    for (final unit in redUnits) {
      if (unit.alive) _updateUnit(unit, dt);
    }
    for (final unit in blueUnits) {
      if (unit.alive) _updateUnit(unit, dt);
    }
    _updateBuildings(dt);
    _cleanupDead();
    onAiTick?.call(this, dt);
    _checkVictory();
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
