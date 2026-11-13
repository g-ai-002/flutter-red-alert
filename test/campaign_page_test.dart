import 'package:flutter/material.dart';
import 'package:flutter_red_alert/game/battle_types.dart';
import 'package:flutter_red_alert/game/mission.dart';
import 'package:flutter_red_alert/pages/battle_page.dart';
import 'package:flutter_red_alert/pages/campaign_page.dart';
import 'package:flutter_red_alert/providers/settings_provider.dart';
import 'package:flutter_red_alert/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Widget> buildShell(Widget home) async {
  SharedPreferences.setMockInitialValues({});
  StorageService.resetForTests();
  final storage = await StorageService.instance;
  return ChangeNotifierProvider(
    create: (_) => SettingsProvider(storage),
    child: MaterialApp(home: home),
  );
}

void main() {
  testWidgets('战役列表展示三关与解锁状态', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(await buildShell(const CampaignPage()));
    await tester.pumpAndSettle();

    expect(find.text('战役模式'), findsOneWidget);
    for (final mission in campaignMissions) {
      expect(find.text(mission.title), findsOneWidget);
    }
    expect(find.text('点击出击'), findsOneWidget);
    expect(find.text('通关上一关后解锁'), findsNWidgets(2));
    expect(find.text('已通关 0/3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('战役战场带迷雾与雷达按钮入场且不溢出', (tester) async {
    await tester.binding.setSurfaceSize(const Size(880, 420));
    await tester.pumpWidget(
      await buildShell(
        BattlePage(difficulty: campaignMissions.first.difficulty, mission: campaignMissions.first),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('雷达'), findsOneWidget);
    expect(find.text('资'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('遭遇战仍可单独开始', (tester) async {
    await tester.pumpWidget(await buildShell(const BattlePage(difficulty: BattleDifficulty.hard)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('开始战斗'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
