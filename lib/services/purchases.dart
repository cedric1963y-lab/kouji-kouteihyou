import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';

import '../core/plan.dart';

class PlanProduct {
  PlanProduct(this.id, this.title, this.price, {this.trial = false});
  final String id;
  final String title;
  final String price;

  /// 無料お試し（導入オファー）の対象か
  final bool trial;
}

/// 課金の窓口。テストやスクショでは Fake を使う。
abstract class PurchaseGateway {
  Future<List<PlanProduct>> products();
  Future<void> buy(String id);
  Future<void> restore();

  /// 今の契約の期限（契約がない・確認できないときは null）
  Future<DateTime?> activeUntil();

  /// 購入・復元が成立した商品 ID
  Stream<String> get granted;
}

class StorePurchaseGateway implements PurchaseGateway {
  StorePurchaseGateway() {
    _sub = InAppPurchase.instance.purchaseStream.listen((list) async {
      for (final p in list) {
        if (p.status == PurchaseStatus.purchased ||
            p.status == PurchaseStatus.restored) {
          _granted.add(p.productID);
        }
        if (p.pendingCompletePurchase) {
          await InAppPurchase.instance.completePurchase(p);
        }
      }
    });
  }

  late final StreamSubscription<List<PurchaseDetails>> _sub;
  final _granted = StreamController<String>.broadcast();
  final _details = <String, ProductDetails>{};

  @override
  Stream<String> get granted => _granted.stream;

  @override
  Future<List<PlanProduct>> products() async {
    if (!await InAppPurchase.instance.isAvailable()) return [];
    final r = await InAppPurchase.instance.queryProductDetails(Plan.productIds);
    for (final d in r.productDetails) {
      _details[d.id] = d;
    }
    final out = <PlanProduct>[];
    for (final id in [Plan.monthlyId, Plan.yearlyId]) {
      final d = _details[id];
      if (d == null) continue;
      out.add(PlanProduct(d.id, d.title, d.price, trial: await _trial(id)));
    }
    return out;
  }

  Future<bool> _trial(String id) async {
    try {
      return await SK2Product.isIntroductoryOfferEligible(id);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<DateTime?> activeUntil() async {
    try {
      final list = await SK2Transaction.transactions();
      DateTime? best;
      for (final tr in list) {
        if (!Plan.productIds.contains(tr.productId)) continue;
        final raw = tr.expirationDate;
        final ms = raw == null ? null : int.tryParse(raw);
        final purchased = int.tryParse(tr.purchaseDate);
        final end = ms != null
            ? DateTime.fromMillisecondsSinceEpoch(ms)
            : Plan.periodEnd(
                tr.productId,
                purchased == null
                    ? DateTime.now()
                    : DateTime.fromMillisecondsSinceEpoch(purchased),
              );
        if (best == null || end.isAfter(best)) best = end;
      }
      return best;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> buy(String id) async {
    final d = _details[id];
    if (d == null) return;
    final param = PurchaseParam(productDetails: d);
    // 自動更新サブスクも in_app_purchase では buyNonConsumable で買う
    await InAppPurchase.instance.buyNonConsumable(purchaseParam: param);
  }

  @override
  Future<void> restore() => InAppPurchase.instance.restorePurchases();

  void dispose() => _sub.cancel();
}

class FakePurchaseGateway implements PurchaseGateway {
  final _granted = StreamController<String>.broadcast();
  @override
  Stream<String> get granted => _granted.stream;
  @override
  Future<List<PlanProduct>> products() async => [
    PlanProduct(Plan.monthlyId, '月額', Plan.monthlyFallback, trial: true),
    PlanProduct(Plan.yearlyId, '年額', Plan.yearlyFallback, trial: true),
  ];
  @override
  Future<void> buy(String id) async => _granted.add(id);
  @override
  Future<void> restore() async {}
  @override
  Future<DateTime?> activeUntil() async => null;
}
