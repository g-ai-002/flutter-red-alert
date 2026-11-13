import 'package:flutter_red_alert/game/battle_types.dart';
import 'package:flutter_red_alert/game/logic_rate.dart';
import 'package:flutter_red_alert/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StorageService.resetForTests();
  });

  test('默认偏好符合设计', () async {
    final storage = await StorageService.instance;
    expect(storage.darkMode, isTrue);
    expect(storage.soundEnabled, isTrue);
    expect(storage.musicEnabled, isTrue);
    expect(storage.hapticsEnabled, isTrue);
    expect(storage.logicRate, LogicRate.hz60);
    expect(storage.difficulty, BattleDifficulty.normal);
    expect(storage.stats.wins, 0);
  });

  test('难度与刷新率可持久化', () async {
    final storage = await StorageService.instance;
    await storage.setDifficulty(BattleDifficulty.hard);
    await storage.setLogicRate(LogicRate.hz120);
    expect(storage.difficulty, BattleDifficulty.hard);
    expect(storage.logicRate, LogicRate.hz120);
  });

  test('战绩与最快通关时间', () async {
    final storage = await StorageService.instance;
    await storage.recordResult(BattleResult.victory, 420);
    await storage.recordResult(BattleResult.victory, 300);
    await storage.recordResult(BattleResult.defeat, 200);
    final stats = storage.stats;
    expect(stats.wins, 2);
    expect(stats.losses, 1);
    expect(stats.bestSeconds, 300);
    expect(stats.winRate, closeTo(2 / 3, 0.001));
  });
}
