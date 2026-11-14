import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../game/battle_controller.dart';
import '../../theme/palette.dart';
import '../../utils/platform_info.dart';

/// 战场手势层：桌面框选 / 右键指令 / 滚轮缩放，触屏点选 / 拖拽 / 捏合。
///
/// 所有坐标直接交给 [BattleController] 换算，选中的虚线框也在这里绘制，
/// 战场页面只保留 HUD 与生命周期。
class BattleInputLayer extends StatefulWidget {
  const BattleInputLayer({super.key, required this.controller});

  final BattleController controller;

  @override
  State<BattleInputLayer> createState() => _BattleInputLayerState();
}

class _BattleInputLayerState extends State<BattleInputLayer> {
  Offset? _dragStart;
  Rect? _boxRect;
  double _scaleAnchor = 1;

  BattleController get _controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: _buildPointerListener()),
        if (_boxRect != null)
          Positioned.fill(
            child: IgnorePointer(child: CustomPaint(painter: _SelectionBoxPainter(_boxRect!))),
          ),
      ],
    );
  }

  Widget _buildPointerListener() {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          _controller.camera.zoomAt(event.localPosition, event.scrollDelta.dy > 0 ? 0.88 : 1.14);
        }
      },
      onPointerDown: (event) {
        if (event.buttons == kSecondaryMouseButton) {
          _controller.contextCommand(event.localPosition);
        }
      },
      child: MouseRegion(
        cursor: _controller.isPlacing ? SystemMouseCursors.precise : SystemMouseCursors.basic,
        onHover: (event) {
          if (_controller.isPlacing) {
            _controller.updateGhost(event.localPosition);
          }
        },
        child: isDesktopPlatform ? _buildDesktopGesture() : _buildTouchGesture(),
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
        setState(() => _boxRect = Rect.fromPoints(start, details.localPosition));
      },
      onPanEnd: (_) {
        final rect = _boxRect;
        if (rect != null && rect.width.abs() > 6 && rect.height.abs() > 6) {
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
          camera.zoomAt(details.localFocalPoint, (target / camera.tileSize).clamp(0.75, 1.35));
          camera.panByScreen(details.focalPointDelta);
          return;
        }
        if (details.pointerCount >= 2) {
          final target = _scaleAnchor * details.scale;
          camera.zoomAt(details.localFocalPoint, (target / camera.tileSize).clamp(0.75, 1.35));
        }
        camera.panByScreen(details.focalPointDelta);
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
    canvas.drawRect(rect, Paint()..color = hudGoldVeil);
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
  bool shouldRepaint(covariant _SelectionBoxPainter oldDelegate) => oldDelegate.rect != rect;
}
