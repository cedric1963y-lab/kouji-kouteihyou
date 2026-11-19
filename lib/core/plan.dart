/// 無料と Pro の線引き。価格は月¥100・年¥1,000のサブスク（2026-11-19決定）
abstract final class Plan {
  static const freeActiveSites = 2;
  static const monthlyId = 'jp.koutei.pro.monthly';
  static const yearlyId = 'jp.koutei.pro.yearly';
  static const productIds = {monthlyId, yearlyId};

  /// ストアに繋がらないときの表記（ASCで決めた価格と合わせる）
  static const monthlyFallback = '¥100';
  static const yearlyFallback = '¥1,000';
  static const fallbackText = '月額 $monthlyFallback ／ 年額 $yearlyFallback';

  /// はじめての方の無料お試し（ASCの導入オファー 1週間）
  static const trialLabel = '1週間無料';

  /// 確認できないときの期限（購入日からの目安）
  static DateTime periodEnd(String id, DateTime from) =>
      from.add(Duration(days: id == yearlyId ? 366 : 31));
}

abstract final class AppLinks {
  static const base = 'https://cedric1963y-lab.github.io/kouji-kouteihyou/';
  static const support = base;
  static const privacy = '${base}privacy.html';
  static const terms = '${base}terms.html';
  static const appleEula =
      'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';
  static const manageSubscriptions =
      'https://apps.apple.com/account/subscriptions';
}
