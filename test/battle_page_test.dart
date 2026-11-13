import 'package:flutter/material.dart';
import 'package:flutter_red_alert/game/battle_types.dart';
import 'package:flutter_red_alert/pages/battle_page.dart';
import 'package:flutter_red_alert/providers/settings_provider.dart';
import 'package:flutter_red_alert/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Widget> buildBattle() async {
  SharedPreferences.setMockInitialValues({});
  StorageService.resetForTests();
  final storage = await StorageService.instance;
  return ChangeNotifierProvider(
    create: (_) => SettingsProvider(storage),
    child: const MaterialApp(
      home: BattlePage(difficulty: BattleDifficulty.normal),
    ),
  );
}

void main() {
  testWidgets('战场 HUD 在横屏手机尺寸下正常显示且不溢出', (tester) async {
    await tester.binding.setSurfaceSize(const Size(880, 420));
    await tester.pumpWidget(await buildBattle());
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('资'), findsOneWidget);
    expect(find.text('建筑'), findsOneWidget);
    expect(find.text('步兵'), findsOneWidget);
    expect(find.text('装甲'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('战场 HUD 在桌面窗口下正常显示', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    await tester.pumpWidget(await buildBattle());
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('资金'), findsOneWidget);
    expect(find.text('电力'), findsOneWidget);
    expect(find.text('部队'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
