import 'package:flutter/material.dart';
import 'package:flutter_red_alert/pages/home_page.dart';
import 'package:flutter_red_alert/providers/settings_provider.dart';
import 'package:flutter_red_alert/services/storage_service.dart';
import 'package:flutter_red_alert/utils/constants.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Widget> buildHome() async {
  SharedPreferences.setMockInitialValues({});
  StorageService.resetForTests();
  final storage = await StorageService.instance;
  return ChangeNotifierProvider(
    create: (_) => SettingsProvider(storage),
    child: const MaterialApp(home: HomePage()),
  );
}

void main() {
  testWidgets('主菜单展示标题、难度与开始按钮', (tester) async {
    await tester.pumpWidget(await buildHome());
    await tester.pumpAndSettle();
    expect(find.text('赤色黎明'), findsOneWidget);
    expect(find.text('开始战役'), findsOneWidget);
    expect(find.text('简单'), findsOneWidget);
    expect(find.text('普通'), findsOneWidget);
    expect(find.text('困难'), findsOneWidget);
    expect(find.textContaining('v${AppConstants.version}'), findsOneWidget);
  });

  testWidgets('主菜单在窄屏与宽屏下均不溢出', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(await buildHome());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.binding.setSurfaceSize(const Size(1280, 800));
    await tester.pumpWidget(await buildHome());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('开始战役'), findsOneWidget);
  });

  testWidgets('切换难度会保存偏好', (tester) async {
    await tester.pumpWidget(await buildHome());
    await tester.pumpAndSettle();
    await tester.tap(find.text('困难'));
    await tester.pumpAndSettle();
    final provider = tester.element(find.byType(HomePage)).read<SettingsProvider>();
    expect(provider.difficulty.label, '困难');
  });
}
