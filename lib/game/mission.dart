import 'battle_types.dart';

/// 战役目标：歼灭全部建筑或只斩首指挥中心。
enum MissionObjective {
  eradicate('歼灭战', '摧毁蓝军全部建筑'),
  decapitate('斩首行动', '摧毁蓝军指挥中心');

  const MissionObjective(this.label, this.brief);

  final String label;
  final String brief;
}

/// 一关战役的全部固定参数：地图、难度、目标与双方初始部队。
///
/// 关卡数据与模拟解耦，[BattleState] 只按这里的配置生成地图与初始单位，
/// 新增关卡不需要改动战斗逻辑。
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

  /// 例：`第一关 · 前哨战`。
  final String title;

  /// 一句话氛围描述。
  final String subtitle;
  final String brief;
  final MissionObjective objective;
  final BattleDifficulty difficulty;
  final int mapSeed;
  final int mapSize;

  /// 在难度初始资金之上额外拨付的军费。
  final int bonusCredits;
  final List<UnitKind> startingArmy;
  final List<UnitKind> enemyArmy;

  /// 开局即存在的蓝军建筑，用于布置前哨炮塔等据点。
  final List<BuildingKind> enemyBuildings;

  String get objectiveText => objective.brief;

  int get startingCredits => difficulty.playerCredits + bonusCredits;
}

/// 三关战役，按顺序解锁。
const List<GameMission> campaignMissions = [
  GameMission(
    id: 'outpost',
    title: '第一关 · 前哨战',
    subtitle: '黎明前的试探',
    brief: '蓝军在前方荒原扎下一座前哨，只有零散守军。'
        '带两个班的步兵和一辆轻坦，把它的建筑全部拔掉，熟悉指挥节奏。',
    objective: MissionObjective.eradicate,
    difficulty: BattleDifficulty.easy,
    mapSeed: 20261114,
    bonusCredits: 1200,
    startingArmy: [
      UnitKind.rifle,
      UnitKind.rifle,
      UnitKind.rifle,
      UnitKind.lightTank,
    ],
    enemyArmy: [UnitKind.rifle, UnitKind.rifle],
    enemyBuildings: [BuildingKind.tower],
  ),
  GameMission(
    id: 'oreline',
    title: '第二关 · 矿石走廊',
    subtitle: '补给线上的拉锯',
    brief: '双方同时盯上了横贯地图的矿脉。蓝军已经修好战车工厂，'
        '枪骑兵与火箭兵会不断压上来，先稳住经济再反推。',
    objective: MissionObjective.eradicate,
    difficulty: BattleDifficulty.normal,
    mapSeed: 20261117,
    bonusCredits: 2000,
    startingArmy: [
      UnitKind.rifle,
      UnitKind.rocket,
      UnitKind.rocket,
      UnitKind.harvester,
    ],
    enemyArmy: [UnitKind.rifle, UnitKind.lightTank],
    enemyBuildings: [BuildingKind.barracks, BuildingKind.tower],
  ),
  GameMission(
    id: 'decapitation',
    title: '第三关 · 斩首行动',
    subtitle: '直取指挥中心',
    brief: '蓝军把重兵收拢在指挥中心周围，外围据点反而空虚。'
        '渗透部队需要绕过炮塔直取指挥中心，一旦得手敌军将全线动摇。',
    objective: MissionObjective.decapitate,
    difficulty: BattleDifficulty.hard,
    mapSeed: 20261121,
    bonusCredits: 2600,
    startingArmy: [
      UnitKind.rocket,
      UnitKind.rocket,
      UnitKind.heavyTank,
      UnitKind.lightTank,
    ],
    enemyArmy: [UnitKind.heavyTank, UnitKind.rifle, UnitKind.rifle],
    enemyBuildings: [BuildingKind.tower, BuildingKind.tower],
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
