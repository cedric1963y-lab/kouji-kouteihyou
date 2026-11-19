import '../core/plan.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';

import '../app_info.dart';
import '../core/days.dart';
import 'pro.dart';
import 'scope.dart';
import 'theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  TextEditingController? company;
  TextEditingController? contact;

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final h = st.data.holidays;
    company ??= TextEditingController(text: st.data.profile.company);
    contact ??= TextEditingController(text: st.data.profile.contact);
    final archived = st.data.sites.where((s) => s.archived).toList();
    final extra = h.extraOff.map(parseDayKey).toList()..sort();
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: [
          const _Head('休みの日（帯の日数に数えない）'),
          SwitchListTile(
            title: const Text('日曜'),
            value: h.sunday,
            onChanged: (v) => st.updateHolidays((x) => x.sunday = v),
          ),
          SwitchListTile(
            title: const Text('土曜'),
            subtitle: const Text('現場ごとにも変えられます'),
            value: h.saturday,
            onChanged: (v) => st.updateHolidays((x) => x.saturday = v),
          ),
          SwitchListTile(
            title: const Text('祝日'),
            value: h.nationalHolidays,
            onChanged: (v) => st.updateHolidays((x) => x.nationalHolidays = v),
          ),
          SwitchListTile(
            title: const Text('お盆（8/13〜16）'),
            value: h.obon,
            onChanged: (v) => st.updateHolidays((x) => x.obon = v),
          ),
          SwitchListTile(
            title: const Text('年末年始（12/29〜1/3）'),
            value: h.newYear,
            onChanged: (v) => st.updateHolidays((x) => x.newYear = v),
          ),
          if (extra.isNotEmpty)
            ListTile(
              title: const Text('自分の休み'),
              subtitle: Text(extra.map(md).join('　')),
            ),
          const _Head('送る画像に入れる名前（Pro）'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                TextField(
                  controller: company,
                  enabled: st.isPro,
                  decoration: const InputDecoration(labelText: '屋号・会社名'),
                ),
                TextField(
                  controller: contact,
                  enabled: st.isPro,
                  decoration: const InputDecoration(labelText: '連絡先（電話など）'),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: st.isPro
                      ? FilledButton(
                          onPressed: () =>
                              st.updateProfile(company!.text, contact!.text),
                          child: const Text('保存'),
                        )
                      : OutlinedButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ProScreen(),
                            ),
                          ),
                          child: const Text('Pro について'),
                        ),
                ),
              ],
            ),
          ),
          if (archived.isNotEmpty) ...[
            const _Head('終わった現場'),
            for (final s in archived)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: K.site(s.colorIndex),
                  radius: 7,
                ),
                title: Text(s.name),
                trailing: TextButton(
                  onPressed: () async {
                    try {
                      await st.archiveSite(s.id, false);
                    } catch (_) {
                      if (context.mounted) {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const ProScreen(reason: '無料では現場2つまでです'),
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('戻す'),
                ),
              ),
          ],
          const _Head('このアプリについて'),
          ListTile(
            title: const Text('プラン'),
            trailing: Text(st.isPro ? 'Pro' : '無料'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProScreen()),
            ),
          ),
          ListTile(
            title: const Text('購入を復元'),
            onTap: () => AppScope.purchasesOf(context).restore(),
          ),
          ListTile(
            title: const Text('サポート'),
            onTap: () => launchUrl(
              Uri.parse(AppLinks.support),
              mode: LaunchMode.externalApplication,
            ),
          ),
          ListTile(
            title: const Text('プライバシーポリシー'),
            onTap: () => launchUrl(
              Uri.parse(AppLinks.privacy),
              mode: LaunchMode.externalApplication,
            ),
          ),
          ListTile(
            title: const Text('利用規約（EULA）'),
            onTap: () => launchUrl(
              Uri.parse(AppLinks.appleEula),
              mode: LaunchMode.externalApplication,
            ),
          ),
          const ListTile(
            title: Text(appName),
            subtitle: Text('データはこの端末の中だけに保存します。アカウント登録はありません。'),
          ),
        ],
      ),
    );
  }
}

class _Head extends StatelessWidget {
  const _Head(this.t);
  final String t;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
    child: Text(
      t,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        color: K.green,
        fontSize: 14,
      ),
    ),
  );
}
