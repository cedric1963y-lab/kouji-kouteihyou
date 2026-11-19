// ignore_for_file: use_build_context_synchronously
// App Store 用スクショをシミュレーターで撮るための入口（リリースには含まれない）
// flutter run -t lib/dev/sim_shots.dart --dart-define=SHOT=01
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../core/models.dart';
import '../core/store.dart';
import '../core/templates.dart';
import '../main.dart';
import '../services/purchases.dart';
import '../ui/export.dart';
import '../ui/free_check.dart';
import '../ui/pro.dart';
import '../ui/sheets.dart';

class _MemoryRepository extends Repository {
  _MemoryRepository() : super(Directory.systemTemp);
  @override
  Future<AppData> load() async => AppData();
  @override
  Future<void> save(AppData d) async {}
}

SiteTemplate _tpl(String id) => siteTemplates.firstWhere((t) => t.id == id);

/// どの画面を撮るか: Library/Application Support/shot.txt（simctl で書き込む）
Future<String> _readShot() async {
  final env = Platform.environment['SHOT'];
  if (env != null) return env;
  try {
    final dir = await getApplicationSupportDirectory();
    return (await File('${dir.path}/shot.txt').readAsString()).trim();
  } catch (_) {
    return const String.fromEnvironment('SHOT', defaultValue: '01');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final shot = await _readShot();
  debugPrint('KOUTEI_SHOT=$shot');
  final st = AppState(
    repository: _MemoryRepository(),
    now: () => DateTime(2026, 11, 19, 9),
  );
  await st.load();
  await st.grantPro(until: DateTime(2027, 12, 31));
  if (shot == '05') await st.updateProfile('〇〇塗装', 'TEL 000-0000-0000');
  final a = await st.createSite(
    _tpl('paint'),
    start: DateTime(2026, 11, 16),
    name: '駅前アパート 外壁塗装',
  );
  await st.rainDay(DateTime(2026, 11, 18), [a.id]);
  final b = await st.createSite(
    _tpl('interior'),
    start: DateTime(2026, 11, 25),
    name: '川沿いの家 内装',
  );
  await st.updateSite(b.id, (s) {
    s.tasks.firstWhere((t) => t.name == 'クロス・床').tentative = true;
    s.memo = '駐車場1台（家の前）・鍵はキーボックス';
  });
  await st.createSite(
    _tpl('exterior'),
    start: DateTime(2026, 11, 30),
    name: '公園通り 外構',
  );
  final s2 = st.site(b.id);
  await st.delayFrom(
    s2.id,
    s2.tasks.firstWhere((t) => t.name == '設備配管').id,
    1,
    ShiftReason.previousTrade,
  );

  // 07 は無料プランの Pro 案内を撮る
  if (shot == '07') await st.grantPro(until: DateTime(2000));
  final nav = GlobalKey<NavigatorState>();
  runApp(
    KouteiApp(state: st, purchases: FakePurchaseGateway(), navigatorKey: nav),
  );
  await Future<void>.delayed(const Duration(milliseconds: 1200));
  final ctx = nav.currentState!.overlay!.context;
  switch (shot) {
    case '02':
      openNewSite(ctx);
    case '03':
      openDaySheet(ctx, DateTime(2026, 11, 20));
    case '04':
      openFreeCheckFrom(ctx, DateTime(2026, 11, 26));
    case '05':
      nav.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const ExportScreen(initialRange: ExportRange.month),
        ),
      );
    case '07':
      // 審査用（サブスクのレビュー用スクショ）。ストアの一覧には使わない
      nav.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const ProScreen()),
      );
    case '06':
      final s = st.activeSites[1];
      openTaskSheet(
        ctx,
        s.id,
        task: s.tasks.firstWhere((t) => t.name == '下地・ボード'),
      );
  }
}
