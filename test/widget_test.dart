import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shokunin_koutei/core/schedule.dart';
import 'package:shokunin_koutei/ui/board.dart';
import 'package:shokunin_koutei/ui/export.dart';
import 'package:shokunin_koutei/ui/pro.dart';
import 'package:shokunin_koutei/services/purchases.dart';

import 'support/harness.dart';

void main() {
  setUpAll(loadFonts);

  testWidgets('＋現場 → 職種 の2タップで工程表ができる', (tester) async {
    final st = await openState();
    await pumpApp(tester, st);
    expect(find.textContaining('職種を選ぶだけ'), findsOneWidget);
    await tester.tap(find.text('現場'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('外壁塗装'));
    await tester.pumpAndSettle();
    expect(st.activeSites.length, 1);
    expect(st.activeSites.single.tasks.length, 11);
    // 次の作業日（11/20 金）から始まる
    expect(siteStart(st.activeSites.single, st.cal), DateTime(2026, 11, 20));
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('3つ目の現場は Pro の案内', (tester) async {
    final st = await openState();
    await st.createSite(tpl('paint'));
    await st.createSite(tpl('roof'));
    await pumpApp(tester, st);
    await tester.tap(find.text('現場'));
    await tester.pumpAndSettle();
    expect(find.byType(ProScreen), findsOneWidget);
    expect(find.text('無料では現場2つまでです'), findsOneWidget);
    expect(find.text('月額 ¥100（1週間無料）'), findsOneWidget);
    expect(find.text('年額 ¥1,000（1週間無料）'), findsOneWidget);
    await tester.tap(find.text('年額 ¥1,000（1週間無料）'));
    await tester.pumpAndSettle();
    expect(st.isPro, isTrue);
    expect(st.data.proUntil, testNow().add(const Duration(days: 366)));
  });

  testWidgets('日付をタップ → 雨で中止 で後ろがずれる', (tester) async {
    final st = await openState();
    final s = await st.createSite(tpl('paint'), start: DateTime(2026, 11, 16));
    final before = handoverDay(s, st.cal)!;
    await pumpApp(tester, st);
    // 2週間表示は 1列40px。表示の起点は今日の7日前（11/12）
    final header = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is HeaderPainter,
    );
    final topLeft = tester.getTopLeft(header);
    const col = 6; // 11/18（getTopLeft は横スクロール込みの位置）
    await tester.tapAt(topLeft + const Offset(col * 40.0 + 20, 30));
    await tester.pumpAndSettle();
    expect(find.text('11月18日（水）'), findsOneWidget);
    await tester.tap(find.text('雨で中止 → 後ろを1日ずらす'));
    await tester.pumpAndSettle();
    expect(find.text('1現場を1日ずらしました'), findsOneWidget);
    expect(
      handoverDay(st.site(s.id), st.cal),
      st.cal.forSite(st.site(s.id)).addWorkDays(before, 1),
    );
  });

  testWidgets('空き確認: 返事の文をコピーできる', (tester) async {
    final st = await openState();
    await st.createSite(tpl('water'), start: DateTime(2026, 11, 20));
    await pumpApp(tester, st);
    await tester.tap(find.byTooltip('空き確認'));
    await tester.pumpAndSettle();
    expect(find.text('その日は埋まってます'), findsOneWidget);
    expect(find.textContaining('別の現場が入っています'), findsOneWidget);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    await tester.tap(find.text('返事をコピー'));
    await tester.pump();
    expect(copied, contains('からなら3日間入れます'));
  });

  testWidgets('送る画面: 無料はアプリ名が入り、Pro は会社名が入る', (tester) async {
    final st = await openState();
    await st.createSite(tpl('paint'), name: '駅前アパート');
    await pumpApp(tester, st);
    await tester.tap(find.byTooltip('送る'));
    await tester.pumpAndSettle();
    expect(find.byType(ExportCard), findsOneWidget);
    expect(find.text('工事の工程表で作成'), findsOneWidget);
    await tester.tap(find.text('PDF'));
    await tester.pumpAndSettle();
    expect(find.text('PDFで送るのは Pro の機能です'), findsOneWidget);
  });

  testWidgets('Pro の書き出しは会社名入り・アプリ名なし', (tester) async {
    final st = await openState(pro: true);
    await st.updateProfile('〇〇塗装', '090-0000-0000');
    await st.createSite(tpl('paint'), name: '駅前アパート');
    await pumpApp(tester, st);
    await tester.tap(find.byTooltip('送る'));
    await tester.pumpAndSettle();
    expect(find.text('〇〇塗装'), findsOneWidget);
    expect(find.text('工事の工程表で作成'), findsNothing);
    await tester.tap(find.text('お客さん向け'));
    await tester.pumpAndSettle();
    expect(find.text('工事の予定'), findsOneWidget);
  });

  testWidgets('帯を長押しでドラッグ → 後ろもまとめてずれる', (tester) async {
    final st = await openState();
    final s = await st.createSite(tpl('water'), start: DateTime(2026, 11, 24));
    await pumpApp(tester, st);
    final body = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is BodyPainter,
    );
    final origin = tester.getTopLeft(body);
    // 行: 現場見出し30 → 着工(節目)34 → 解体・撤去34。11/24 は起点11/12から12列目
    final p = origin + const Offset(12 * 40 + 20, 30 + 34 + 17);
    final g = await tester.startGesture(p);
    await tester.pump(const Duration(milliseconds: 600));
    await g.moveBy(const Offset(40, 0));
    await tester.pump();
    await g.moveBy(const Offset(40, 0));
    await tester.pump();
    await g.up();
    await tester.pumpAndSettle();
    final c = st.cal.forSite(st.site(s.id));
    final t = st.site(s.id).tasks.firstWhere((t) => t.name == '解体・撤去');
    expect(c.snap(t.start), DateTime(2026, 11, 26));
    expect(find.textContaining('後ろを +2日 ずらしました'), findsOneWidget);
  });

  testWidgets('ストアに繋がらないときも価格は月¥100・年¥1,000', (tester) async {
    final st = await openState();
    await pumpApp(tester, st, purchases: _OfflineGateway());
    await tester.tap(find.byTooltip('設定'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('プラン'));
    await tester.pumpAndSettle();
    expect(find.text('月額 ¥100 ／ 年額 ¥1,000'), findsOneWidget);
  });
  testWidgets('Pro画面に無料お試し・自動更新の説明と規約リンクがある', (tester) async {
    final st = await openState();
    await pumpApp(tester, st);
    await tester.tap(find.byTooltip('設定'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('プラン'));
    await tester.pumpAndSettle();
    expect(find.text('月額 ¥100（1週間無料）'), findsOneWidget);
    expect(find.text('年額 ¥1,000（1週間無料）'), findsOneWidget);
    expect(find.textContaining('24時間前までに解約'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('利用規約（EULA）'), 100);
    expect(find.text('利用規約（EULA）'), findsOneWidget);
    expect(find.text('プライバシーポリシー'), findsOneWidget);
  });
}

class _OfflineGateway extends FakePurchaseGateway {
  @override
  Future<List<PlanProduct>> products() async => [];
}
