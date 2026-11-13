import 'package:flutter/material.dart';
import 'package:flutter_red_alert/game/battle_types.dart';
import 'package:flutter_red_alert/game/logic_rate.dart';
import 'package:flutter_red_alert/pages/settings_page.dart';
import 'package:flutter_red_alert/providers/settings_provider.dart';
import 'package:flutter_red_alert/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('设置页的单选组能切换逻辑刷新率与默认难度', (tester) async {
    SharedPreferences.setMockInitialValues({});
    StorageService.resetForTests();
    final storage = await StorageService.instance;
    final settings = SettingsProvider(storage);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(settings.logicRate, LogicRate.hz60);
    await tester.tap(find.text(LogicRate.hz30.label));
    await tester.pumpAndSettle();
    expect(settings.logicRate, LogicRate.hz30);

    final hard = find.widgetWithText(
      RadioListTile<BattleDifficulty>,
      BattleDifficulty.hard.label,
    );
    await tester.scrollUntilVisible(hard, 200);
    await tester.pumpAndSettle();
    await tester.tap(hard);
    await tester.pumpAndSettle();
    expect(settings.difficulty, BattleDifficulty.hard);
  });
}
