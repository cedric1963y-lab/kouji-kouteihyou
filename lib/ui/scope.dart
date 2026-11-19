import 'package:flutter/widgets.dart';

import '../core/store.dart';
import '../services/purchases.dart';

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({
    super.key,
    required AppState state,
    required this.purchases,
    required super.child,
  }) : super(notifier: state);
  final PurchaseGateway purchases;

  static AppState of(BuildContext c) =>
      c.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
  static PurchaseGateway purchasesOf(BuildContext c) =>
      c.dependOnInheritedWidgetOfExactType<AppScope>()!.purchases;
}
