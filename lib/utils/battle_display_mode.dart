import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'system_ui.dart';

/// 战场是否值得横屏全屏：即时战略需要同时容纳战场、迷你地图与建造栏，
/// 手机等窄屏（短边 < 600）横屏能显著增加可用宽度，平板与桌面不改变方向。
bool shouldBattleLandscape(Size size) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
  final shortest = size.shortestSide;
  return shortest < 600;
}

/// 战场页显示模式：窄屏手机进入横屏并隐藏系统栏，离开后恢复。
class BattleDisplayMode extends StatefulWidget {
  const BattleDisplayMode({super.key, required this.child});

  final Widget child;

  @override
  State<BattleDisplayMode> createState() => _BattleDisplayModeState();
}

class _BattleDisplayModeState extends State<BattleDisplayMode> {
  bool _applied = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final wanted = shouldBattleLandscape(MediaQuery.sizeOf(context));
    if (wanted == _applied) return;
    _applied = wanted;
    if (wanted) {
      _enter();
    } else {
      _restore();
    }
  }

  Future<void> _enter() async {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _restore() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    applyImmersiveWindow();
  }

  @override
  void dispose() {
    if (_applied) _restore();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
