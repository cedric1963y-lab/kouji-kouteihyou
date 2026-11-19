import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_info.dart';
import '../core/days.dart';
import '../core/schedule.dart';
import '../core/store.dart';
import 'board.dart';
import 'export.dart';
import 'free_check.dart';
import 'pro.dart';
import 'scope.dart';
import 'settings.dart';
import 'sheets.dart';
import 'theme.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key, this.initialZoom = Zoom.twoWeeks});
  final Zoom initialZoom;
  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  late Zoom zoom = widget.initialZoom;
  bool compact = false;
  final scrollX = ScrollController();
  String? dragTask;
  double dragDx = 0;
  bool _jumped = false;

  @override
  void dispose() {
    scrollX.dispose();
    super.dispose();
  }

  BoardSpec _spec(AppState st) {
    final sites = st.activeSites;
    var from = addDays(st.today, -7);
    var to = addDays(st.today, 70);
    for (final s in sites) {
      final a = siteStart(s, st.cal);
      final b = siteEnd(s, st.cal);
      if (a != null && a.isBefore(from)) from = addDays(a, -3);
      if (b != null && addDays(b, 21).isAfter(to)) to = addDays(b, 21);
    }
    return BoardSpec(
      sites: sites,
      cal: st.cal,
      from: from,
      days: daysBetween(from, to) + 1,
      colW: zoom.col,
      today: st.today,
      compact: compact,
    );
  }

  void _jumpToToday(BoardSpec spec) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollX.hasClients) return;
      final x = (spec.colOf(spec.today) - 2) * spec.colW;
      scrollX.jumpTo(x.clamp(0, scrollX.position.maxScrollExtent));
    });
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final spec = _spec(st);
    if (!_jumped && spec.sites.isNotEmpty) {
      _jumped = true;
      _jumpToToday(spec);
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text(appName),
        actions: [
          IconButton(
            tooltip: '空き確認',
            icon: const Icon(Icons.event_available),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FreeCheckScreen()),
            ),
          ),
          IconButton(
            tooltip: '送る',
            icon: const Icon(Icons.ios_share),
            onPressed: spec.sites.isEmpty
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ExportScreen()),
                  ),
          ),
          IconButton(
            tooltip: '設定',
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _toolbar(st, spec),
          Expanded(child: spec.sites.isEmpty ? _empty() : _board(st, spec)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openNewSite(context),
        icon: const Icon(Icons.add),
        label: const Text(
          '現場',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
    );
  }

  Widget _toolbar(AppState st, BoardSpec spec) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
      child: Row(
        children: [
          SegmentedButton<Zoom>(
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: [
              for (final z in Zoom.values)
                ButtonSegment(value: z, label: Text(z.label)),
            ],
            selected: {zoom},
            onSelectionChanged: (v) {
              setState(() => zoom = v.first);
              _jumpToToday(_spec(st));
            },
          ),
          const SizedBox(width: 6),
          FilterChip(
            label: const Text('まとめ'),
            selected: compact,
            visualDensity: VisualDensity.compact,
            onSelected: (v) => setState(() => compact = v),
          ),
          const Spacer(),
          IconButton(
            tooltip: '今日へ',
            icon: const Icon(Icons.today),
            onPressed: () => _jumpToToday(spec),
          ),
          IconButton(
            tooltip: '元に戻す',
            icon: const Icon(Icons.undo),
            onPressed: st.canUndo ? st.undo : null,
          ),
        ],
      ),
    );
  }

  Widget _empty() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.view_timeline_outlined, size: 64, color: K.muted),
          const SizedBox(height: 12),
          const Text(
            '右下の「＋ 現場」から\n職種を選ぶだけで工程表ができます',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, height: 1.5),
          ),
          const SizedBox(height: 8),
          Text(
            '雨の日は日付をタップ → 「雨で中止」で\n後ろの工程がまとめてずれます',
            textAlign: TextAlign.center,
            style: TextStyle(color: K.muted, height: 1.5),
          ),
        ],
      ),
    ),
  );

  Widget _board(AppState st, BoardSpec spec) {
    return SingleChildScrollView(
      controller: scrollX,
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: spec.width,
        child: Column(
          children: [
            GestureDetector(
              onTapUp: (d) =>
                  openDaySheet(context, spec.dayAt(d.localPosition.dx)),
              child: CustomPaint(
                size: Size(spec.width, BoardSpec.headerH),
                painter: HeaderPainter(spec, scrollX: scrollX),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 96),
                child: GestureDetector(
                  onTapUp: (d) => _onTap(st, spec, d.localPosition),
                  onLongPressStart: (d) => _dragStart(spec, d.localPosition),
                  onLongPressMoveUpdate: (d) {
                    if (dragTask == null) return;
                    setState(() => dragDx = d.offsetFromOrigin.dx);
                  },
                  onLongPressEnd: (_) => _dragEnd(st, spec),
                  child: CustomPaint(
                    size: Size(spec.width, spec.bodyHeight),
                    painter: BodyPainter(
                      spec,
                      scrollX: scrollX,
                      dragTaskId: dragTask,
                      dragDx: dragDx,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _dragSite;

  void _dragStart(BoardSpec spec, Offset p) {
    final r = spec.rowAt(p.dy);
    if (r == null) return;
    final t = spec.taskAt(r, p.dx);
    if (t == null) return;
    HapticFeedback.mediumImpact();
    setState(() {
      dragTask = t.id;
      _dragSite = r.site.id;
      dragDx = 0;
    });
  }

  Future<void> _dragEnd(AppState st, BoardSpec spec) async {
    final id = dragTask;
    final siteId = _dragSite;
    final cols = (dragDx / spec.colW).round();
    setState(() {
      dragTask = null;
      dragDx = 0;
    });
    if (id == null || siteId == null || cols == 0) return;
    final s = st.site(siteId);
    final t = s.tasks.firstWhere((x) => x.id == id);
    final c = st.cal.forSite(s);
    final target = addDays(c.snap(t.start), cols);
    final n = await st.dragTask(siteId, id, target);
    if (!mounted || n == 0) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('「${t.name}」から後ろを ${n > 0 ? '+' : ''}$n日 ずらしました'),
          action: SnackBarAction(label: '元に戻す', onPressed: st.undo),
        ),
      );
  }

  void _onTap(AppState st, BoardSpec spec, Offset p) {
    final r = spec.rowAt(p.dy);
    if (r == null) return;
    final t = spec.taskAt(r, p.dx);
    if (t != null) {
      openTaskSheet(context, r.site.id, task: t);
      return;
    }
    if (r.isHeader) {
      openSiteSheet(context, r.site.id);
    } else {
      openTaskSheet(context, r.site.id, start: spec.dayAt(p.dx));
    }
  }
}

/// 無料の上限に当たったとき
Future<void> showLimit(BuildContext context) async {
  await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const ProScreen(reason: '無料では現場2つまでです')),
  );
}

Future<void> guardLimit(BuildContext context, Future<void> Function() f) async {
  try {
    await f();
  } on LimitReached {
    if (context.mounted) await showLimit(context);
  }
}
