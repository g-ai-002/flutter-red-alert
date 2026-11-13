import 'package:flame/game.dart';
import 'package:flutter/gestures.dart';
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
import '../utils/platform_info.dart';
import 'guide_page.dart';
import 'widgets/battle_dialogs.dart';
import 'widgets/battle_hud.dart';
import 'widgets/build_panel.dart';
import 'widgets/minimap.dart';

/// 战场页面：Flame 渲染战场，Flutter 负责手势与悬浮 HUD。
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
  Offset? _dragStart;
  Rect? _boxRect;
  double _scaleAnchor = 1;

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

  // ===== 键盘 =====

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

  // ===== 构建 =====

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
              Positioned.fill(child: IgnorePointer(child: GameWidget(game: _game))),
              Positioned.fill(child: _buildInputLayer()),
              if (_boxRect != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _SelectionBoxPainter(_boxRect!),
                    ),
                  ),
                ),
              Positioned.fill(
                child: SafeArea(
                  minimum: const EdgeInsets.all(6),
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) => _buildHud(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputLayer() {
    final desktop = isDesktopPlatform;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          _controller.camera.zoomAt(
            event.localPosition,
            event.scrollDelta.dy > 0 ? 0.88 : 1.14,
          );
        }
      },
      onPointerDown: (event) {
        if (event.buttons == kSecondaryMouseButton) {
          _controller.contextCommand(event.localPosition);
        }
      },
      child: MouseRegion(
        cursor: _controller.isPlacing
            ? SystemMouseCursors.precise
            : SystemMouseCursors.basic,
        onHover: (event) {
          if (_controller.isPlacing) {
            _controller.updateGhost(event.localPosition);
          }
        },
        child: desktop ? _buildDesktopGesture() : _buildTouchGesture(),
      ),
    );
  }

  Widget _buildDesktopGesture() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) => _controller.tap(details.localPosition),
      onPanStart: (details) {
        if (_controller.isPlacing) return;
        _dragStart = details.localPosition;
        if (_boxRect != null) setState(() => _boxRect = null);
      },
      onPanUpdate: (details) {
        if (_controller.isPlacing) {
          _controller.updateGhost(details.localPosition);
          return;
        }
        final start = _dragStart;
        if (start == null) return;
        if ((details.localPosition - start).distance < 8) return;
        setState(
          () => _boxRect = Rect.fromPoints(start, details.localPosition),
        );
      },
      onPanEnd: (_) {
        final rect = _boxRect;
        if (rect != null &&
            rect.width.abs() > 6 &&
            rect.height.abs() > 6) {
          _controller.selectRect(rect);
        }
        setState(() {
          _dragStart = null;
          _boxRect = null;
        });
      },
      onPanCancel: () {
        setState(() {
          _dragStart = null;
          _boxRect = null;
        });
      },
      child: const SizedBox.expand(),
    );
  }

  Widget _buildTouchGesture() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) => _controller.tap(details.localPosition),
      onScaleStart: (_) {
        _scaleAnchor = _controller.camera.tileSize;
      },
      onScaleUpdate: (details) {
        final camera = _controller.camera;
        if (_controller.isPlacing) {
          if (details.pointerCount <= 1) {
            _controller.updateGhost(details.localFocalPoint);
            return;
          }
          final target = _scaleAnchor * details.scale;
          camera.zoomAt(
            details.localFocalPoint,
            (target / camera.tileSize).clamp(0.75, 1.35),
          );
          camera.panByScreen(details.focalPointDelta);
          return;
        }
        if (details.pointerCount >= 2) {
          final target = _scaleAnchor * details.scale;
          camera.zoomAt(
            details.localFocalPoint,
            (target / camera.tileSize).clamp(0.75, 1.35),
          );
        }
        camera.panByScreen(details.focalPointDelta);
      },
    );
  }

  Widget _buildHud() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760 || constraints.maxHeight < 420;
        final bottomHeight = compact ? 124.0 : 150.0;
        return Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: BattleStatusBar(
                controller: _controller,
                onPause: _openPauseMenu,
                onMenu: _openPauseMenu,
              ),
            ),
            Positioned(
              top: 40,
              left: 0,
              right: 0,
              child: Center(
                child: ToastStack(controller: _controller),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectionStrip(controller: _controller),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: bottomHeight,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        BattleMinimap(
                          controller: _controller,
                          size: bottomHeight,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: BuildPanel(
                            controller: _controller,
                            compact: compact,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 鼠标框选矩形。
class _SelectionBoxPainter extends CustomPainter {
  _SelectionBoxPainter(this.rect);

  final Rect rect;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      rect,
      Paint()..color = const Color(0x33D9A94B),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xDDF2D27A);
    const dash = 6.0;
    const gap = 4.0;
    for (var x = rect.left; x < rect.right; x += dash + gap) {
      final end = (x + dash).clamp(rect.left, rect.right);
      canvas.drawLine(Offset(x, rect.top), Offset(end, rect.top), paint);
      canvas.drawLine(Offset(x, rect.bottom), Offset(end, rect.bottom), paint);
    }
    for (var y = rect.top; y < rect.bottom; y += dash + gap) {
      final end = (y + dash).clamp(rect.top, rect.bottom);
      canvas.drawLine(Offset(rect.left, y), Offset(rect.left, end), paint);
      canvas.drawLine(Offset(rect.right, y), Offset(rect.right, end), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SelectionBoxPainter oldDelegate) =>
      oldDelegate.rect != rect;
}
