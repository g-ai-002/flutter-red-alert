import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui';

import 'battle_types.dart';
import 'entity.dart';
import 'mission.dart';
import 'pathfinding.dart';
import 'production_catalog.dart';
import 'terrain.dart';
import 'vision.dart';

part 'battle_combat.dart';
part 'battle_construction.dart';
part 'battle_movement.dart';
part 'battle_production.dart';
part 'battle_setup.dart';

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
    this.mission,
    int seed = 7,
  }) : vision = VisionMap(width: map.width, height: map.height) {
    _occupancy = List<Building?>.filled(map.width * map.height, null);
    _random = math.Random(seed);
    _finder = PathFinder(
      map: map,
      isBlocked: (x, y) =>
          map.blocked(x, y) || _occupancy[y * map.width + x] != null,
    );
  }

  /// 创建一张新地图并布置双方初始基地；传入战役时按关卡配置生成。
  factory BattleState.create({
    BattleDifficulty difficulty = BattleDifficulty.normal,
    GameMission? mission,
    int mapSeed = 20261114,
    int setupSeed = 7,
  }) {
    final state = BattleState(
      map: GameMap.generate(
        size: mission?.mapSize ?? 44,
        seed: mission?.mapSeed ?? mapSeed,
      ),
      difficulty: mission?.difficulty ?? difficulty,
      mission: mission,
      seed: setupSeed,
    );
    state._setupBases();
    state._applyMission();
    state._refreshVision();
    return state;
  }

  final GameMap map;
  final BattleDifficulty difficulty;
  final GameMission? mission;

  /// 玩家阵营的战争迷雾；蓝军 AI 不受迷雾限制。
  final VisionMap vision;

  /// 雷达扫描剩余时间与冷却，单位秒。
  double radarRemaining = 0;
  double radarCooldown = 0;

  static const double radarScanSeconds = 4;
  static const double radarCooldownSeconds = 45;

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
  final Map<int, Actor> _byId = {};
  final Map<Team, Map<ProductionCategory, ProductionJob?>> _queues = {
    for (final team in Team.values)
      team: {for (final category in ProductionCategory.values) category: null},
  };
  final Map<Team, List<BuildingKind>> _readyStructures = {
    for (final team in Team.values) team: <BuildingKind>[],
  };
  late final Map<Team, UnmodifiableListView<BuildingKind>> _readyViews = {
    for (final team in Team.values)
      team: UnmodifiableListView(_readyStructures[team]!),
  };

  // ===== 查询 =====

  List<Unit> unitsOf(Team team) => team == Team.red ? redUnits : blueUnits;

  List<Building> buildingsOf(Team team) =>
      team == Team.red ? redBuildings : blueBuildings;

  int creditsOf(Team team) => team == Team.red ? creditsRed : creditsBlue;

  Actor? actorById(int id) {
    final actor = _byId[id];
    return actor != null && actor.alive ? actor : null;
  }

  Building? buildingAt(int x, int y) {
    if (x < 0 || y < 0 || x >= map.width || y >= map.height) return null;
    return _occupancy[y * map.width + x];
  }

  bool isBlocked(int x, int y) => map.blocked(x, y) || buildingAt(x, y) != null;

  int countBuildings(Team team, BuildingKind kind) =>
      buildingsOf(team).where((b) => b.spec.kind == kind).length;

  bool hasBuilding(Team team, BuildingKind kind) =>
      countBuildings(team, kind) > 0;

  int powerProduced(Team team) =>
      buildingsOf(team)
          .where((b) => b.spec.power > 0)
          .fold(0, (sum, b) => sum + b.spec.power);

  int powerUsed(Team team) =>
      buildingsOf(team)
          .where((b) => b.spec.power < 0)
          .fold(0, (sum, b) => sum - b.spec.power);

  /// 电力充足时为 1，不足时生产与防御效率减半。
  double powerFactor(Team team) =>
      powerUsed(team) > powerProduced(team) ? 0.5 : 1.0;

  /// 战斗单位数量（不含采矿车）。
  int armySize(Team team) => unitsOf(team).where((u) => !u.isHarvester).length;

  List<Unit> selectableUnits(Team team, Iterable<int> ids) =>
      unitsOf(team).where((u) => ids.contains(u.id) && u.alive).toList();

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

  // 基地与战役初始布置见 battle_setup.dart。

  // ===== 视野与雷达 =====

  /// 目标是否对玩家可见；己方目标恒为可见。
  bool isVisibleToPlayer(Actor actor) =>
      actor.team == Team.red || vision.sees(actor);

  bool get radarActive => radarRemaining > 0;

  bool get radarReady =>
      radarCooldown <= 0 && hasBuilding(Team.red, BuildingKind.hq);

  /// 启动一次雷达扫描：要求指挥中心在线且冷却结束。
  bool triggerRadar() {
    if (!radarReady) return false;
    radarRemaining = radarScanSeconds;
    radarCooldown = radarCooldownSeconds;
    addNotice('雷达扫描启动，敌军位置已标定', level: NoticeLevel.success);
    return true;
  }

  void _updateRadar(double dt) {
    if (radarRemaining > 0) radarRemaining = math.max(0, radarRemaining - dt);
    if (radarCooldown > 0) radarCooldown = math.max(0, radarCooldown - dt);
  }

  double _visionTimer = 0;

  void _updateVision(double dt) {
    _visionTimer += dt;
    if (_visionTimer < 0.2) return;
    _visionTimer = 0;
    _refreshVision();
  }

  /// 用己方全部存活单位与建筑重建可见范围。
  void _refreshVision() {
    vision.beginFrame();
    for (final unit in redUnits) {
      if (unit.alive) vision.reveal(unit);
    }
    for (final building in redBuildings) {
      if (building.alive) vision.reveal(building);
    }
    vision.commit();
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
    _updateVision(dt);
    _updateRadar(dt);
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
    var hasDead = false;
    for (final actor in actors) {
      if (!actor.alive) {
        hasDead = true;
        break;
      }
    }
    if (!hasDead) return;
    for (var i = actors.length - 1; i >= 0; i--) {
      final actor = actors[i];
      if (actor.alive) continue;
      actors.removeAt(i);
      _byId.remove(actor.id);
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
    final decapitate = mission?.objective == MissionObjective.decapitate;
    final blueLost = decapitate
        ? !hasBuilding(Team.blue, BuildingKind.hq)
        : blueBuildings.isEmpty;
    if (blueLost) {
      result = BattleResult.victory;
      addNotice(
        decapitate ? '蓝军指挥中心被摧毁，战斗胜利' : '蓝军基地已被摧毁，战斗胜利',
        level: NoticeLevel.success,
      );
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
