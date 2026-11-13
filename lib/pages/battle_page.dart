import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../flame/battle_game.dart';
import '../game/battle_controller.dart';
import '../game/battle_state.dart';
import '../game/battle_types.dart';
import '../game/logic_rate.dart';
import '../providers/settings_provider.dart';
import '../services/log_service.dart';
import '../utils/battle_display_mode.dart';
import 'guide_page.dart';
import 'widgets/battle_dialogs.dart';
import 'widgets/battle_hud_layout.dart';
import 'widgets/battle_input_layer.dart';

/// 战场页面：组合 Flame 战场、手势层与悬浮 HUD，并管理对局生命周期。
class BattlePage extends StatefulWidget {
  const BattlePage({super.key, required this.difficulty});

  final BattleDifficulty difficulty;

  @override
  State<BattlePage> createState() => _BattlePageState();
}

class _BattlePageState extends State<BattlePage> with WidgetsBindingObserver {
  late final BattleState _state;
  late final BattleController _controller;
  late final BattleGame _game;
  late final LogicRate _logicRate;
  final FocusNode _focus = FocusNode(debugLabel: 'battle');

  bool _resultHandled = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _logicRate = settings.logicRate;
    _state = BattleState.create(difficulty: widget.difficulty);
    _controller = BattleController(state: _state, logicRate: _logicRate);
    _game = BattleGame(controller: _controller, logicRate: _logicRate);
    _controller.addListener(_onControllerChanged);
    WidgetsBinding.instance.addObserver(this);
    _state.addNotice('战役目标：摧毁蓝军全部建筑');
    LogService.info(
      '开始战斗: 难度 ${widget.difficulty.label}, 逻辑 ${_logicRate.label}, '
      '地图 ${_state.map.width}×${_state.map.height}',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _focus.dispose();
    LogService.info('离开战场页面');
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _controller.setPaused(true);
    }
  }

  void _onControllerChanged() {
    if (!mounted || _resultHandled) return;
    final result = _controller.result;
    if (result == null) return;
    _resultHandled = true;
    final seconds = _state.elapsed.round();
    context.read<SettingsProvider>().recordResult(result, seconds);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showBattleResultDialog(
        context,
        result: result,
        elapsed: _controller.elapsedText,
        difficulty: widget.difficulty.label,
        onRestart: _restartBattle,
        onHome: _goHome,
      );
    });
  }

  void _restartBattle() {
    final navigator = Navigator.of(context);
    navigator.popUntil((route) => route.isFirst);
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => BattlePage(difficulty: widget.difficulty),
      ),
    );
  }

  void _goHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _openGuide() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const GuidePage()),
    );
  }

  Future<void> _openPauseMenu() async {
    _controller.setPaused(true);
    await showPauseDialog(
      context,
      controller: _controller,
      onRestart: _restartBattle,
      onHome: _goHome,
      onGuide: () {
        Navigator.of(context).pop();
        _openGuide();
      },
    );
    if (mounted) _controller.setPaused(false);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      if (_controller.isPlacing) {
        _controller.cancelPlacement();
      } else if (!_controller.paused) {
        _openPauseMenu();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.space) {
      if (!_controller.paused) _openPauseMenu();
      return KeyEventResult.handled;
    }
    var dx = 0.0;
    var dy = 0.0;
    if (key == LogicalKeyboardKey.keyA || key == LogicalKeyboardKey.arrowLeft) {
      dx = -1;
    } else if (key == LogicalKeyboardKey.keyD ||
        key == LogicalKeyboardKey.arrowRight) {
      dx = 1;
    } else if (key == LogicalKeyboardKey.keyW ||
        key == LogicalKeyboardKey.arrowUp) {
      dy = -1;
    } else if (key == LogicalKeyboardKey.keyS ||
        key == LogicalKeyboardKey.arrowDown) {
      dy = 1;
    }
    if (dx == 0 && dy == 0) return KeyEventResult.ignored;
    _controller.camera.panByTiles(Offset(dx * 1.4, dy * 1.4));
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: BattleDisplayMode(
        child: Focus(
          focusNode: _focus,
          autofocus: true,
          onKeyEvent: _onKey,
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(child: GameWidget(game: _game)),
              ),
              Positioned.fill(
                child: BattleInputLayer(controller: _controller),
              ),
              Positioned.fill(
                child: SafeArea(
                  minimum: const EdgeInsets.all(6),
                  child: BattleHudLayout(
                    controller: _controller,
                    onPause: _openPauseMenu,
                    onMenu: _openPauseMenu,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
