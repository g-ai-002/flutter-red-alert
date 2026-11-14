part of 'battle_state.dart';

/// 生产任务：记录生产项与进度，名称、价格和工期直接取目录里的定义。
class ProductionJob {
  ProductionJob({required this.item}) : progress = 0;

  final ProductionItem item;
  double progress;

  String get id => item.id;

  String get name => item.name;

  String get icon => item.icon;

  ProductionCategory get category => item.category;

  int get cost => item.cost;

  double get totalSeconds => item.seconds;
}

/// 生产队列与解锁判定：玩家建造栏、蓝军 AI 与模拟主循环共用同一套规则。
extension BattleProduction on BattleState {
  Map<ProductionCategory, ProductionJob?> queuesOf(Team team) => _queues[team]!;

  ProductionJob? jobOf(Team team, ProductionCategory category) => _queues[team]![category];

  List<BuildingKind> readyStructuresOf(Team team) => _readyViews[team]!;

  /// 某类建筑是否已生产完成、等待放置。
  bool hasReadyStructure(Team team, BuildingKind kind) => _readyStructures[team]!.contains(kind);

  bool canProduce(Team team, ProductionCategory category, String id) =>
      productionBlocker(team, category, id) == null;

  /// 返回无法生产的原因，null 表示条件满足；供建造栏角标与生产入口共用。
  String? productionBlocker(Team team, ProductionCategory category, String id) {
    final item = ProductionCatalog.byId(id);
    if (item == null) {
      return category == ProductionCategory.structure ? '未知建筑' : '未知单位';
    }
    if (item.category != category) return '分类不匹配';
    if (category == ProductionCategory.structure) {
      // 指挥中心被摧毁后，只要有其他建筑就允许重建。
      if (!hasBuilding(team, BuildingKind.hq)) {
        if (id != BuildingKind.hq.name) return '需要指挥中心';
        return buildingsOf(team).isEmpty ? '基地已失守' : null;
      }
    } else if (!hasBuilding(team, producerForCategory[category]!)) {
      return '需要${producerForCategory[category]!.label}';
    }
    final requires = item.requires;
    if (requires != null && !hasBuilding(team, requires)) {
      return '需要${requires.label}';
    }
    return null;
  }

  int costOf(String id) => ProductionCatalog.byId(id)?.cost ?? 0;

  String nameOf(String id) => ProductionCatalog.byId(id)?.name ?? id;

  /// 开始生产；资金立即扣除，队列已有任务或条件不足时返回 false。
  bool startProduction(Team team, ProductionCategory category, String id, {bool announce = true}) {
    if (result != null) return false;
    final item = ProductionCatalog.byId(id);
    final queue = _queues[team]!;
    if (queue[category] != null) {
      if (announce) {
        addNotice('${category.label}队列正在生产', level: NoticeLevel.warning);
      }
      return false;
    }
    if (item == null || !canProduce(team, category, id)) {
      if (announce) {
        addNotice('缺少前置建筑，暂时无法生产${nameOf(id)}', level: NoticeLevel.warning);
      }
      return false;
    }
    if (creditsOf(team) < item.cost) {
      if (announce) {
        addNotice('资金不足，无法生产${item.name}', level: NoticeLevel.warning);
      }
      return false;
    }
    addCredits(team, -item.cost);
    queue[category] = ProductionJob(item: item);
    return true;
  }

  void cancelProduction(Team team, ProductionCategory category) {
    final job = _queues[team]![category];
    if (job == null) return;
    addCredits(team, job.cost);
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
        if (job.item.isBuilding) {
          _readyStructures[team]!.add(job.item.building!);
          _queues[team]![category] = null;
          if (team == Team.red) {
            addNotice('${job.name}已就绪，点击建造栏放置', level: NoticeLevel.success);
          }
        } else {
          _completeUnitJob(team, category, job);
        }
      }
    }
  }

  void _completeUnitJob(Team team, ProductionCategory category, ProductionJob job) {
    if (_trySpawnUnit(team, job.item.unit!)) return;
    // 出兵口被占满时保持 100%，等待空位；生产者被摧毁则中止并退款。
    if (hasBuilding(team, producerForCategory[category]!)) return;
    addCredits(team, job.cost);
    _queues[team]![category] = null;
    if (team == Team.red) {
      addNotice('生产建筑被摧毁，${job.name}生产中止', level: NoticeLevel.warning);
    }
  }

  bool _trySpawnUnit(Team team, UnitKind kind) {
    final category = unitSpecs[kind]!.category;
    final producerKind = producerForCategory[category]!;
    for (final producer in buildingsOf(team)) {
      if (producer.spec.kind != producerKind) continue;
      final tile = findSpawnTile(producer);
      if (tile == null) continue;
      _spawnUnit(team, kind, tile.center);
      _queues[team]![category] = null;
      _emit(BattleEvent(BattleEventKind.spawn, tile.x + 0.5, tile.y + 0.5, team: team));
      if (team == Team.red) {
        addNotice('${kind.label}已出厂', level: NoticeLevel.success);
      }
      return true;
    }
    return false;
  }
}
