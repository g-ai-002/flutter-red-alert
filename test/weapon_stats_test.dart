import 'dart:ui';

import 'package:flutter_red_alert/game/battle_types.dart';
import 'package:flutter_red_alert/game/entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WeaponStats', () {
    test('单位按目标护甲取对应倍率', () {
      final rifle = unitSpecs[UnitKind.rifle]!;
      expect(rifle.multiplierAgainst(ArmorClass.infantry), 1);
      expect(rifle.multiplierAgainst(ArmorClass.vehicle), 0.35);
      expect(rifle.multiplierAgainst(ArmorClass.structure), 0.25);
      expect(rifle.firesShell, isFalse);
    });

    test('车辆与防御建筑使用炮弹，建筑没有溅射', () {
      expect(unitSpecs[UnitKind.heavyTank]!.firesShell, isTrue);
      expect(unitSpecs[UnitKind.artillery]!.splash, greaterThan(0));
      final tower = buildingSpecs[BuildingKind.tower]!;
      expect(tower.firesShell, isTrue);
      expect(tower.splash, 0);
      expect(tower.multiplierAgainst(ArmorClass.vehicle), 0.8);
    });
  });

  test('点到矩形的最短距离在框内为零', () {
    const rect = Rect.fromLTWH(2, 3, 4, 2);
    expect(distanceToRect(const Offset(4, 4), rect), 0);
    expect(distanceToRect(const Offset(1, 4), rect), 1);
    expect(distanceToRect(const Offset(2, 1), rect), 2);
    expect(distanceToRect(const Offset(0, 0), rect), closeTo(3.6055, 0.001));
  });
}
