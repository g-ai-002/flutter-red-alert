import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// 启动即进入沉浸式全屏：Android 游戏页与主菜单都不保留系统栏，其余平台无需设置。
Future<void> applyImmersiveWindow() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
}

/// 系统栏（状态栏与导航栏）样式：透明底色，图标深浅由背景亮度决定。
SystemUiOverlayStyle systemOverlayStyleFor(Color background) {
  final dark = background.computeLuminance() < 0.5;
  final iconBrightness = dark ? Brightness.light : Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: iconBrightness,
    // iOS 的语义与 Android 相反：状态栏底色深才配浅色图标。
    statusBarBrightness: dark ? Brightness.dark : Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: iconBrightness,
  );
}

/// 按当前主题的页面底色设置系统栏样式，随深浅色模式切换。
class SystemUiOverlay extends StatelessWidget {
  const SystemUiOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlayStyleFor(Theme.of(context).scaffoldBackgroundColor),
      child: child,
    );
  }
}
