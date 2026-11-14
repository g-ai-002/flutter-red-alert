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
import 'selection_state.dart';
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
  BattleController({required this.state, required this.logicRate, BattleCamera? cameraOverride})
    : camera =
          cameraOverride ?? BattleCamera(mapWidth: state.map.width, mapHeight: state.map.height) {
    _ai = AiCommander(team: Team.blue, difficulty: state.difficulty);
    state.onAiTick = _ai.update;
    _placement = PlacementState(state: state, team: playerTeam);
    _selection = SelectionState(state: state, team: playerTeam);
    camera.focusOn(GameMap.redBase);
  }

  final BattleState state;
  final LogicRate logicRate;
  final BattleCamera camera;
  late final AiCommander _ai;
  late final PlacementState _placement;
  late final SelectionState _selection;

  Set<int> get selectedIds => _selection.ids;
  final List<BattleToast> toasts = [];

  bool paused = false;

  double speed = 1;
  double _notifyAccumulator = 0;
  bool _resultAnnounced = false;
  bool _strikeAiming = false;
  Offset? _strikeTarget;

  /// 指令统一出口：按需播放反馈音，并通知 HUD 刷新。
  void _commit([BattleFeedback? feedback]) {
    if (feedback != null) SoundService.play(feedback);
    notifyListeners();
  }

  BattleResult? get result => state.result;
  BattleDifficulty get difficulty => state.difficulty;
  bool get isPlacing => _placement.active;

  /// 战略打击瞄准状态与当前落点，渲染层据此绘制杀伤范围。
  bool get strikeAiming => _strikeAiming;

  Offset? get strikeTarget => _strikeTarget;

  bool get strikeReady => state.strikeReady(playerTeam);

  double get strikeProgress => state.strikeProgress(playerTeam);

  PlacementState get placement => _placement;

  BuildingSpec? get placingSpec => _placement.spec;

  TilePoint? get ghostTile => _placement.tile;

  bool get ghostValid => _placement.valid;

  List<Unit> get selectedUnits => _selection.units;

  List<Actor> get selectedActors => _selection.actors;

  /// 当前选中的指挥官信息；多选时汇总生命值。
  SelectionInfo? get selection => _selection.summary;

  bool get canCommandSelection => _selection.canCommand;

  void tick(double dt) {
    if (state.result == null && !paused) {
      state.update(dt * speed);
    }
    _drainNotices();
    _updateToasts(dt);

    if (state.result != null && !_resultAnnounced) {
      _resultAnnounced = true;
      LogService.info(
        '对局结束: ${state.result == BattleResult.victory ? '胜利' : '失败'}, '
        '用时 ${state.elapsed.toStringAsFixed(0)} 秒',
      );
      _commit(
        state.result == BattleResult.victory ? BattleFeedback.victory : BattleFeedback.defeat,
      );
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

  /// 屏幕落点上的可见目标，迷雾中的敌军不参与选择与攻击。
  Actor? _visibleActorAt(Offset screenPosition) {
    final hit = state.actorAt(camera.screenToWorld(screenPosition));
    return hit != null && state.isVisibleToPlayer(hit) ? hit : null;
  }

  /// 单击/点按战场：选择、移动或攻击。
  void tap(Offset screenPosition, {bool additive = false}) {
    if (_strikeAiming) {
      updateStrikeAim(screenPosition);
      _tryLaunchStrike();
      return;
    }
    if (isPlacing) {
      // 点哪放哪：先把预览移动到落点，再尝试确认。
      updateGhost(screenPosition);
      _tryPlaceGhost();
      return;
    }

    final actor = _visibleActorAt(screenPosition);

    if (actor != null && actor.team != playerTeam && canCommandSelection) {
      state.issueAttack(selectedUnits, actor.id);
      _commit(BattleFeedback.command);
      return;
    }

    if (actor != null) {
      _selection.selectActor(actor, additive: additive);
      _commit(BattleFeedback.select);
      return;
    }

    if (canCommandSelection) {
      state.issueMove(selectedUnits, camera.screenToWorld(screenPosition));
      _commit(BattleFeedback.command);
      return;
    }
    if (selectedIds.isNotEmpty) {
      _selection.clear();
      notifyListeners();
    }
  }

  /// 桌面右键：对目标直接下达指令，不改变选择；瞄准时改为取消打击。
  void contextCommand(Offset screenPosition) {
    if (_strikeAiming) {
      cancelStrikeAim();
      return;
    }
    if (!canCommandSelection) return;
    final actor = _visibleActorAt(screenPosition);
    if (actor != null && actor.team != playerTeam) {
      state.issueAttack(selectedUnits, actor.id);
    } else {
      state.issueMove(selectedUnits, camera.screenToWorld(screenPosition));
    }
    _commit(BattleFeedback.command);
  }

  /// 框选：屏幕矩形内的己方单位。
  void selectRect(Rect screenRect, {bool additive = false}) {
    final a = camera.screenToWorld(screenRect.topLeft);
    final b = camera.screenToWorld(screenRect.bottomRight);
    _selection.selectRect(Rect.fromPoints(a, b), additive: additive);
    _commit(selectedIds.isEmpty ? null : BattleFeedback.select);
  }

  /// 全选同类：单选时选中全部同型单位，否则选中全部战斗单位。
  void selectAllSameKind() {
    if (selectedActors.isEmpty) return;
    _selection.selectAllSameKind();
    _commit(BattleFeedback.select);
  }

  void stopSelected() {
    final units = selectedUnits;
    if (units.isEmpty) return;
    state.stopUnits(units);
    _commit(BattleFeedback.command);
  }

  void focusSelection() {
    final actors = selectedActors;
    if (actors.isEmpty) return;
    final center =
        actors.map((actor) => actor.position).reduce((a, b) => a + b) / actors.length.toDouble();
    camera.focusOn(center);
    _commit();
  }

  void beginPlacement(String id) {
    final kind = buildingKindFromId(id);
    if (kind == null || !state.hasReadyStructure(playerTeam, kind)) return;
    _strikeAiming = false;
    selectedIds.clear();
    _placement.begin(kind, camera.center);
    _commit();
  }

  void updateGhost(Offset screenPosition) {
    if (!isPlacing) return;
    final wasValid = ghostValid;
    _placement.moveTo(camera.screenToWorld(screenPosition));
    // 预览框由渲染层逐帧读取，只有落点合法性变化才需要刷新 HUD，
    // 否则鼠标每次移动都会重建整块悬浮界面。
    if (ghostValid != wasValid) notifyListeners();
  }

  void cancelPlacement() {
    if (!isPlacing) return;
    _placement.cancel();
    _commit();
  }

  /// 返回 true 表示成功放置并退出放置模式。
  bool _tryPlaceGhost() {
    final spec = placingSpec;
    if (spec == null) return false;
    if (!ghostValid) {
      state.addNotice('此处无法建造，请靠近己方建筑', level: NoticeLevel.warning);
      _drainNotices();
      _commit(BattleFeedback.command);
      return false;
    }
    final tile = ghostTile!;
    final building = _placement.commit();
    if (building == null) return false;
    LogService.info('放置建筑: ${spec.kind.label} @(${tile.x},${tile.y})');
    _commit(BattleFeedback.build);
    return true;
  }

  void focusWorld(Offset tile) {
    camera.focusOn(tile);
    _commit();
  }

  void togglePause() {
    paused = !paused;
    _commit();
  }

  void setPaused(bool value) {
    if (paused == value) return;
    paused = value;
    _commit();
  }

  void cycleSpeed() {
    speed = speed >= 2 ? 1 : 2;
    _commit();
  }

  /// 雷达扫描：指挥中心在线且冷却结束时短暂标定全部敌军。
  void triggerRadar() {
    final scanned = state.triggerRadar();
    if (!scanned) {
      state.addNotice(
        state.hasBuilding(playerTeam, BuildingKind.hq) ? '雷达冷却中，请稍后再扫描' : '指挥中心已被摧毁，雷达离线',
        level: NoticeLevel.warning,
      );
    }
    _drainNotices();
    _commit(scanned ? BattleFeedback.command : null);
  }

  /// 进入或退出战略打击瞄准；发射井未就绪时给出原因。
  void toggleStrikeAiming() {
    if (_strikeAiming) {
      cancelStrikeAim();
      return;
    }
    if (!strikeReady) {
      state.addNotice(
        state.hasBuilding(playerTeam, BuildingKind.silo) ? '导弹发射井仍在蓄能' : '需要先建造导弹发射井',
        level: NoticeLevel.warning,
      );
      _drainNotices();
      _commit();
      return;
    }
    _placement.cancel();
    selectedIds.clear();
    _strikeAiming = true;
    _strikeTarget = camera.center;
    _commit(BattleFeedback.command);
  }

  /// 瞄准落点跟随鼠标 / 手指，渲染层逐帧读取，不需要刷新 HUD。
  void updateStrikeAim(Offset screenPosition) {
    if (!_strikeAiming) return;
    final world = camera.screenToWorld(screenPosition);
    _strikeTarget = Offset(
      world.dx.clamp(0, state.map.width.toDouble()),
      world.dy.clamp(0, state.map.height.toDouble()),
    );
  }

  void cancelStrikeAim() {
    if (!_strikeAiming) return;
    _strikeAiming = false;
    _commit();
  }

  bool _tryLaunchStrike() {
    final target = _strikeTarget;
    if (target == null || !state.launchStrike(playerTeam, target)) return false;
    _strikeAiming = false;
    LogService.info('战略打击: (${target.dx.toStringAsFixed(1)}, ${target.dy.toStringAsFixed(1)})');
    _commit(BattleFeedback.explosion);
    return true;
  }

  /// 生产入口：开始生产或进入放置。
  void requestProduction(ProductionCategory category, String id) {
    if (category == ProductionCategory.structure) {
      final kind = buildingKindFromId(id);
      if (kind != null && state.hasReadyStructure(playerTeam, kind)) {
        beginPlacement(id);
        return;
      }
    }
    final started = state.startProduction(playerTeam, category, id);
    if (started) LogService.info('开始生产: ${state.nameOf(id)}');
    _drainNotices();
    _commit(started ? BattleFeedback.command : null);
  }

  void cancelProduction(ProductionCategory category) {
    state.cancelProduction(playerTeam, category);
    _commit();
  }

  @override
  void dispose() {
    state.onAiTick = null;
    super.dispose();
  }

  /// 对局用时，`mm:ss`。
  String get elapsedText => formatDuration(state.elapsed.round());
}
