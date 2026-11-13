part of 'battle_state.dart';

/// 开局布置：双方基地、采矿车与战役初始部队。
extension BattleSetup on BattleState {
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

  /// 按战役配置拨付额外军费、部署初始部队与蓝军据点。
  void _applyMission() {
    final mission = this.mission;
    if (mission == null) return;
    creditsRed += mission.bonusCredits;
    _deployArmy(Team.red, mission.startingArmy);
    _deployArmy(Team.blue, mission.enemyArmy);
    for (final kind in mission.enemyBuildings) {
      final spot = findPlacement(buildingSpecs[kind]!, Team.blue);
      if (spot != null) _spawnBuilding(Team.blue, kind, spot.x, spot.y);
    }
    addNotice('战役目标：${mission.objectiveText}');
  }

  /// 在基地外侧按三列阵型展开一支初始部队。
  void _deployArmy(Team team, List<UnitKind> army) {
    if (army.isEmpty) return;
    final base = map.baseOf(team);
    final facing = team == Team.red ? 1.0 : -1.0;
    for (var i = 0; i < army.length; i++) {
      final column = i % 3 - 1;
      final row = 2.6 + (i ~/ 3) * 1.4;
      _spawnUnit(team, army[i], base + Offset(column * 1.6, facing * row));
    }
  }
}
