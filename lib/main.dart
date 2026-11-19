import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:path_provider/path_provider.dart';

import 'app_info.dart';
import 'core/plan.dart';
import 'core/store.dart';
import 'services/purchases.dart';
import 'ui/scope.dart';
import 'ui/theme.dart';
import 'ui/timeline.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dir = await getApplicationSupportDirectory();
  final state = AppState(repository: Repository(dir));
  await state.load();
  final purchases = StorePurchaseGateway();
  // 購入・復元はどの画面からでも反映する
  purchases.granted.listen((id) => syncPro(state, purchases, id: id));
  runApp(KouteiApp(state: state, purchases: purchases));
  // 起動時に App Store の契約期限と合わせる（更新済みの契約を拾う）
  syncPro(state, purchases);
}

/// App Store の契約期限を端末の Pro 期限に反映する。
/// [id] があるのは購入・復元が今成立したとき。
Future<void> syncPro(
  AppState state,
  PurchaseGateway purchases, {
  String? id,
}) async {
  final until = await purchases.activeUntil();
  final now = state.now();
  if (until != null) {
    if (state.data.proUntil == null || until.isAfter(state.data.proUntil!)) {
      await state.grantPro(until: until);
    }
  } else if (id != null) {
    await state.grantPro(until: Plan.periodEnd(id, now));
  }
}

class KouteiApp extends StatelessWidget {
  const KouteiApp({super.key, required this.state, required this.purchases});
  final AppState state;
  final PurchaseGateway purchases;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      purchases: purchases,
      child: MaterialApp(
        title: appName,
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        locale: const Locale('ja'),
        supportedLocales: const [Locale('ja')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const TimelineScreen(),
      ),
    );
  }
}
