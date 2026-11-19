import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/plan.dart';
import '../services/purchases.dart';
import 'scope.dart';
import 'theme.dart';

/// Pro の案内（価格は仮。ASC で決めた値をストアから読む）
class ProScreen extends StatefulWidget {
  const ProScreen({super.key, this.reason});
  final String? reason;
  @override
  State<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends State<ProScreen> {
  List<PlanProduct>? products;
  StreamSubscription<String>? sub;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (products != null) return;
    final g = AppScope.purchasesOf(context);
    final st = AppScope.of(context);
    g.products().then((p) {
      if (mounted) setState(() => products = p);
    });
    sub ??= g.granted.listen((id) async {
      final until = await g.activeUntil() ?? Plan.periodEnd(id, st.now());
      if (st.data.proUntil == null || until.isAfter(st.data.proUntil!)) {
        await st.grantPro(until: until);
      }
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  void dispose() {
    sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = AppScope.purchasesOf(context);
    final st = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Pro')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (widget.reason != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                widget.reason!,
                style: const TextStyle(
                  color: K.orange,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          const Text(
            '元請さん・お客さんに出す工程表を、自分の名前で',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          for (final (i, t) in const [
            (Icons.all_inclusive, '現場の数の上限なし（無料は同時に2現場まで）'),
            (Icons.badge_outlined, '送る画像に会社名・連絡先を入れる'),
            (Icons.hide_image_outlined, '画像のすみの「アプリ名」表示を消す'),
            (Icons.picture_as_pdf_outlined, 'A4横のPDFで送る'),
          ])
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(i, color: K.green),
              title: Text(t),
            ),
          const SizedBox(height: 12),
          if (st.isPro)
            const Text(
              'Pro をご利用中です',
              style: TextStyle(fontWeight: FontWeight.w700),
            )
          else if (products == null)
            const Center(child: CircularProgressIndicator())
          else if (products!.isEmpty)
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Plan.fallbackText,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 4),
                Text('今はストアに接続できません。時間をおいてお試しください。'),
              ],
            )
          else
            for (final p in products!)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FilledButton(
                  onPressed: () => g.buy(p.id),
                  child: Text(
                    p.trial
                        ? '${_label(p.id)} ${p.price}（${Plan.trialLabel}）'
                        : '${_label(p.id)} ${p.price}',
                  ),
                ),
              ),
          const Text(
            '月額 ¥100 または 年額 ¥1,000（税込）の自動更新サブスクです。'
            'はじめての方は1週間無料で、お試しが終わると選んだプランで課金されます。'
            '期間が終わる24時間前までに解約しないと自動で更新されます。'
            '解約は App Store の設定（サブスクリプション）からいつでもできます。',
            style: TextStyle(color: K.muted, fontSize: 12),
          ),
          TextButton(onPressed: () => g.restore(), child: const Text('購入を復元')),
          Wrap(
            spacing: 4,
            children: [
              TextButton(
                onPressed: () => _open(AppLinks.appleEula),
                child: const Text('利用規約（EULA）'),
              ),
              TextButton(
                onPressed: () => _open(AppLinks.privacy),
                child: const Text('プライバシーポリシー'),
              ),
              TextButton(
                onPressed: () => _open(AppLinks.manageSubscriptions),
                child: const Text('サブスクの管理'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '人・人工・お金は扱いません。工程表のデータはこの端末の中だけに保存されます。',
            style: TextStyle(color: K.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

String _label(String id) => id == Plan.yearlyId ? '年額' : '月額';

Future<void> _open(String url) async {
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}
