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
    final queue = state.queuesOf(team)[ProductionCategory.structure];
    if (queue != null) return;
    if (state.readyStructuresOf(team).length >= 2) return;
    final credits = state.creditsOf(team);
    final powerProduced = state.powerProduced(team);
    final powerUsed = state.powerUsed(team);

    BuildingKind? want;
    if (!state.hasBuilding(team, BuildingKind.hq)) {
      want = BuildingKind.hq;
    } else if (powerUsed + 30 > powerProduced) {
      want = BuildingKind.power;
    } else if (state.countBuildings(team, BuildingKind.refinery) < 2) {
      want = BuildingKind.refinery;
    } else if (state.countBuildings(team, BuildingKind.barracks) < 1) {
      want = BuildingKind.barracks;
    } else if (state.countBuildings(team, BuildingKind.factory) < 1) {
      want = BuildingKind.factory;
    } else if (state.countBuildings(team, BuildingKind.tower) < 3) {
      want = BuildingKind.tower;
    } else if (state.countBuildings(team, BuildingKind.power) < 3) {
      want = BuildingKind.power;
    } else if (state.countBuildings(team, BuildingKind.refinery) < 3) {
      want = BuildingKind.refinery;
    } else if (state.countBuildings(team, BuildingKind.tower) < 6) {
      want = BuildingKind.tower;
    }

    if (want == null) return;
    final cost = buildingSpecs[want]!.cost;
    // 留出生产资金，避免把收入全部砸进建筑导致断兵。
    final reserve = state.armySize(team) < difficulty.waveSize ? 700 : 250;
    if (credits < cost + reserve) return;
    if (!state.canProduce(team, ProductionCategory.structure, want.name)) return;
    state.startProduction(
      team,
      ProductionCategory.structure,
      want.name,
      announce: false,
    );
  }

  void _manageProduction(BattleState state) {
    final credits = state.creditsOf(team);
    final armorJob = state.jobOf(team, ProductionCategory.armor);
    if (armorJob == null && state.canProduce(team, ProductionCategory.armor, UnitKind.lightTank.name)) {
      final harvesters = state
          .unitsOf(team)
          .where((u) => u.isHarvester)
          .length;
      if (harvesters < 3 && credits >= 1100) {
        state.startProduction(
          team,
          ProductionCategory.armor,
          UnitKind.harvester.name,
          announce: false,
        );
      } else if (credits >= 1700) {
        state.startProduction(
          team,
          ProductionCategory.armor,
          UnitKind.heavyTank.name,
          announce: false,
        );
      } else if (credits >= 800) {
        state.startProduction(
          team,
          ProductionCategory.armor,
          UnitKind.lightTank.name,
          announce: false,
        );
      }
    }

    final infantryJob = state.jobOf(team, ProductionCategory.infantry);
    if (infantryJob == null &&
        state.canProduce(team, ProductionCategory.infantry, UnitKind.rifle.name) &&
        credits >= 500) {
      final rocketRatio = state.armySize(team) % 3 == 2;
      state.startProduction(
        team,
        ProductionCategory.infantry,
        rocketRatio ? UnitKind.rocket.name : UnitKind.rifle.name,
        announce: false,
      );
    }
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
      final defenders = units
          .where((u) => u.order != UnitOrder.attack)
          .toList();
      if (defenders.isNotEmpty) {
        final target = intruder.first;
        state.issueAttack(defenders, target.id);
      }
      return;
    }

    final readyToAttack = state.armySize(team) >= difficulty.waveSize;
    if (!readyToAttack && _waveTimer > 0) return;
    if (readyToAttack || _sentFirstWave) {
      _waveTimer = difficulty.waveSeconds;
      final idle = units.where((u) => u.order != UnitOrder.attack).toList();
      if (idle.isEmpty) return;
      final target = _pickAttackTarget(state);
      if (target == null) return;
      state.issueAttack(idle, target.id);
      _sentFirstWave = true;
    }
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
