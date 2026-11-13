import 'dart:math' as math;

import 'battle_state.dart';
import 'battle_types.dart';
import 'entity.dart';

/// 蓝军 AI 指挥官：维持经济与电力，按科技顺序补建筑，持续扩军并成波进攻。
///
/// 每秒思考一次，所有决策都走与玩家相同的生产与放置接口，保证双方规则一致。
class AiCommander {
  AiCommander({required this.team, required this.difficulty}) {
    _waveTimer = difficulty.waveSeconds * 0.9;
  }

  final Team team;
  final BattleDifficulty difficulty;

  /// 建筑补齐顺序：每种建筑的目标数量，按表顺序逐项检查。
  static const List<(BuildingKind, int)> _buildPlan = [
    (BuildingKind.refinery, 2),
    (BuildingKind.barracks, 1),
    (BuildingKind.factory, 1),
    (BuildingKind.tower, 3),
    (BuildingKind.power, 3),
    (BuildingKind.refinery, 3),
    (BuildingKind.tower, 6),
  ];

  double _think = 0.5;
  double _waveTimer = 0;
  bool _sentFirstWave = false;

  void update(BattleState state, double dt) {
    _think -= dt;
    if (_think > 0) return;
    _think = 1;
    _placeReadyStructures(state);
    _manageStructures(state);
    _manageProduction(state);
    _manageArmy(state, 1.0);
  }

  void _placeReadyStructures(BattleState state) {
    for (var guard = 0; guard < 3; guard++) {
      final ready = state.readyStructuresOf(team);
      if (ready.isEmpty) return;
      final kind = ready.first;
      if (state.placeReadyStructure(team, kind) == null) return;
    }
  }

  void _manageStructures(BattleState state) {
    if (state.queuesOf(team)[ProductionCategory.structure] != null) return;
    if (state.readyStructuresOf(team).length >= 2) return;
    final want = _nextBuilding(state);
    if (want == null) return;
    final cost = buildingSpecs[want]!.cost;
    // 留出生产资金，避免把收入全部砸进建筑导致断兵。
    final reserve = state.armySize(team) < difficulty.waveSize ? 700 : 250;
    if (state.creditsOf(team) < cost + reserve) return;
    if (!state.canProduce(team, ProductionCategory.structure, want.name)) return;
    state.startProduction(team, ProductionCategory.structure, want.name, announce: false);
  }

  /// 先补齐指挥中心与电力，再按计划表补建筑。
  BuildingKind? _nextBuilding(BattleState state) {
    if (!state.hasBuilding(team, BuildingKind.hq)) return BuildingKind.hq;
    if (state.powerUsed(team) + 30 > state.powerProduced(team)) {
      return BuildingKind.power;
    }
    for (final (kind, target) in _buildPlan) {
      if (state.countBuildings(team, kind) < target) return kind;
    }
    return null;
  }

  void _manageProduction(BattleState state) {
    final credits = state.creditsOf(team);
    if (state.jobOf(team, ProductionCategory.armor) == null &&
        state.canProduce(team, ProductionCategory.armor, UnitKind.lightTank.name)) {
      _startArmor(state, credits);
    }
    if (state.jobOf(team, ProductionCategory.infantry) == null &&
        state.canProduce(team, ProductionCategory.infantry, UnitKind.rifle.name) &&
        credits >= 500) {
      final wantRocket = state.armySize(team) % 3 == 2;
      state.startProduction(
        team,
        ProductionCategory.infantry,
        (wantRocket ? UnitKind.rocket : UnitKind.rifle).name,
        announce: false,
      );
    }
  }

  void _startArmor(BattleState state, int credits) {
    final harvesters = state.unitsOf(team).where((u) => u.isHarvester).length;
    final UnitKind? want;
    if (harvesters < 3 && credits >= 1100) {
      want = UnitKind.harvester;
    } else if (credits >= 1700) {
      want = UnitKind.heavyTank;
    } else if (credits >= 800) {
      want = UnitKind.lightTank;
    } else {
      want = null;
    }
    if (want == null) return;
    state.startProduction(team, ProductionCategory.armor, want.name, announce: false);
  }

  void _manageArmy(BattleState state, double dt) {
    _waveTimer -= dt;
    final units = state.unitsOf(team).where((u) => !u.isHarvester).toList();
    if (units.isEmpty) return;

    // 基地附近出现敌军时优先回防。
    final base = state.map.baseOf(team);
    final intruder = state
        .unitsOf(team.opponent)
        .where((u) => (u.position - base).distance < 12)
        .toList();
    if (intruder.isNotEmpty) {
      final defenders = units.where((u) => u.order != UnitOrder.attack).toList();
      if (defenders.isNotEmpty) {
        state.issueAttack(defenders, intruder.first.id);
      }
      return;
    }

    final readyToAttack = state.armySize(team) >= difficulty.waveSize;
    if (!readyToAttack && _waveTimer > 0) return;
    if (!readyToAttack && !_sentFirstWave) return;
    _waveTimer = difficulty.waveSeconds;
    final idle = units.where((u) => u.order != UnitOrder.attack).toList();
    if (idle.isEmpty) return;
    final target = _pickAttackTarget(state);
    if (target == null) return;
    state.issueAttack(idle, target.id);
    _sentFirstWave = true;
  }

  /// 优先打指挥中心，其次打离己方基地最近的建筑。
  Building? _pickAttackTarget(BattleState state) {
    final enemies = state.buildingsOf(team.opponent);
    if (enemies.isEmpty) return null;
    final base = state.map.baseOf(team);
    Building? hq;
    Building? nearest;
    var nearestDistance = double.infinity;
    for (final building in enemies) {
      if (building.spec.kind == BuildingKind.hq) hq = building;
      final distance = (building.position - base).distance;
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearest = building;
      }
    }
    if (hq != null) {
      // 后期才直取指挥中心，前期先拆外围，形成推进节奏。
      final waves = state.elapsed / math.max(1, difficulty.waveSeconds);
      if (waves > 6) return hq;
    }
    return nearest;
  }
}
