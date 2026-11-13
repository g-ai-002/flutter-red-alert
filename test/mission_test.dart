import 'package:flutter_red_alert/game/battle_state.dart';
import 'package:flutter_red_alert/game/battle_types.dart';
import 'package:flutter_red_alert/game/mission.dart';
import 'package:flutter_red_alert/providers/settings_provider.dart';
import 'package:flutter_red_alert/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('战役关卡 id 唯一且按顺序衔接', () {
    expect(
      campaignMissions.map((mission) => mission.id).toSet().length,
      campaignMissions.length,
    );
    expect(campaignMissions.first.objective, MissionObjective.eradicate);
    expect(campaignMissions.last.objective, MissionObjective.decapitate);
    expect(
      nextMissionOf(campaignMissions.first)?.id,
      campaignMissions[1].id,
    );
    expect(nextMissionOf(campaignMissions.last), isNull);
    expect(missionById('outpost')?.title, contains('前哨战'));
    expect(missionById('missing'), isNull);
  });

  test('战役开局按关卡配置生成地图、资金与初始部队', () {
    final mission = campaignMissions[1];
    final state = BattleState.create(mission: mission);

    expect(state.mission?.id, mission.id);
    expect(state.map.width, mission.mapSize);
    expect(state.creditsRed, mission.startingCredits);
    expect(state.redUnits.length, 2 + mission.startingArmy.length);
    expect(state.blueUnits.length, 2 + mission.enemyArmy.length);
    expect(
      state.blueBuildings.where(
        (building) => building.spec.kind == BuildingKind.tower,
      ),
      isNotEmpty,
    );
  });

  test('歼灭战摧毁指挥中心不会直接获胜', () {
    final state = BattleState.create(mission: campaignMissions.first);
    final hq = state.blueBuildings.firstWhere(
      (building) => building.spec.kind == BuildingKind.hq,
    );
    hq.applyDamage(hq.maxHp);
    state.update(0.016);

    expect(state.result, isNull);
    expect(state.blueBuildings, isNotEmpty);
  });

  test('斩首行动摧毁指挥中心立即获胜', () {
    final state = BattleState.create(mission: campaignMissions.last);
    final hq = state.blueBuildings.firstWhere(
      (building) => building.spec.kind == BuildingKind.hq,
    );
    hq.applyDamage(hq.maxHp);
    state.update(0.016);

    expect(state.result, BattleResult.victory);
  });

  test('战役通关进度持久化并按顺序解锁', () async {
    SharedPreferences.setMockInitialValues({});
    StorageService.resetForTests();
    final storage = await StorageService.instance;
    final settings = SettingsProvider(storage);

    expect(settings.isMissionUnlocked(campaignMissions[0]), isTrue);
    expect(settings.isMissionUnlocked(campaignMissions[1]), isFalse);

    await settings.completeMission(campaignMissions[0].id);
    expect(settings.isMissionCompleted(campaignMissions[0].id), isTrue);
    expect(settings.isMissionUnlocked(campaignMissions[1]), isTrue);
    expect(settings.isMissionUnlocked(campaignMissions[2]), isFalse);
    expect(storage.completedMissions, {campaignMissions[0].id});
  });
}
