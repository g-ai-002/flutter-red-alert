import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/log_service.dart';
import '../services/sound_service.dart';
import '../utils/formatters.dart';
import 'ai_commander.dart';
import 'battle_camera.dart';
import 'battle_state.dart';
import 'battle_types.dart';
import 'entity.dart';
import 'logic_rate.dart';
import 'placement_state.dart';
import 'terrain.dart';

/// 一条浮动提示，带剩余显示时间。
class BattleToast {
  BattleToast(this.text, this.level) : remaining = 3.4;

  final String text;
  final NoticeLevel level;
  double remaining;
}

/// 玩家阵营固定为赤军。
const Team playerTeam = Team.red;

/// 对局控制器：把纯逻辑的 [BattleState] 包装成界面可用的状态，
/// 负责选择、指令、建造放置、提示与摄像机，并以约 6Hz 通知 HUD 重绘。
class BattleController extends ChangeNotifier {
  BattleController({
    required this.state,
    required this.logicRate,
    BattleCamera? cameraOverride,
  }) : camera =
           cameraOverride ??
           BattleCamera(
             mapWidth: state.map.width,
             mapHeight: state.map.height,
           ) {
    _ai = AiCommander(team: Team.blue, difficulty: state.difficulty);
    state.onAiTick = _ai.update;
    _placement = PlacementState(state: state, team: playerTeam);
    camera.focusOn(GameMap.redBase);
  }

  final BattleState state;
  final LogicRate logicRate;
  final BattleCamera camera;
  late final AiCommander _ai;
  late final PlacementState _placement;

  final Set<int> selectedIds = {};
  final List<BattleToast> toasts = [];

  bool paused = false;

  /// 游戏速度倍率，仅 1x 与 2x 两档。
  double speed = 1;

  double _notifyAccumulator = 0;
  bool _resultAnnounced = false;

  BattleDifficulty get difficulty => state.difficulty;
  BattleResult? get result => state.result;
  bool get isPlacing => _placement.active;

  /// 放置预览状态，供渲染层直接读取。
  PlacementState get placement => _placement;

  BuildingSpec? get placingSpec => _placement.spec;

  /// 当前放置位置（左上角格）。
  TilePoint? get ghostTile => _placement.tile;

  bool get ghostValid => _placement.valid;

  List<Unit> get selectedUnits =>
      state.selectableUnits(playerTeam, selectedIds);

  List<Actor> get selectedActors => selectedIds
      .map(state.actorById)
      .whereType<Actor>()
      .where((actor) => actor.alive)
      .toList();

  /// 当前选中的指挥官信息；多选时汇总生命值。
  SelectionInfo? get selection {
    final actors = selectedActors;
    if (actors.isEmpty) return null;
    if (actors.length == 1) {
      final actor = actors.first;
      return SelectionInfo(
        name: actor.displayName,
        icon: actor is Unit ? actor.spec.icon : (actor as Building).spec.icon,
        hp: actor.hp,
        maxHp: actor.maxHp,
        team: actor.team,
        isBuilding: actor.isBuilding,
        count: 1,
      );
    }
    final first = actors.first;
    final sameName = actors.every((a) => a.displayName == first.displayName);
    final hp = actors.fold<int>(0, (sum, a) => sum + a.hp);
    final maxHp = actors.fold<int>(0, (sum, a) => sum + a.maxHp);
    return SelectionInfo(
      name: sameName ? first.displayName : '混编部队',
      icon: sameName
          ? (first is Unit ? first.spec.icon : (first as Building).spec.icon)
          : '编',
      hp: hp,
      maxHp: maxHp,
      team: first.team,
      isBuilding: false,
      count: actors.length,
    );
  }

  bool get canCommandSelection =>
      selectedIds.isNotEmpty &&
      selectedActors.every((actor) => actor is Unit && actor.team == playerTeam);

  // ===== 主循环 =====

  void tick(double dt) {
    if (state.result == null && !paused) {
      state.update(dt * speed);
    }
    _drainNotices();
    _updateToasts(dt);

    if (state.result != null && !_resultAnnounced) {
      _resultAnnounced = true;
      SoundService.play(
        state.result == BattleResult.victory
            ? BattleFeedback.victory
            : BattleFeedback.defeat,
      );
      LogService.info(
        '对局结束: ${state.result == BattleResult.victory ? '胜利' : '失败'}, '
        '用时 ${state.elapsed.toStringAsFixed(0)} 秒',
      );
      notifyListeners();
      return;
    }

    _notifyAccumulator += dt;
    if (_notifyAccumulator >= 0.16) {
      _notifyAccumulator = 0;
      notifyListeners();
    }
  }

  void _drainNotices() {
    final notices = state.drainNotices();
    for (final notice in notices) {
      if (toasts.isNotEmpty &&
          toasts.last.text == notice.text &&
          toasts.last.level == notice.level) {
        toasts.last.remaining = 3.4;
        continue;
      }
      toasts.add(BattleToast(notice.text, notice.level));
      if (toasts.length > 3) toasts.removeAt(0);
    }
  }

  void _updateToasts(double dt) {
    if (toasts.isEmpty) return;
    for (final toast in toasts) {
      toast.remaining -= dt;
    }
    toasts.removeWhere((toast) => toast.remaining <= 0);
  }

  // ===== 交互 =====

  /// 单击/点按战场：选择、移动或攻击。
  void tap(Offset screenPosition, {bool additive = false}) {
    if (isPlacing) {
      // 点哪放哪：先把预览移动到落点，再尝试确认。
      updateGhost(screenPosition);
      _tryPlaceGhost();
      return;
    }

    final world = camera.screenToWorld(screenPosition);
    final hit = state.actorAt(world);
    final actor = hit != null && state.isVisibleToPlayer(hit) ? hit : null;

    if (actor != null && actor.team == playerTeam) {
      if (additive) {
        if (!selectedIds.add(actor.id)) selectedIds.remove(actor.id);
      } else {
        selectedIds
          ..clear()
          ..add(actor.id);
      }
      SoundService.play(BattleFeedback.select);
      notifyListeners();
      return;
    }

    if (actor != null && actor.team != playerTeam) {
      if (canCommandSelection) {
        state.issueAttack(selectedUnits, actor.id);
        SoundService.play(BattleFeedback.command);
        notifyListeners();
        return;
      }
      selectedIds
        ..clear()
        ..add(actor.id);
      SoundService.play(BattleFeedback.select);
      notifyListeners();
      return;
    }

    if (canCommandSelection) {
      state.issueMove(selectedUnits, world);
      SoundService.play(BattleFeedback.command);
      notifyListeners();
      return;
    }
    if (selectedIds.isNotEmpty) {
      selectedIds.clear();
      notifyListeners();
    }
  }

  /// 桌面右键：对目标直接下达指令，不改变选择。
  void contextCommand(Offset screenPosition) {
    if (!canCommandSelection) return;
    final world = camera.screenToWorld(screenPosition);
    final hit = state.actorAt(world);
    final actor = hit != null && state.isVisibleToPlayer(hit) ? hit : null;
    if (actor != null && actor.team != playerTeam) {
      state.issueAttack(selectedUnits, actor.id);
    } else {
      state.issueMove(selectedUnits, world);
    }
    SoundService.play(BattleFeedback.command);
    notifyListeners();
  }

  /// 框选：屏幕矩形内的己方单位。
  void selectRect(Rect screenRect, {bool additive = false}) {
    final a = camera.screenToWorld(screenRect.topLeft);
    final b = camera.screenToWorld(screenRect.bottomRight);
    final worldRect = Rect.fromPoints(a, b);
    if (!additive) selectedIds.clear();
    for (final unit in state.unitsOf(playerTeam)) {
      if (!unit.alive) continue;
      if (worldRect.contains(unit.position)) selectedIds.add(unit.id);
    }
    if (selectedIds.isNotEmpty) SoundService.play(BattleFeedback.select);
    notifyListeners();
  }

  /// 全选同类：单选时选中全部同型单位，否则选中全部战斗单位。
  void selectAllSameKind() {
    final actors = selectedActors;
    if (actors.isEmpty) return;
    final first = actors.first;
    selectedIds.clear();
    if (first is Unit && !first.isHarvester) {
      for (final unit in state.unitsOf(playerTeam)) {
        if (unit.spec.kind == first.spec.kind) selectedIds.add(unit.id);
      }
    } else if (first is Unit) {
      for (final unit in state.unitsOf(playerTeam)) {
        if (unit.isHarvester) selectedIds.add(unit.id);
      }
    } else {
      for (final unit in state.unitsOf(playerTeam)) {
        selectedIds.add(unit.id);
      }
    }
    SoundService.play(BattleFeedback.select);
    notifyListeners();
  }

  void stopSelected() {
    final units = selectedUnits;
    if (units.isEmpty) return;
    state.stopUnits(units);
    SoundService.play(BattleFeedback.command);
    notifyListeners();
  }

  void focusSelection() {
    final actors = selectedActors;
    if (actors.isEmpty) return;
    final center = actors
        .map((actor) => actor.position)
        .reduce((a, b) => a + b) /
        actors.length.toDouble();
    camera.focusOn(center);
    notifyListeners();
  }

  // ===== 建造放置 =====

  void beginPlacement(String id) {
    final kind = buildingKindFromId(id);
    if (kind == null) return;
    if (!state.readyStructuresOf(playerTeam).contains(kind)) return;
    selectedIds.clear();
    _placement.begin(kind, camera.center);
    notifyListeners();
  }

  void updateGhost(Offset screenPosition) {
    if (!isPlacing) return;
    _placement.moveTo(camera.screenToWorld(screenPosition));
    notifyListeners();
  }

  void cancelPlacement() {
    if (!isPlacing) return;
    _placement.cancel();
    notifyListeners();
  }

  /// 返回 true 表示成功放置并退出放置模式。
  bool _tryPlaceGhost() {
    final spec = placingSpec;
    if (spec == null) return false;
    if (!ghostValid) {
      SoundService.play(BattleFeedback.command);
      state.addNotice('此处无法建造，请靠近己方建筑', level: NoticeLevel.warning);
      _drainNotices();
      notifyListeners();
      return false;
    }
    final tile = ghostTile!;
    final building = _placement.commit();
    if (building == null) return false;
    SoundService.play(BattleFeedback.build);
    LogService.info('放置建筑: ${spec.kind.label} @(${tile.x},${tile.y})');
    notifyListeners();
    return true;
  }

  // ===== 视角与暂停 =====

  void focusWorld(Offset tile) {
    camera.focusOn(tile);
    notifyListeners();
  }

  void togglePause() {
    paused = !paused;
    notifyListeners();
  }

  void setPaused(bool value) {
    if (paused == value) return;
    paused = value;
    notifyListeners();
  }

  void cycleSpeed() {
    speed = speed >= 2 ? 1 : 2;
    notifyListeners();
  }

  /// 雷达扫描：指挥中心在线且冷却结束时短暂标定全部敌军。
  void triggerRadar() {
    if (!state.triggerRadar()) {
      state.addNotice(
        state.hasBuilding(playerTeam, BuildingKind.hq)
            ? '雷达冷却中，请稍后再扫描'
            : '指挥中心已被摧毁，雷达离线',
        level: NoticeLevel.warning,
      );
    } else {
      SoundService.play(BattleFeedback.command);
    }
    _drainNotices();
    notifyListeners();
  }

  /// 生产入口：开始生产或进入放置。
  void requestProduction(ProductionCategory category, String id) {
    if (category == ProductionCategory.structure) {
      final kind = buildingKindFromId(id);
      if (kind != null &&
          state.readyStructuresOf(playerTeam).contains(kind)) {
        beginPlacement(id);
        return;
      }
    }
    final started = state.startProduction(playerTeam, category, id);
    if (started) {
      SoundService.play(BattleFeedback.command);
      LogService.info('开始生产: ${state.nameOf(id)}');
    }
    _drainNotices();
    notifyListeners();
  }

  void cancelProduction(ProductionCategory category) {
    state.cancelProduction(playerTeam, category);
    notifyListeners();
  }

  @override
  void dispose() {
    state.onAiTick = null;
    super.dispose();
  }

  /// 对局用时，`mm:ss`。
  String get elapsedText => formatDuration(state.elapsed.round());

  /// 电力负载：已用/已发，未发电时视为 1。
  double get powerRatio {
    final used = state.powerUsed(playerTeam);
    final produced = state.powerProduced(playerTeam);
    if (produced <= 0) return used > 0 ? 1 : 0;
    return math.min(1, used / produced);
  }
}
