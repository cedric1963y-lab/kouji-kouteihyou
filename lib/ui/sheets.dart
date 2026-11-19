import 'package:flutter/material.dart';

import '../core/days.dart';
import '../core/models.dart';
import '../core/schedule.dart';
import '../core/store.dart';
import '../core/templates.dart';
import 'export.dart';
import 'free_check.dart';
import 'scope.dart';
import 'theme.dart';
import 'timeline.dart';

Future<T?> _sheet<T>(BuildContext context, Widget child) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (c) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
        child: child,
      ),
    );

IconData templateIcon(String id) => switch (id) {
  'paint' => Icons.format_paint,
  'roof' => Icons.roofing,
  'interior' => Icons.chair_outlined,
  'water' => Icons.shower_outlined,
  'exterior' => Icons.fence,
  'carpenter' => Icons.carpenter,
  _ => Icons.edit_note,
};

IconData reasonIcon(ShiftReason r) => switch (r) {
  ShiftReason.rain => Icons.umbrella,
  ShiftReason.previousTrade => Icons.hourglass_bottom,
  ShiftReason.material => Icons.inventory_2_outlined,
  ShiftReason.client => Icons.house_outlined,
  ShiftReason.other => Icons.more_horiz,
};

Widget _title(String s, {String? sub}) => Padding(
  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        s,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      ),
      if (sub != null)
        Text(sub, style: const TextStyle(color: K.muted, fontSize: 13)),
    ],
  ),
);

// ───────────────────────── 現場を作る（＋ → 職種 の2タップ）

Future<void> openNewSite(BuildContext context) async {
  final st = AppScope.of(context);
  if (!st.canAddSite) return showLimit(context);
  await _sheet(context, const _NewSiteSheet());
}

class _NewSiteSheet extends StatefulWidget {
  const _NewSiteSheet();
  @override
  State<_NewSiteSheet> createState() => _NewSiteSheetState();
}

class _NewSiteSheetState extends State<_NewSiteSheet> {
  final name = TextEditingController();
  late DateTime start;
  bool _init = false;

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final cal = st.cal;
    final tomorrow = cal.snap(addDays(st.today, 1));
    var monday = addDays(st.today, 1);
    while (monday.weekday != DateTime.monday) {
      monday = addDays(monday, 1);
    }
    monday = cal.snap(monday);
    if (!_init) {
      start = tomorrow;
      _init = true;
    }
    Future<void> create(SiteTemplate t) async {
      final nav = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      await guardLimit(context, () async {
        final s = await st.createSite(t, start: start, name: name.text);
        nav.pop();
        messenger.showSnackBar(
          SnackBar(
            content: Text('「${s.name}」を作りました。帯をタップで日数を直せます'),
            action: SnackBarAction(label: '元に戻す', onPressed: st.undo),
          ),
        );
      });
    }

    final others = st.data.sites;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('現場を作る', sub: '職種をタップすると、工程がまとめて入ります'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final d in {tomorrow, monday})
                  ChoiceChip(
                    label: Text(
                      '${sameDay(d, tomorrow) ? '次の作業日' : '来週の月曜'} ${md(d)}',
                    ),
                    selected: sameDay(start, d),
                    onSelected: (_) => setState(() => start = d),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.calendar_month, size: 18),
                  label: Text(
                    sameDay(start, tomorrow) || sameDay(start, monday)
                        ? '日付を選ぶ'
                        : '${md(start)}から',
                  ),
                  onPressed: () async {
                    final p = await pickDay(context, start);
                    if (p != null) setState(() => start = cal.snap(p));
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.25,
              children: [
                for (final t in siteTemplates)
                  _TemplateButton(t, onTap: () => create(t)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: TextField(
              controller: name,
              decoration: const InputDecoration(
                labelText: '現場の名前（あとでもOK）',
                hintText: '例: 駅前のアパート 外壁',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          if (others.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text(
                '前の現場をコピー',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in others.reversed.take(6))
                    ActionChip(
                      avatar: CircleAvatar(
                        backgroundColor: K.site(s.colorIndex),
                        radius: 6,
                      ),
                      label: Text(s.name),
                      onPressed: () async {
                        final nav = Navigator.of(context);
                        await guardLimit(context, () async {
                          await st.duplicateSite(s.id, start);
                          nav.pop();
                        });
                      },
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TemplateButton extends StatelessWidget {
  const _TemplateButton(this.t, {required this.onTap});
  final SiteTemplate t;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final work = t.steps.where((s) => s.milestone == null);
    final days = work.fold<int>(0, (a, s) => a + s.days);
    return Material(
      color: K.paper,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(templateIcon(t.id), color: K.green, size: 28),
              const SizedBox(height: 4),
              Text(
                t.label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              if (t.id != 'blank')
                Text(
                  '約$days日',
                  style: const TextStyle(color: K.muted, fontSize: 11),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<DateTime?> pickDay(BuildContext context, DateTime initial) {
  final st = AppScope.of(context);
  return showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: addDays(st.today, -365),
    lastDate: addDays(st.today, 730),
    locale: const Locale('ja'),
  );
}

// ───────────────────────── 工程を足す・直す

Future<void> openTaskSheet(
  BuildContext context,
  String siteId, {
  Task? task,
  DateTime? start,
}) async {
  await _sheet(context, _TaskSheet(siteId: siteId, task: task, start: start));
}

class _TaskSheet extends StatefulWidget {
  const _TaskSheet({required this.siteId, this.task, this.start});
  final String siteId;
  final Task? task;
  final DateTime? start;
  @override
  State<_TaskSheet> createState() => _TaskSheetState();
}

class _TaskSheetState extends State<_TaskSheet> {
  Task? t;
  final name = TextEditingController();
  final note = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final site = st.site(widget.siteId);
    final c = st.cal.forSite(site);
    t ??= () {
      final x =
          widget.task?.copy() ??
          Task(
            id: st.newId(),
            name: '',
            start: c.snap(widget.start ?? st.today),
            workDays: 2,
          );
      name.text = x.name;
      note.text = x.note;
      return x;
    }();
    final task = t!;
    final isNew = widget.task == null;
    final end = c.endOf(task);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(backgroundColor: K.site(site.colorIndex), radius: 7),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  site.name,
                  style: const TextStyle(color: K.muted, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isNew ? '工程を足す' : '工程を直す',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          SegmentedButton<TaskKind>(
            segments: const [
              ButtonSegment(
                value: TaskKind.work,
                label: Text('作業'),
                icon: Icon(Icons.horizontal_rule),
              ),
              ButtonSegment(
                value: TaskKind.milestone,
                label: Text('節目'),
                icon: Icon(Icons.change_history),
              ),
            ],
            selected: {task.kind},
            onSelectionChanged: (v) => setState(() => task.kind = v.first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: name,
            decoration: InputDecoration(
              labelText: task.isMilestone ? '節目の名前' : '作業の名前',
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) => task.name = v,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final s
                    in task.isMilestone
                        ? MilestoneType.values.map((m) => m.label)
                        : taskNameSuggestions)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      label: Text(s),
                      onPressed: () => setState(() {
                        task.name = s;
                        name.text = s;
                        if (task.isMilestone) {
                          task.milestone = MilestoneType.values.firstWhere(
                            (m) => m.label == s,
                          );
                        }
                      }),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _row(
            '始まり',
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton.filledTonal(
                  onPressed: () => setState(
                    () => task.start = c.addWorkDays(c.snap(task.start), -1),
                  ),
                  icon: const Icon(Icons.chevron_left),
                ),
                TextButton(
                  onPressed: () async {
                    final p = await pickDay(context, c.snap(task.start));
                    if (p != null) setState(() => task.start = c.snap(p));
                  },
                  child: Text(
                    md(c.snap(task.start)),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: () => setState(
                    () => task.start = c.addWorkDays(c.snap(task.start), 1),
                  ),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          if (!task.isMilestone)
            _row(
              '日数',
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton.filledTonal(
                    onPressed: task.workDays > 1
                        ? () => setState(() => task.workDays--)
                        : null,
                    icon: const Icon(Icons.remove),
                  ),
                  SizedBox(
                    width: 64,
                    child: Text(
                      '${task.workDays}日',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: () => setState(() => task.workDays++),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ),
          if (!task.isMilestone)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 6),
              child: Text(
                '終わり ${md(end)}（休みの日は数えません）',
                textAlign: TextAlign.right,
                style: const TextStyle(color: K.muted),
              ),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('雨だと止まる（外の作業）'),
            value: task.rainStops,
            onChanged: (v) => setState(() => task.rainStops = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('仮押さえ'),
            subtitle: const Text('点線で表示。まだ確定していない日程'),
            value: task.tentative,
            onChanged: (v) => setState(() => task.tentative = v),
          ),
          TextField(
            controller: note,
            decoration: const InputDecoration(
              labelText: 'メモ（任意）',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => task.note = v,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () async {
              if (task.name.trim().isEmpty) {
                task.name = task.isMilestone ? '節目' : '作業';
              }
              final nav = Navigator.of(context);
              if (isNew) {
                await st.addTask(site.id, task);
              } else {
                await st.updateTask(site.id, task);
              }
              nav.pop();
            },
            child: Text(isNew ? '足す' : '保存'),
          ),
          if (!isNew) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
              icon: const Icon(Icons.hourglass_bottom),
              label: const Text('遅れた → ここから後ろをずらす'),
              onPressed: () async {
                final nav = Navigator.of(context);
                final done = await _sheet<bool>(
                  context,
                  _DelaySheet(siteId: site.id, taskId: task.id),
                );
                if (done == true) nav.pop();
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: K.sunday),
              onPressed: () async {
                final nav = Navigator.of(context);
                await st.deleteTask(site.id, task.id);
                nav.pop();
              },
              child: const Text('この工程を消す'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, Widget child) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const Spacer(),
        child,
      ],
    ),
  );
}

class _DelaySheet extends StatefulWidget {
  const _DelaySheet({required this.siteId, required this.taskId});
  final String siteId;
  final String taskId;
  @override
  State<_DelaySheet> createState() => _DelaySheetState();
}

class _DelaySheetState extends State<_DelaySheet> {
  ShiftReason reason = ShiftReason.previousTrade;
  int days = 1;
  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final s = st.site(widget.siteId);
    final t = s.tasks.firstWhere((x) => x.id == widget.taskId);
    final after = s.tasks
        .where(
          (x) => !st.cal
              .forSite(s)
              .snap(x.start)
              .isBefore(st.cal.forSite(s).snap(t.start)),
        )
        .length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '「${t.name}」から後ろをずらす',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          Text(
            'この工程を含めて$after件がまとめて動きます',
            style: const TextStyle(color: K.muted),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in ShiftReason.values.where(
                (r) => r != ShiftReason.rain,
              ))
                ChoiceChip(
                  avatar: Icon(reasonIcon(r), size: 18),
                  label: Text(r.label),
                  selected: reason == r,
                  onSelected: (_) => setState(() => reason = r),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                onPressed: days > 1 ? () => setState(() => days--) : null,
                icon: const Icon(Icons.remove),
              ),
              SizedBox(
                width: 96,
                child: Text(
                  '$days日 うしろ',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton.filledTonal(
                onPressed: () => setState(() => days++),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () async {
              final nav = Navigator.of(context);
              await st.delayFrom(s.id, t.id, days, reason);
              nav.pop(true);
            },
            child: const Text('まとめてずらす'),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── 日付をタップ（雨・休み）

Future<void> openDaySheet(BuildContext context, DateTime day) async {
  await _sheet(context, _DaySheet(day: dayOf(day)));
}

class _DaySheet extends StatefulWidget {
  const _DaySheet({required this.day});
  final DateTime day;
  @override
  State<_DaySheet> createState() => _DaySheetState();
}

class _DaySheetState extends State<_DaySheet> {
  Set<String>? picked;

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final day = widget.day;
    final off = st.cal.offReason(day);
    final extraOff = st.data.holidays.extraOff.contains(dayKey(day));
    // その日に作業がある現場
    final working = [
      for (final s in st.activeSites)
        if (s.tasks.any(
          (t) => !t.isMilestone && st.cal.forSite(s).occupies(t, day),
        ))
          s,
    ];
    final stopped = [
      for (final s in st.activeSites)
        if (s.stopDayKeys.contains(dayKey(day))) s,
    ];
    picked ??= {
      for (final s in working)
        if (s.tasks.any(
          (t) => t.rainStops && st.cal.forSite(s).occupies(t, day),
        ))
          s.id,
    };
    if (picked!.isEmpty) picked = {for (final s in working) s.id};

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${day.month}月${dayJa(day)}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          if (off != null)
            Text('休み（$off）', style: const TextStyle(color: K.sunday)),
          const SizedBox(height: 12),
          if (working.isNotEmpty) ...[
            const Text(
              '雨で止める現場',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            for (final s in working)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: picked!.contains(s.id),
                onChanged: (v) => setState(
                  () => v == true ? picked!.add(s.id) : picked!.remove(s.id),
                ),
                secondary: CircleAvatar(
                  backgroundColor: K.site(s.colorIndex),
                  radius: 7,
                ),
                title: Text(s.name),
                subtitle: Text(
                  s.tasks
                      .where(
                        (t) =>
                            !t.isMilestone &&
                            st.cal.forSite(s).occupies(t, day),
                      )
                      .map((t) => t.name)
                      .join('・'),
                ),
              ),
            const SizedBox(height: 8),
            FilledButton.icon(
              icon: const Icon(Icons.umbrella),
              label: const Text('雨で中止 → 後ろを1日ずらす'),
              onPressed: picked!.isEmpty
                  ? null
                  : () async {
                      final nav = Navigator.of(context);
                      final messenger = ScaffoldMessenger.of(context);
                      final n = await st.rainDay(day, picked!);
                      nav.pop();
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('$n現場を1日ずらしました'),
                          action: SnackBarAction(
                            label: '元に戻す',
                            onPressed: st.undo,
                          ),
                        ),
                      );
                    },
            ),
            const SizedBox(height: 8),
          ] else if (off == null)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'この日に作業のある現場はありません',
                style: TextStyle(color: K.muted),
              ),
            ),
          for (final s in stopped)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.umbrella, color: K.saturday),
              title: Text('${s.name}は中止にしています'),
              trailing: TextButton(
                onPressed: () async {
                  final nav = Navigator.of(context);
                  await st.clearStopDay(s.id, day);
                  nav.pop();
                },
                child: const Text('取り消す'),
              ),
            ),
          if (off == null)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
              icon: const Icon(Icons.beach_access_outlined),
              label: const Text('この日は自分の休みにする（全部の現場）'),
              onPressed: () async {
                final nav = Navigator.of(context);
                await st.addOffDay(day);
                nav.pop();
              },
            )
          else if (extraOff)
            OutlinedButton(
              onPressed: () async {
                final nav = Navigator.of(context);
                await st.removeOffDay(day);
                nav.pop();
              },
              child: const Text('休みをやめる'),
            ),
          const SizedBox(height: 8),
          TextButton.icon(
            icon: const Icon(Icons.event_available),
            label: const Text('この日から空いてる？'),
            onPressed: () {
              Navigator.pop(context);
              openFreeCheckFrom(context, day);
            },
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── 現場の設定

Future<void> openSiteSheet(BuildContext context, String siteId) async {
  await _sheet(context, _SiteSheet(siteId: siteId));
}

class _SiteSheet extends StatefulWidget {
  const _SiteSheet({required this.siteId});
  final String siteId;
  @override
  State<_SiteSheet> createState() => _SiteSheetState();
}

class _SiteSheetState extends State<_SiteSheet> {
  TextEditingController? name;
  TextEditingController? memo;
  AppState? _st;

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    _st = st;
    if (!st.data.sites.any((s) => s.id == widget.siteId)) {
      return const SizedBox(height: 80);
    }
    final s = st.site(widget.siteId);
    name ??= TextEditingController(text: s.name);
    memo ??= TextEditingController(text: s.memo);
    final start = siteStart(s, st.cal);
    final end = handoverDay(s, st.cal);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: name,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            decoration: const InputDecoration(labelText: '現場の名前'),
            onSubmitted: (v) => st.updateSite(s.id, (x) => x.name = v.trim()),
          ),
          if (start != null && end != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '${md(start)} 〜 ${md(end)}　順延 ${s.logs.length}回',
                style: const TextStyle(color: K.muted),
              ),
            ),
          const SizedBox(height: 12),
          const Text('色', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            children: [
              for (var i = 0; i < K.siteColors.length; i++)
                GestureDetector(
                  onTap: () => st.updateSite(s.id, (x) => x.colorIndex = i),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: K.siteColors[i],
                    child: s.colorIndex == i
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: memo,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: '現場メモ（駐車場・鍵・作業できる時間など）',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            initialValue: s.saturdayWork == null
                ? 0
                : (s.saturdayWork! ? 1 : 2),
            decoration: const InputDecoration(labelText: '土曜日'),
            items: const [
              DropdownMenuItem(value: 0, child: Text('全体の設定に合わせる')),
              DropdownMenuItem(value: 1, child: Text('この現場は土曜も作業')),
              DropdownMenuItem(value: 2, child: Text('この現場は土曜休み')),
            ],
            onChanged: (v) => st.updateSite(
              s.id,
              (x) => x.saturdayWork = v == 0 ? null : v == 1,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('工程を足す'),
            onPressed: () {
              Navigator.pop(context);
              openTaskSheet(
                context,
                s.id,
                start: end == null
                    ? st.today
                    : st.cal.forSite(s).addWorkDays(end, 1),
              );
            },
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
            icon: const Icon(Icons.ios_share),
            label: const Text('この現場だけ送る'),
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ExportScreen(onlySiteId: s.id),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
            icon: const Icon(Icons.inventory_outlined),
            label: const Text('終わった現場としてしまう'),
            onPressed: () async {
              final nav = Navigator.of(context);
              await st.updateSite(
                s.id,
                (x) => x.name = name!.text.trim().isEmpty
                    ? x.name
                    : name!.text.trim(),
              );
              await st.archiveSite(s.id, true);
              nav.pop();
            },
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: K.sunday),
            onPressed: () async {
              final nav = Navigator.of(context);
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: Text('「${s.name}」を消しますか？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('やめる'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('消す'),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                await st.deleteSite(s.id);
                nav.pop();
              }
            },
            child: const Text('この現場を消す'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // 閉じたときに名前とメモを保存
    final st = _st;
    final n = name?.text.trim() ?? '';
    final m = memo?.text ?? '';
    final id = widget.siteId;
    if (st != null && st.data.sites.any((x) => x.id == id)) {
      final s = st.site(id);
      if ((n.isNotEmpty && n != s.name) || m != s.memo) {
        Future.microtask(
          () => st.updateSite(id, (x) {
            if (n.isNotEmpty) x.name = n;
            x.memo = m;
          }),
        );
      }
    }
    name?.dispose();
    memo?.dispose();
    super.dispose();
  }
}
