import 'dart:ui';

/// 阵营：赤军（玩家）与蓝军（敌军）。
enum Team {
  red('赤军', Color(0xFFC8382B)),
  blue('蓝军', Color(0xFF2F6FA8));

  const Team(this.label, this.color);
  final String label;
  final Color color;

  Team get opponent => this == Team.red ? Team.blue : Team.red;
}

/// 地形：影响通行与建造，矿石格可被采矿车采集。
enum TerrainKind {
  grass('草地'),
  dirt('泥地'),
  road('公路'),
  ore('矿石'),
  water('水域'),
  rock('岩石');

  const TerrainKind(this.label);
  final String label;
}

/// 护甲类型，决定不同武器造成的伤害倍率。
enum ArmorClass { infantry, vehicle, structure }

/// 生产分类：建筑在指挥中心排产，步兵在兵营、装甲在战车工厂。
enum ProductionCategory {
  structure('建筑'),
  infantry('步兵'),
  armor('装甲');

  const ProductionCategory(this.label);
  final String label;
}

/// 步兵单位类型。
enum UnitKind {
  rifle('步兵', '步', '廉价的步枪兵，适合早期占点与清理步兵'),
  rocket('火箭兵', '火', '携带反装甲火箭，对坦克与建筑效果显著'),
  harvester('采矿车', '矿', '自动往返矿区与精炼厂，为基地提供资金'),
  lightTank('轻型坦克', '轻', '机动灵活，压制步兵与轻型目标'),
  heavyTank('重型坦克', '重', '装甲厚重的主战坦克，攻坚核心');

  const UnitKind(this.label, this.icon, this.description);
  final String label;
  final String icon;
  final String description;
}

/// 建筑类型。
enum BuildingKind {
  hq('指挥中心', '指', '基地核心，建造建筑与训练采矿车的起点'),
  power('电厂', '电', '为基地提供电力，电力不足会拖慢生产'),
  refinery('矿石精炼厂', '炼', '接收采矿车卸矿，并作为后续科技的跳板'),
  barracks('兵营', '兵', '训练步兵与火箭兵'),
  factory('战车工厂', '厂', '生产采矿车与各型坦克'),
  tower('哨戒炮塔', '塔', '自动攻击射程内的敌军，守卫基地');

  const BuildingKind(this.label, this.icon, this.description);
  final String label;
  final String icon;
  final String description;
}

/// 单位参数。数值集中在这里，平衡调整只改这一处。
class UnitSpec {
  const UnitSpec({
    required this.kind,
    required this.cost,
    required this.maxHp,
    required this.speed,
    required this.buildSeconds,
    required this.category,
    this.attack = 0,
    this.range = 0,
    this.cooldown = 1,
    this.vsInfantry = 1,
    this.vsVehicle = 1,
    this.vsStructure = 1,
    this.requires,
    this.capacity = 0,
    this.armor = ArmorClass.infantry,
    this.radius = 0.3,
  });

  final UnitKind kind;
  final int cost;
  final int maxHp;

  /// 移动速度，单位：格/秒。
  final double speed;
  final double buildSeconds;
  final ProductionCategory category;
  final int attack;
  final double range;
  final double cooldown;
  final double vsInfantry;
  final double vsVehicle;
  final double vsStructure;
  final BuildingKind? requires;

  /// 采矿车载矿上限，非采矿车为 0。
  final int capacity;
  final ArmorClass armor;
  final double radius;

  String get name => kind.label;
  String get icon => kind.icon;
  String get description => kind.description;
  bool get isHarvester => kind == UnitKind.harvester;

  double multiplierAgainst(ArmorClass armor) => switch (armor) {
    ArmorClass.infantry => vsInfantry,
    ArmorClass.vehicle => vsVehicle,
    ArmorClass.structure => vsStructure,
  };
}

/// 建筑参数。
class BuildingSpec {
  const BuildingSpec({
    required this.kind,
    required this.cost,
    required this.maxHp,
    required this.power,
    required this.buildSeconds,
    required this.width,
    required this.height,
    this.requires,
    this.attack = 0,
    this.range = 0,
    this.cooldown = 1,
    this.vsInfantry = 1,
    this.vsVehicle = 1,
    this.vsStructure = 1,
    this.producesCategory,
  });

  final BuildingKind kind;
  final int cost;
  final int maxHp;

  /// 正数为发电，负数为耗电。
  final int power;
  final double buildSeconds;
  final int width;
  final int height;
  final BuildingKind? requires;
  final int attack;
  final double range;
  final double cooldown;
  final double vsInfantry;
  final double vsVehicle;
  final double vsStructure;

  /// 该建筑可排产的生产分类。
  final ProductionCategory? producesCategory;

  String get name => kind.label;
  String get icon => kind.icon;
  String get description => kind.description;
  ArmorClass get armor => ArmorClass.structure;

  bool get isProducer => producesCategory != null;
  bool get isDefense => attack > 0;

  double multiplierAgainst(ArmorClass armor) => switch (armor) {
    ArmorClass.infantry => vsInfantry,
    ArmorClass.vehicle => vsVehicle,
    ArmorClass.structure => vsStructure,
  };
}

/// 全部单位参数。
const Map<UnitKind, UnitSpec> unitSpecs = {
  UnitKind.rifle: UnitSpec(
    kind: UnitKind.rifle,
    cost: 200,
    maxHp: 130,
    speed: 2.5,
    buildSeconds: 6,
    category: ProductionCategory.infantry,
    attack: 15,
    range: 4.5,
    cooldown: 0.8,
    vsInfantry: 1,
    vsVehicle: 0.35,
    vsStructure: 0.25,
    requires: BuildingKind.barracks,
    radius: 0.28,
  ),
  UnitKind.rocket: UnitSpec(
    kind: UnitKind.rocket,
    cost: 350,
    maxHp: 110,
    speed: 2.2,
    buildSeconds: 9,
    category: ProductionCategory.infantry,
    attack: 38,
    range: 6,
    cooldown: 1.7,
    vsInfantry: 0.5,
    vsVehicle: 1,
    vsStructure: 0.9,
    requires: BuildingKind.barracks,
    radius: 0.28,
  ),
  UnitKind.harvester: UnitSpec(
    kind: UnitKind.harvester,
    cost: 1000,
    maxHp: 620,
    speed: 1.8,
    buildSeconds: 14,
    category: ProductionCategory.armor,
    requires: BuildingKind.hq,
    capacity: 600,
    armor: ArmorClass.vehicle,
    radius: 0.4,
  ),
  UnitKind.lightTank: UnitSpec(
    kind: UnitKind.lightTank,
    cost: 700,
    maxHp: 500,
    speed: 2.6,
    buildSeconds: 11,
    category: ProductionCategory.armor,
    attack: 32,
    range: 5.5,
    cooldown: 1.1,
    vsInfantry: 0.55,
    vsVehicle: 1,
    vsStructure: 0.8,
    requires: BuildingKind.factory,
    armor: ArmorClass.vehicle,
    radius: 0.42,
  ),
  UnitKind.heavyTank: UnitSpec(
    kind: UnitKind.heavyTank,
    cost: 1500,
    maxHp: 1150,
    speed: 1.45,
    buildSeconds: 20,
    category: ProductionCategory.armor,
    attack: 72,
    range: 6.5,
    cooldown: 1.9,
    vsInfantry: 0.6,
    vsVehicle: 1,
    vsStructure: 1.1,
    requires: BuildingKind.factory,
    armor: ArmorClass.vehicle,
    radius: 0.48,
  ),
};

/// 全部建筑参数。
const Map<BuildingKind, BuildingSpec> buildingSpecs = {
  BuildingKind.hq: BuildingSpec(
    kind: BuildingKind.hq,
    cost: 3000,
    maxHp: 2600,
    power: 30,
    buildSeconds: 40,
    width: 3,
    height: 3,
  ),
  BuildingKind.power: BuildingSpec(
    kind: BuildingKind.power,
    cost: 800,
    maxHp: 900,
    power: 120,
    buildSeconds: 14,
    width: 2,
    height: 2,
    requires: BuildingKind.hq,
  ),
  BuildingKind.refinery: BuildingSpec(
    kind: BuildingKind.refinery,
    cost: 2000,
    maxHp: 1500,
    power: -40,
    buildSeconds: 24,
    width: 3,
    height: 2,
    requires: BuildingKind.power,
  ),
  BuildingKind.barracks: BuildingSpec(
    kind: BuildingKind.barracks,
    cost: 500,
    maxHp: 750,
    power: -20,
    buildSeconds: 12,
    width: 2,
    height: 2,
    requires: BuildingKind.power,
    producesCategory: ProductionCategory.infantry,
  ),
  BuildingKind.factory: BuildingSpec(
    kind: BuildingKind.factory,
    cost: 1200,
    maxHp: 1300,
    power: -45,
    buildSeconds: 22,
    width: 3,
    height: 3,
    requires: BuildingKind.refinery,
    producesCategory: ProductionCategory.armor,
  ),
  BuildingKind.tower: BuildingSpec(
    kind: BuildingKind.tower,
    cost: 600,
    maxHp: 850,
    power: -15,
    buildSeconds: 10,
    width: 1,
    height: 1,
    requires: BuildingKind.barracks,
    attack: 30,
    range: 7,
    cooldown: 1.0,
    vsInfantry: 0.9,
    vsVehicle: 0.8,
    vsStructure: 0.2,
  ),
};

/// 生产建筑与分类的对应关系。
const Map<ProductionCategory, BuildingKind> producerForCategory = {
  ProductionCategory.structure: BuildingKind.hq,
  ProductionCategory.infantry: BuildingKind.barracks,
  ProductionCategory.armor: BuildingKind.factory,
};

/// 难度：影响经济、AI 出兵规模与初始资金。
enum BattleDifficulty {
  easy(
    label: '简单',
    description: '敌军出兵较少，资金充裕，适合熟悉操作',
    playerCredits: 7000,
    aiCredits: 4200,
    aiIncome: 0.85,
    waveSize: 4,
    waveSeconds: 46,
    aiBuildSpeed: 0.9,
  ),
  normal(
    label: '普通',
    description: '标准节奏，敌军会持续扩军并成波进攻',
    playerCredits: 6000,
    aiCredits: 5200,
    aiIncome: 1.0,
    waveSize: 6,
    waveSeconds: 38,
    aiBuildSpeed: 1.0,
  ),
  hard(
    label: '困难',
    description: '敌军经济更强、出兵更快，需要稳健运营',
    playerCredits: 6000,
    aiCredits: 7200,
    aiIncome: 1.25,
    waveSize: 8,
    waveSeconds: 30,
    aiBuildSpeed: 1.12,
  );

  const BattleDifficulty({
    required this.label,
    required this.description,
    required this.playerCredits,
    required this.aiCredits,
    required this.aiIncome,
    required this.waveSize,
    required this.waveSeconds,
    required this.aiBuildSpeed,
  });

  final String label;
  final String description;
  final int playerCredits;
  final int aiCredits;
  final double aiIncome;
  final int waveSize;
  final double waveSeconds;
  final double aiBuildSpeed;

  static BattleDifficulty byName(String? name) => values.firstWhere(
    (item) => item.name == name,
    orElse: () => BattleDifficulty.normal,
  );
}

/// 战斗结果。
enum BattleResult { victory, defeat }

/// 选中目标的简短描述，供 HUD 使用。
class SelectionInfo {
  const SelectionInfo({
    required this.name,
    required this.icon,
    required this.hp,
    required this.maxHp,
    required this.team,
    required this.isBuilding,
    required this.count,
  });

  final String name;
  final String icon;
  final int hp;
  final int maxHp;
  final Team team;
  final bool isBuilding;
  final int count;

  double get hpRatio => maxHp <= 0 ? 0 : hp / maxHp;
}
