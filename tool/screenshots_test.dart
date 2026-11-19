// スクショ作成: flutter test tool/screenshots_test.dart --update-goldens
// 出力: ../screenshots/*.png（1290x2796, 6.9インチ相当）
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shokunin_koutei/ui/board.dart';
import 'package:shokunin_koutei/ui/free_check.dart';
import 'package:shokunin_koutei/ui/sheets.dart';

import '../test/support/harness.dart';

Future<void> shot(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('../../screenshots/$name.png'));
}

void main() {
  setUpAll(loadFonts);

  testWidgets('01 工程表', (tester) async {
    final st = await openState(pro: true);
    await seedDemo(st);
    await pumpApp(tester, st);
    await shot(tester, '01-timeline');
  });

  testWidgets('02 現場を作る', (tester) async {
    final st = await openState(pro: true);
    await seedDemo(st);
    await pumpApp(tester, st);
    await tester.tap(find.text('現場'));
    await shot(tester, '02-new-site');
  });

  testWidgets('03 雨で中止', (tester) async {
    final st = await openState(pro: true);
    await seedDemo(st);
    await pumpApp(tester, st);
    final header = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is HeaderPainter);
    // 11/20(金) = 起点11/12から8列目
    await tester.tapAt(tester.getTopLeft(header) + const Offset(8 * 40 + 20, 30));
    await shot(tester, '03-rain');
  });

  testWidgets('04 空き確認', (tester) async {
    final st = await openState(pro: true);
    await seedDemo(st);
    await pumpApp(tester, st);
    openFreeCheckFrom(tester.element(find.byType(Scaffold).first),
        DateTime(2026, 11, 26));
    await shot(tester, '04-free-check');
  });

  testWidgets('05 送る', (tester) async {
    final st = await openState(pro: true);
    await st.updateProfile('〇〇塗装', 'TEL 000-0000-0000');
    await seedDemo(st);
    await pumpApp(tester, st);
    await tester.tap(find.byTooltip('送る'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1ヶ月'));
    await shot(tester, '05-export');
  });

  testWidgets('06 遅れた', (tester) async {
    final st = await openState(pro: true);
    await seedDemo(st);
    await pumpApp(tester, st, size: const Size(430, 932));
    final s = st.activeSites[1];
    final t = s.tasks.firstWhere((t) => t.name == '下地・ボード');
    // 直接シートを開く
    final ctx = tester.element(find.byType(Scaffold).first);
    // ignore: use_build_context_synchronously
    openTaskSheet(ctx, s.id, task: t);
    await shot(tester, '06-task');
  });
}
