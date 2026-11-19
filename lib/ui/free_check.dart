import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../core/days.dart';
import '../core/schedule.dart';
import '../core/store.dart';
import 'scope.dart';
import 'theme.dart';

void openFreeCheckFrom(BuildContext context, DateTime day) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => FreeCheckScreen(initial: day)),
  );
}

/// 「〇日から入れる？」にすぐ答える
class FreeCheckScreen extends StatefulWidget {
  const FreeCheckScreen({super.key, this.initial});
  final DateTime? initial;
  @override
  State<FreeCheckScreen> createState() => _FreeCheckScreenState();
}

class _FreeCheckScreenState extends State<FreeCheckScreen> {
  DateTime? asked;
  int needed = 3;

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    asked ??= dayOf(widget.initial ?? addDays(st.today, 1));
    final a = checkAvailability(st.activeSites, asked!, needed, st.cal);
    final strip = [for (var i = 0; i < 28; i++) addDays(st.today, i)];
    return Scaffold(
      appBar: AppBar(title: const Text('空き確認')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '「何日から入れる？」と聞かれたら',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 64,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [for (final d in strip) _dayChip(st, d)],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                '何日ぶん？',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              IconButton.filledTonal(
                onPressed: needed > 1 ? () => setState(() => needed--) : null,
                icon: const Icon(Icons.remove),
              ),
              SizedBox(
                width: 64,
                child: Text(
                  '$needed日',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton.filledTonal(
                onPressed: () => setState(() => needed++),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            color: a.askedIsFree
                ? const Color(0xFFE6F4EA)
                : const Color(0xFFFFF3E0),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        a.askedIsFree ? Icons.check_circle : Icons.info,
                        color: a.askedIsFree
                            ? const Color(0xFF2E9D5B)
                            : K.orange,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        a.askedIsFree ? '入れます' : 'その日は埋まってます',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  if (!a.askedIsFree && a.busyOnAsked.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '${md(asked!)}は ${a.busyOnAsked.map((s) => s.name).join('・')}',
                        style: const TextStyle(color: K.muted),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      a.replyText,
                      style: const TextStyle(fontSize: 16, height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '返事にほかの現場の名前は出しません',
                    style: TextStyle(color: K.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          icon: const Icon(Icons.copy),
                          label: const Text('返事をコピー'),
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            await Clipboard.setData(
                              ClipboardData(text: a.replyText),
                            );
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('コピーしました。LINEに貼り付けてください'),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.outlined(
                        tooltip: '送る',
                        icon: const Icon(Icons.ios_share),
                        onPressed: () => SharePlus.instance.share(
                          ShareParams(text: a.replyText),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('この先4週間', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _legend(),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [for (final d in strip) _cell(st, d)],
          ),
        ],
      ),
    );
  }

  Widget _dayChip(AppState st, DateTime d) {
    final sel = sameDay(d, asked!);
    final off = st.cal.offReason(d) != null;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => asked = d),
        child: Container(
          width: 52,
          decoration: BoxDecoration(
            color: sel ? K.green : (off ? K.off : Colors.white),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: sel ? K.green : K.grid),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${d.month}/${d.day}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: sel ? Colors.white : K.ink,
                ),
              ),
              Text(
                wd(d),
                style: TextStyle(
                  fontSize: 12,
                  color: sel
                      ? Colors.white
                      : (d.weekday == 7
                            ? K.sunday
                            : (d.weekday == 6 ? K.saturday : K.muted)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cell(AppState st, DateTime d) {
    final l = loadOn(st.activeSites, d, st.cal);
    Color bg;
    if (l.off != null) {
      bg = K.off;
    } else if (l.sites.isEmpty) {
      bg = const Color(0xFFE6F4EA);
    } else {
      bg = K
          .site(l.sites.first.colorIndex)
          .withValues(alpha: l.tentativeOnly ? 0.35 : 0.85);
    }
    final dark = l.sites.isNotEmpty && !l.tentativeOnly;
    return GestureDetector(
      onTap: () => setState(() => asked = d),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
          border: sameDay(d, asked!)
              ? Border.all(color: K.orange, width: 2)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${d.day}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: dark ? Colors.white : K.ink,
              ),
            ),
            Text(
              l.off != null
                  ? '休'
                  : (l.sites.isEmpty
                        ? '空'
                        : (l.tentativeOnly ? '仮' : '${l.sites.length}件')),
              style: TextStyle(
                fontSize: 10,
                color: dark ? Colors.white : K.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legend() => const Wrap(
    spacing: 12,
    children: [
      _Legend(Color(0xFFE6F4EA), '空き'),
      _Legend(K.off, '休み'),
      _Legend(Color(0xFF2F80C8), '現場あり'),
    ],
  );
}

class _Legend extends StatelessWidget {
  const _Legend(this.c, this.t);
  final Color c;
  final String t;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 4),
      Text(t, style: const TextStyle(fontSize: 12, color: K.muted)),
    ],
  );
}
