import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shokunin_koutei/core/days.dart';
import 'package:shokunin_koutei/core/models.dart';
import 'package:shokunin_koutei/core/store.dart';
import 'package:shokunin_koutei/core/templates.dart';
import 'package:shokunin_koutei/main.dart';
import 'package:shokunin_koutei/services/purchases.dart';

/// 固定の時計: 2026/11/19(木) 9:00
DateTime testNow() => DateTime(2026, 11, 19, 9);

/// ウィジェットテストでは実ファイルを触らない
class MemoryRepository extends Repository {
  MemoryRepository() : super(Directory('/nonexistent'));
  String? saved;
  @override
  Future<AppData> load() async => AppData();
  @override
  Future<void> save(AppData d) async => saved = 'ok';
}

Future<AppState> openState({bool pro = false}) async {
  final st = AppState(repository: MemoryRepository(), now: testNow);
  await st.load();
  if (pro) await st.grantPro(until: DateTime(2027, 12, 31));
  return st;
}

bool _fonts = false;
Future<void> loadFonts() async {
  if (_fonts) return;
  _fonts = true;
  Future<ByteData> f(String p) async =>
      ByteData.sublistView(await File(p).readAsBytes());
  final jp = FontLoader('NotoSansJP')
    ..addFont(f('assets/fonts/NotoSansJP-Regular.ttf'))
    ..addFont(f('assets/fonts/NotoSansJP-Bold.ttf'));
  await jp.load();
  final flutterRoot =
      Platform.environment['FLUTTER_ROOT'] ?? '/home/box/flutter';
  final icons = FontLoader('MaterialIcons')
    ..addFont(
      f(
        '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      ),
    );
  await icons.load();
}

Future<void> pumpApp(
  WidgetTester tester,
  AppState st, {
  PurchaseGateway? purchases,
  Size size = const Size(430, 932),
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    KouteiApp(state: st, purchases: purchases ?? FakePurchaseGateway()),
  );
  await tester.pumpAndSettle();
}

SiteTemplate tpl(String id) => siteTemplates.firstWhere((t) => t.id == id);

/// スクショ用の見本データ（実在の名前は使わない）
Future<void> seedDemo(AppState st) async {
  final a = await st.createSite(
    tpl('paint'),
    start: DateTime(2026, 11, 16),
    name: '駅前アパート 外壁塗装',
  );
  await st.rainDay(DateTime(2026, 11, 18), [a.id]);
  final b = await st.createSite(
    tpl('interior'),
    start: DateTime(2026, 11, 25),
    name: '川沿いの家 内装',
  );
  await st.updateSite(b.id, (s) {
    s.tasks.firstWhere((t) => t.name == 'クロス・床').tentative = true;
    s.memo = '駐車場1台（家の前）・鍵はキーボックス';
  });
  await st.createSite(
    tpl('exterior'),
    start: DateTime(2026, 11, 30),
    name: '公園通り 外構',
  );
  final ids = [for (final s in st.data.sites) s.id];
  // 前の業者の遅れ（内装の配管が1日遅れ）
  final s2 = st.site(ids[1]);
  await st.delayFrom(
    s2.id,
    s2.tasks.firstWhere((t) => t.name == '設備配管').id,
    1,
    ShiftReason.previousTrade,
  );
}

String k(DateTime d) => dayKey(d);
