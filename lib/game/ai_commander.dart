import 'dart:math' as math;

import 'battle_state.dart';
import 'battle_types.dart';
import 'entity.dart';

/// 蓝军 AI 指挥官：维持经济与电力，按科技顺序补建筑，持续扩军并成波进攻。
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
    (BuildingKind.silo, 1),
  ];

  double _think = 0.5;
  double _waveTimer = 0;
  bool _sentFirstWave = false;

  void update(BattleState state, double dt) {
    _think -= dt;
    if (_think > 0) return;
    _think = 1;
    _placeReadyStructures(state);
    final enemyAir = state.unitsOf(team.opponent).any((u) => u.isAir);
    _manageStructures(state, enemyAir);
    _manageProduction(state, enemyAir);
    _manageStrike(state);
    _manageArmy(state, 1.0);
  }

  /// 发射井蓄满后优先打击赤军指挥中心，其次打击精炼厂等经济建筑。
  void _manageStrike(BattleState state) {
    if (!state.strikeReady(team)) return;
    Building? target;
    for (final building in state.buildingsOf(team.opponent)) {
      if (building.spec.kind == BuildingKind.hq) {
        target = building;
        break;
      }
      if (target == null || building.spec.kind == BuildingKind.refinery) target = building;
    }
    if (target != null) state.launchStrike(team, target.position);
  }

  void _placeReadyStructures(BattleState state) {
    for (var guard = 0; guard < 3; guard++) {
      final ready = state.readyStructuresOf(team);
      if (ready.isEmpty) return;
      final kind = ready.first;
      if (state.placeReadyStructure(team, kind) == null) return;
    }
  }

  void _manageStructures(BattleState state, bool enemyAir) {
    if (state.queuesOf(team)[ProductionCategory.structure] != null) return;
    if (state.readyStructuresOf(team).length >= 2) return;
    final want = _nextBuilding(state, enemyAir);
    if (want == null) return;
    final cost = buildingSpecs[want]!.cost;
    // 留出生产资金，避免把收入全部砸进建筑导致断兵。
    final reserve = state.armySize(team) < difficulty.waveSize ? 700 : 250;
    if (state.creditsOf(team) < cost + reserve) return;
    if (!state.canProduce(team, ProductionCategory.structure, want.name)) return;
    state.startProduction(team, ProductionCategory.structure, want.name, announce: false);
  }

  /// 先补齐指挥中心与电力，再按计划表补建筑；敌方空军出现时优先补防空。
  BuildingKind? _nextBuilding(BattleState state, bool enemyAir) {
    if (!state.hasBuilding(team, BuildingKind.hq)) return BuildingKind.hq;
    if (state.powerUsed(team) + 30 > state.powerProduced(team)) {
      return BuildingKind.power;
    }
    if (enemyAir && state.countBuildings(team, BuildingKind.airDefense) < 2) {
      return BuildingKind.airDefense;
    }
    for (final (kind, target) in _buildPlan) {
      if (state.countBuildings(team, kind) < target) return kind;
    }
    return null;
  }

  void _manageProduction(BattleState state, bool enemyAir) {
    final credits = state.creditsOf(team);
    if (state.jobOf(team, ProductionCategory.armor) == null &&
        state.canProduce(team, ProductionCategory.armor, UnitKind.lightTank.name)) {
      _startArmor(state, credits);
    }
    if (state.jobOf(team, ProductionCategory.infantry) == null &&
        state.canProduce(team, ProductionCategory.infantry, UnitKind.rifle.name) &&
        credits >= 500) {
      final needsEngineer =
          state.armySize(team) >= 5 && !state.unitsOf(team).any((u) => u.spec.isEngineer);
      final wantRocket = enemyAir || state.armySize(team) % 3 == 2;
      final kind = needsEngineer
          ? UnitKind.engineer
          : wantRocket
          ? UnitKind.rocket
          : UnitKind.rifle;
      state.startProduction(team, ProductionCategory.infantry, kind.name, announce: false);
    }
  }

  void _startArmor(BattleState state, int credits) {
    var harvesters = 0;
    var artillery = 0;
    var gunships = 0;
    for (final unit in state.unitsOf(team)) {
      if (unit.isHarvester) harvesters++;
      if (unit.isAir) gunships++;
      if (unit.spec.kind == UnitKind.artillery) artillery++;
    }
    final UnitKind? want;
    if (harvesters < 3 && credits >= 1100) {
      want = UnitKind.harvester;
    } else if (gunships < 2 && credits >= 1900) {
      want = UnitKind.gunship;
    } else if (artillery < 2 && state.armySize(team) >= 8 && credits >= 2000) {
      want = UnitKind.artillery;
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
    final units = state.unitsOf(team).where((u) => !u.isHarvester && !u.spec.isEngineer).toList();
    if (units.isEmpty) return;

    // 基地附近出现敌军时优先回防；打不到空中目标的部队继续执行进攻计划。
    final base = state.map.baseOf(team);
    final intruder = state
        .unitsOf(team.opponent)
        .where((u) => (u.position - base).distance < 12)
        .toList();
    if (intruder.isNotEmpty) {
      final air = intruder.first.isAir;
      final defenders = units
          .where((u) => u.order != UnitOrder.attack && u.spec.canTarget(air))
          .toList();
      if (defenders.isNotEmpty) {
        state.issueAttack(defenders, intruder.first.id);
        return;
      }
    }

    final readyToAttack = state.armySize(team) >= difficulty.waveSize;
    if (!readyToAttack && _waveTimer > 0) return;
    // 首波之后也要攒够最低兵力再出击，避免逐个送死形成无休止的拉锯。
    if (!readyToAttack && (!_sentFirstWave || units.length < 4)) return;
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
