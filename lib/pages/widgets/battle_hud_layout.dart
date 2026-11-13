import 'package:flutter/material.dart';

import '../../game/battle_controller.dart';
import 'battle_hud.dart';
import 'build_panel.dart';
import 'hud_status_bar.dart';
import 'minimap.dart';

/// 战场悬浮 HUD：顶部状态栏与提示、底部选中信息、迷你地图与建造栏。
///
/// 只负责排版与自适应，不持有对局状态；数据变化由 [AnimatedBuilder] 驱动。
class BattleHudLayout extends StatelessWidget {
  const BattleHudLayout({
    super.key,
    required this.controller,
    required this.onPause,
    required this.onMenu,
  });

  final BattleController controller;
  final VoidCallback onPause;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxWidth < 760 || constraints.maxHeight < 420;
          final bottomHeight = compact ? 124.0 : 150.0;
          return Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: BattleStatusBar(
                  controller: controller,
                  onPause: onPause,
                  onMenu: onMenu,
                ),
              ),
              Positioned(
                top: 40,
                left: 0,
                right: 0,
                child: Center(child: ToastStack(controller: controller)),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectionStrip(controller: controller),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: bottomHeight,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          BattleMinimap(
                            controller: controller,
                            size: bottomHeight,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: BuildPanel(
                              controller: controller,
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
      ),
    );
  }
}
