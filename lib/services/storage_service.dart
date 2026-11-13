import 'package:shared_preferences/shared_preferences.dart';

import '../game/battle_types.dart';
import '../game/logic_rate.dart';
import '../utils/constants.dart';

/// 单机战绩：胜场、负场与最快通关时间。
class BattleStats {
  const BattleStats({required this.wins, required this.losses, required this.bestSeconds});

  final int wins;
  final int losses;
  final int? bestSeconds;

  int get total => wins + losses;

  double get winRate => total == 0 ? 0 : wins / total;

  BattleStats record(BattleResult result, int seconds) {
    if (result == BattleResult.victory) {
      final best = bestSeconds;
      return BattleStats(
        wins: wins + 1,
        losses: losses,
        bestSeconds: best == null || seconds < best ? seconds : best,
      );
    }
    return BattleStats(wins: wins, losses: losses + 1, bestSeconds: bestSeconds);
  }
}

/// 轻量偏好存储：写入失败时静默忽略，不影响对局主流程。
class StorageService {
  static StorageService? _instance;
  SharedPreferences? _prefs;

  StorageService._();

  static Future<StorageService> get instance async {
    if (_instance != null) return _instance!;
    final service = StorageService._();
    service._prefs = await SharedPreferences.getInstance();
    _instance = service;
    return service;
  }

  /// 仅供测试：清空单例，配合 SharedPreferences 的 mock 数据使用。
  static void resetForTests() => _instance = null;

  SharedPreferences get _p {
    final prefs = _prefs;
    if (prefs == null) throw StateError('StorageService 尚未初始化');
    return prefs;
  }

  Future<void> _write(Future<bool> Function(SharedPreferences prefs) action) async {
    try {
      await action(_p);
    } catch (_) {}
  }

  /// 默认使用深色模式，战场氛围更统一。
  bool get darkMode => _p.getBool(AppConstants.prefKeyDarkMode) ?? true;
  Future<void> setDarkMode(bool value) =>
      _write((p) => p.setBool(AppConstants.prefKeyDarkMode, value));

  bool get soundEnabled => _p.getBool(AppConstants.prefKeySound) ?? true;
  Future<void> setSoundEnabled(bool value) =>
      _write((p) => p.setBool(AppConstants.prefKeySound, value));

  bool get musicEnabled => _p.getBool(AppConstants.prefKeyMusic) ?? true;
  Future<void> setMusicEnabled(bool value) =>
      _write((p) => p.setBool(AppConstants.prefKeyMusic, value));

  bool get hapticsEnabled => _p.getBool(AppConstants.prefKeyHaptics) ?? true;
  Future<void> setHapticsEnabled(bool value) =>
      _write((p) => p.setBool(AppConstants.prefKeyHaptics, value));

  LogicRate get logicRate => LogicRate.byName(_p.getString(AppConstants.prefKeyLogicRate));

  Future<void> setLogicRate(LogicRate value) =>
      _write((p) => p.setString(AppConstants.prefKeyLogicRate, value.name));

  BattleDifficulty get difficulty =>
      BattleDifficulty.byName(_p.getString(AppConstants.prefKeyDifficulty));

  Future<void> setDifficulty(BattleDifficulty value) =>
      _write((p) => p.setString(AppConstants.prefKeyDifficulty, value.name));

  BattleStats get stats => BattleStats(
    wins: _p.getInt(AppConstants.prefKeyWins) ?? 0,
    losses: _p.getInt(AppConstants.prefKeyLosses) ?? 0,
    bestSeconds: _p.getInt(AppConstants.prefKeyBestSeconds),
  );

  Future<void> recordResult(BattleResult result, int seconds) => _write((p) async {
    final next = stats.record(result, seconds);
    await p.setInt(AppConstants.prefKeyWins, next.wins);
    await p.setInt(AppConstants.prefKeyLosses, next.losses);
    final best = next.bestSeconds;
    if (best != null) {
      await p.setInt(AppConstants.prefKeyBestSeconds, best);
    }
    return true;
  });

  /// 已通关的战役关卡 id 集合。
  Set<String> get completedMissions =>
      (_p.getStringList(AppConstants.prefKeyCampaign) ?? const <String>[]).toSet();

  Future<void> completeMission(String missionId) => _write((p) async {
    final completed = completedMissions..add(missionId);
    await p.setStringList(AppConstants.prefKeyCampaign, completed.toList());
    return true;
  });
}
