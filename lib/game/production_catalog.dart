import 'battle_types.dart';

/// 一条可生产项：把对外的 id、名称、图标、价格、工期与前置建筑统一成同一视图。
///
/// 建筑与单位的参数仍分别定义在 [buildingSpecs] / [unitSpecs]，这里只做索引，
/// 保证建造栏、生产校验、控制器与 AI 不再各自解析 id。
class ProductionItem {
  const ProductionItem({
    required this.id,
    required this.category,
    required this.name,
    required this.icon,
    required this.cost,
    required this.seconds,
    this.requires,
    this.building,
    this.unit,
  });

  final String id;
  final ProductionCategory category;
  final String name;
  final String icon;
  final int cost;
  final double seconds;
  final BuildingKind? requires;

  /// 建筑项对应的类型，单位项为 null。
  final BuildingKind? building;
  final UnitKind? unit;

  bool get isBuilding => building != null;
}

/// 生产项目录：唯一一份「能生产什么、按什么顺序展示」的定义。
class ProductionCatalog {
  ProductionCatalog._();

  static const List<String> _structureOrder = [
    'power',
    'refinery',
    'barracks',
    'factory',
    'tower',
    'hq',
  ];
  static const List<String> _infantryOrder = ['rifle', 'rocket'];
  static const List<String> _armorOrder = ['harvester', 'lightTank', 'heavyTank'];

  static final Map<String, ProductionItem> _byId = _build();

  /// 某一分类的生产项，顺序即建造栏展示顺序。
  static List<ProductionItem> of(ProductionCategory category) =>
      switch (category) {
        ProductionCategory.structure => _itemsOf(_structureOrder),
        ProductionCategory.infantry => _itemsOf(_infantryOrder),
        ProductionCategory.armor => _itemsOf(_armorOrder),
      };

  static ProductionItem? byId(String id) => _byId[id];

  /// 全部生产项，主要用于测试与遍历。
  static Iterable<ProductionItem> get all => _byId.values;

  static Map<String, ProductionItem> _build() {
    final items = <String, ProductionItem>{};
    for (final id in _structureOrder) {
      final kind = buildingKindFromId(id);
      if (kind == null) continue;
      final spec = buildingSpecs[kind]!;
      items[id] = ProductionItem(
        id: id,
        category: ProductionCategory.structure,
        name: spec.name,
        icon: spec.icon,
        cost: spec.cost,
        seconds: spec.buildSeconds,
        requires: spec.requires,
        building: kind,
      );
    }
    for (final order in [_infantryOrder, _armorOrder]) {
      for (final id in order) {
        final kind = unitKindFromId(id);
        if (kind == null) continue;
        final spec = unitSpecs[kind]!;
        items[id] = ProductionItem(
          id: id,
          category: spec.category,
          name: spec.name,
          icon: spec.icon,
          cost: spec.cost,
          seconds: spec.buildSeconds,
          requires: spec.requires,
          unit: kind,
        );
      }
    }
    return items;
  }

  static List<ProductionItem> _itemsOf(List<String> order) => [
    for (final id in order)
      if (_byId[id] != null) _byId[id]!,
  ];
}
