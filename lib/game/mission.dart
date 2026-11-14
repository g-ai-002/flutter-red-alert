import 'battle_types.dart';

/// 战役目标：歼灭全部建筑或只斩首指挥中心。
enum MissionObjective {
  eradicate('歼灭战', '摧毁蓝军全部建筑'),
  decapitate('斩首行动', '摧毁蓝军指挥中心');

  const MissionObjective(this.label, this.brief);

  final String label;
  final String brief;
}

/// 一关战役的全部固定参数，关卡数据与模拟逻辑解耦。
class GameMission {
  const GameMission({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.brief,
    required this.objective,
    required this.difficulty,
    required this.mapSeed,
    this.mapSize = 44,
    this.bonusCredits = 0,
    this.startingArmy = const [],
    this.enemyArmy = const [],
    this.enemyBuildings = const [],
  });

  final String id;
  final String title;
  final String subtitle;
  final String brief;
  final MissionObjective objective;
  final BattleDifficulty difficulty;
  final int mapSeed;
  final int mapSize;
  final int bonusCredits;
  final List<UnitKind> startingArmy;
  final List<UnitKind> enemyArmy;
  final List<BuildingKind> enemyBuildings;

  String get objectiveText => objective.brief;

  int get startingCredits => difficulty.playerCredits + bonusCredits;
}

/// 五关战役，按顺序解锁。
const List<GameMission> campaignMissions = [
  GameMission(
    id: 'outpost',
    title: '第一关 · 前哨战',
    subtitle: '黎明前的试探',
    brief:
        '蓝军在前方荒原扎下一座前哨，只有零散守军。'
        '带两个班的步兵和一辆轻坦，把它的建筑全部拔掉，熟悉指挥节奏。',
    objective: MissionObjective.eradicate,
    difficulty: BattleDifficulty.easy,
    mapSeed: 20261114,
    bonusCredits: 1200,
    startingArmy: [UnitKind.rifle, UnitKind.rifle, UnitKind.rifle, UnitKind.lightTank],
    enemyArmy: [UnitKind.rifle, UnitKind.rifle],
    enemyBuildings: [BuildingKind.tower],
  ),
  GameMission(
    id: 'oreline',
    title: '第二关 · 矿石走廊',
    subtitle: '补给线上的拉锯',
    brief:
        '双方同时盯上了横贯地图的矿脉。蓝军已经修好战车工厂，'
        '枪骑兵与火箭兵会不断压上来，先稳住经济再反推。',
    objective: MissionObjective.eradicate,
    difficulty: BattleDifficulty.normal,
    mapSeed: 20261117,
    bonusCredits: 2000,
    startingArmy: [UnitKind.rifle, UnitKind.rocket, UnitKind.rocket, UnitKind.harvester],
    enemyArmy: [UnitKind.rifle, UnitKind.lightTank],
    enemyBuildings: [BuildingKind.barracks, BuildingKind.tower],
  ),
  GameMission(
    id: 'decapitation',
    title: '第三关 · 斩首行动',
    subtitle: '直取指挥中心',
    brief:
        '蓝军把重兵收拢在指挥中心周围，外围据点反而空虚。'
        '渗透部队需要绕过炮塔直取指挥中心，一旦得手敌军将全线动摇。',
    objective: MissionObjective.decapitate,
    difficulty: BattleDifficulty.hard,
    mapSeed: 20261121,
    bonusCredits: 2600,
    startingArmy: [UnitKind.rocket, UnitKind.rocket, UnitKind.heavyTank, UnitKind.lightTank],
    enemyArmy: [UnitKind.heavyTank, UnitKind.rifle, UnitKind.rifle],
    enemyBuildings: [BuildingKind.tower, BuildingKind.tower],
  ),
  GameMission(
    id: 'ironflood',
    title: '第四关 · 铁流',
    subtitle: '钢铁与火焰',
    brief:
        '蓝军把火炮推上了高地，正面冲锋会被远程火力撕碎。'
        '用工程兵维持装甲，再以火炮反制炮群，把他们的战车工厂碾平。',
    objective: MissionObjective.eradicate,
    difficulty: BattleDifficulty.normal,
    mapSeed: 20261125,
    bonusCredits: 2400,
    startingArmy: [
      UnitKind.engineer,
      UnitKind.rifle,
      UnitKind.rocket,
      UnitKind.artillery,
      UnitKind.lightTank,
    ],
    enemyArmy: [UnitKind.lightTank, UnitKind.artillery, UnitKind.rifle],
    enemyBuildings: [BuildingKind.factory, BuildingKind.tower],
  ),
  GameMission(
    id: 'dawn',
    title: '第五关 · 黎明总攻',
    subtitle: '最后的总攻',
    brief:
        '蓝军把最后的精锐与指挥中心一起缩进核心阵地，防空炮塔已封锁低空。'
        '带上工程兵、重炮与直升机，先敲掉防空再压制地面，把旗帜插上他们的指挥中心。',
    objective: MissionObjective.decapitate,
    difficulty: BattleDifficulty.hard,
    mapSeed: 20261128,
    bonusCredits: 3200,
    startingArmy: [
      UnitKind.engineer,
      UnitKind.engineer,
      UnitKind.heavyTank,
      UnitKind.heavyTank,
      UnitKind.artillery,
      UnitKind.rocket,
      UnitKind.gunship,
    ],
    enemyArmy: [
      UnitKind.heavyTank,
      UnitKind.heavyTank,
      UnitKind.rocket,
      UnitKind.artillery,
      UnitKind.rifle,
      UnitKind.gunship,
    ],
    enemyBuildings: [
      BuildingKind.tower,
      BuildingKind.tower,
      BuildingKind.barracks,
      BuildingKind.airDefense,
    ],
  ),
];

GameMission? missionById(String id) {
  for (final mission in campaignMissions) {
    if (mission.id == id) return mission;
  }
  return null;
}

/// 下一关；已是最后一关返回 null。
GameMission? nextMissionOf(GameMission mission) {
  final index = campaignMissions.indexWhere((item) => item.id == mission.id);
  if (index < 0 || index + 1 >= campaignMissions.length) return null;
  return campaignMissions[index + 1];
}
