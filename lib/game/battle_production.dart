part of 'battle_state.dart';

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

/// 生产队列与解锁判定：玩家建造栏、蓝军 AI 与模拟主循环共用同一套规则。
extension BattleProduction on BattleState {
  Map<ProductionCategory, ProductionJob?> queuesOf(Team team) => _queues[team]!;

  ProductionJob? jobOf(Team team, ProductionCategory category) =>
      _queues[team]![category];

  List<BuildingKind> readyStructuresOf(Team team) => _readyViews[team]!;

  bool canProduce(Team team, ProductionCategory category, String id) =>
      productionBlocker(team, category, id) == null;

  /// 返回无法生产的原因，null 表示条件满足；供建造栏角标与生产入口共用。
  String? productionBlocker(Team team, ProductionCategory category, String id) {
    if (category == ProductionCategory.structure) {
      final kind = buildingKindFromId(id);
      if (kind == null) return '未知建筑';
      // 指挥中心被摧毁后，只要有其他建筑就允许重建。
      if (!hasBuilding(team, BuildingKind.hq)) {
        if (kind != BuildingKind.hq) return '需要指挥中心';
        return buildingsOf(team).isEmpty ? '基地已失守' : null;
      }
      final requires = buildingSpecs[kind]!.requires;
      if (requires != null && !hasBuilding(team, requires)) {
        return '需要${requires.label}';
      }
      return null;
    }
    final kind = unitKindFromId(id);
    if (kind == null) return '未知单位';
    final producer = producerForCategory[category]!;
    if (!hasBuilding(team, producer)) return '需要${producer.label}';
    final requires = unitSpecs[kind]!.requires;
    if (requires != null && !hasBuilding(team, requires)) {
      return '需要${requires.label}';
    }
    return null;
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
      if (announce) {
        addNotice('${category.label}队列正在生产', level: NoticeLevel.warning);
      }
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
      if (announce) {
        addNotice('资金不足，无法生产${nameOf(id)}', level: NoticeLevel.warning);
      }
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
    final redPower = powerFactor(Team.red);
    final bluePower = powerFactor(Team.blue);
    for (final team in Team.values) {
      for (final category in ProductionCategory.values) {
        final job = _queues[team]![category];
        if (job == null) continue;
        final speed =
            (team == Team.red ? redPower : bluePower) *
            (team == Team.blue ? difficulty.aiBuildSpeed : 1.0);
        job.progress += dt * speed / job.totalSeconds;
        if (job.progress < 1) continue;
        job.progress = 1;
        if (category == ProductionCategory.structure) {
          final kind = buildingKindFromId(job.id)!;
          _readyStructures[team]!.add(kind);
          _queues[team]![category] = null;
          if (team == Team.red) {
            addNotice('${kind.label}已就绪，点击建造栏放置', level: NoticeLevel.success);
          }
        } else {
          if (!_trySpawnUnit(team, job.id)) {
            // 出兵口被占满时保持 100%，等待空位；生产者被摧毁则中止并退款。
            if (!hasBuilding(team, producerForCategory[category]!)) {
              _addCredits(team, job.cost);
              _queues[team]![category] = null;
              if (team == Team.red) {
                addNotice(
                  '生产建筑被摧毁，${job.name}生产中止',
                  level: NoticeLevel.warning,
                );
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
    final producers = buildingsOf(team)
        .where((b) => b.spec.kind == producerKind)
        .toList();
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
}
