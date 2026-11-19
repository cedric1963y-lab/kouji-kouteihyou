import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../app_info.dart';
import '../core/days.dart';
import '../core/models.dart';
import '../core/schedule.dart';
import '../core/store.dart';
import 'board.dart';
import 'pro.dart';
import 'scope.dart';
import 'theme.dart';

enum ExportRange { twoWeeks, month, all }

enum Audience { contractor, client }

extension on ExportRange {
  String get label => switch (this) {
    ExportRange.twoWeeks => '2週間',
    ExportRange.month => '1ヶ月',
    ExportRange.all => '全部',
  };
}

/// 元請さん・お客さんに送る画像とPDF
class ExportScreen extends StatefulWidget {
  const ExportScreen({
    super.key,
    this.onlySiteId,
    this.initialRange = ExportRange.twoWeeks,
  });
  final String? onlySiteId;
  final ExportRange initialRange;
  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  late ExportRange range = widget.initialRange;
  Audience audience = Audience.contractor;
  final boundary = GlobalKey();
  bool busy = false;

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final sites = widget.onlySiteId == null
        ? st.activeSites
        : [st.site(widget.onlySiteId!)];
    final card = ExportCard(
      state: st,
      sites: sites,
      range: range,
      audience: audience,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('予定を送る')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Column(
              children: [
                SegmentedButton<ExportRange>(
                  showSelectedIcon: false,
                  segments: [
                    for (final r in ExportRange.values)
                      ButtonSegment(value: r, label: Text(r.label)),
                  ],
                  selected: {range},
                  onSelectionChanged: (v) => setState(() => range = v.first),
                ),
                const SizedBox(height: 8),
                SegmentedButton<Audience>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: Audience.contractor,
                      label: Text('元請さん向け'),
                    ),
                    ButtonSegment(
                      value: Audience.client,
                      label: Text('お客さん向け'),
                    ),
                  ],
                  selected: {audience},
                  onSelectionChanged: (v) => setState(() => audience = v.first),
                ),
                if (audience == Audience.client)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      '仮押さえとメモは出さず、工程をまとめて見やすくします',
                      style: TextStyle(color: K.muted, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: K.grid),
                  color: Colors.white,
                ),
                child: SingleChildScrollView(
                  child: FittedBox(
                    fit: BoxFit.fitWidth,
                    alignment: Alignment.topCenter,
                    child: RepaintBoundary(key: boundary, child: card),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.image_outlined),
                      label: const Text('画像で送る（LINEなど）'),
                      onPressed: busy ? null : () => _shareImage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 52),
                    ),
                    icon: Icon(
                      st.isPro ? Icons.picture_as_pdf : Icons.lock_outline,
                    ),
                    label: const Text('PDF'),
                    onPressed: busy
                        ? null
                        : () => st.isPro
                              ? _sharePdf()
                              : Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ProScreen(
                                      reason: 'PDFで送るのは Pro の機能です',
                                    ),
                                  ),
                                ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<Uint8List> _png() async {
    final ro =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final img = await ro.toImage(pixelRatio: 2.5);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  Future<File> _tmp(String name) async {
    final dir = await getTemporaryDirectory();
    return File('${dir.path}/$name');
  }

  String get _stamp {
    final n = DateTime.now();
    return '${n.year}${n.month.toString().padLeft(2, '0')}${n.day.toString().padLeft(2, '0')}';
  }

  Future<void> _shareImage() async {
    setState(() => busy = true);
    try {
      final f = await _tmp('工程表_$_stamp.png');
      await f.writeAsBytes(await _png());
      await SharePlus.instance.share(ShareParams(files: [XFile(f.path)]));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _sharePdf() async {
    setState(() => busy = true);
    try {
      final png = await _png();
      final doc = pw.Document();
      final image = pw.MemoryImage(png);
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(20),
          build: (_) =>
              pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
        ),
      );
      final f = await _tmp('工程表_$_stamp.pdf');
      await f.writeAsBytes(await doc.save());
      await SharePlus.instance.share(ShareParams(files: [XFile(f.path)]));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

/// 書き出す1枚（画面に出すプレビューと同じもの）
class ExportCard extends StatelessWidget {
  const ExportCard({
    super.key,
    required this.state,
    required this.sites,
    required this.range,
    required this.audience,
  });
  final AppState state;
  final List<Site> sites;
  final ExportRange range;
  final Audience audience;

  static const width = 1000.0;

  @override
  Widget build(BuildContext context) {
    final st = state;
    final cal = st.cal;
    DateTime from;
    int days;
    if (range == ExportRange.all) {
      DateTime? a;
      DateTime? b;
      for (final s in sites) {
        final x = siteStart(s, cal);
        final y = siteEnd(s, cal);
        if (x != null && (a == null || x.isBefore(a))) a = x;
        if (y != null && (b == null || y.isAfter(b))) b = y;
      }
      from = addDays(a ?? st.today, -1);
      days = daysBetween(from, addDays(b ?? st.today, 2)) + 1;
    } else {
      from = addDays(st.today, -1);
      days = range == ExportRange.twoWeeks ? 15 : 32;
    }
    final colW = (width - 32) / days;
    final client = audience == Audience.client;
    final spec = BoardSpec(
      sites: sites,
      cal: cal,
      from: from,
      days: days,
      colW: colW,
      today: st.today,
      compact: client && colW < 18,
      showTentative: !client,
      clipToRange: true,
    );
    final company = st.isPro ? st.data.profile.company.trim() : '';
    final contact = st.isPro ? st.data.profile.contact.trim() : '';
    final logs = <(Site, ShiftLog)>[
      for (final s in sites)
        for (final l in s.logs) (s, l),
    ]..sort((a, b) => b.$2.day.compareTo(a.$2.day));

    return Container(
      width: width,
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                client ? '工事の予定' : '工程表',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: K.ink,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${md(st.today)} 時点',
                style: const TextStyle(fontSize: 15, color: K.muted),
              ),
              const Spacer(),
              if (company.isNotEmpty || contact.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (company.isNotEmpty)
                      Text(
                        company,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    if (contact.isNotEmpty)
                      Text(
                        contact,
                        style: const TextStyle(fontSize: 13, color: K.muted),
                      ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          for (final s in sites)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _siteLine(s, cal, client),
            ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(border: Border.all(color: K.grid)),
            child: Column(
              children: [
                CustomPaint(
                  size: Size(spec.width, BoardSpec.headerH),
                  painter: HeaderPainter(spec),
                ),
                CustomPaint(
                  size: Size(spec.width, spec.bodyHeight),
                  painter: BodyPainter(spec),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            children: const [
              _Key(Icons.change_history, '節目（橙は引渡し）'),
              _Key(Icons.umbrella, '雨などで中止した日'),
              _Key(Icons.crop_square, '薄い所は休みの日'),
            ],
          ),
          if (logs.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              '順延の記録',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            for (final (s, l) in logs.take(6))
              Text(
                '${md(l.day)}　${sites.length > 1 ? '${s.name}　' : ''}'
                '${l.reason.label}${l.stopDay ? 'で中止' : ''}（${l.days > 0 ? '+' : ''}${l.days}日）',
                style: const TextStyle(fontSize: 13),
              ),
          ],
          if (!client)
            for (final s in sites.where((s) => s.memo.trim().isNotEmpty))
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${s.name}：${s.memo.trim()}',
                  style: const TextStyle(fontSize: 13, color: K.muted),
                ),
              ),
          if (!st.isPro)
            const Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  appCredit,
                  style: TextStyle(fontSize: 11, color: K.muted),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _siteLine(Site s, WorkCalendar cal, bool client) {
    final a = siteStart(s, cal);
    final b = handoverDay(s, cal);
    final ms = s.tasks.where((t) => t.isMilestone).toList();
    final c = cal.forSite(s);
    return Row(
      children: [
        CircleAvatar(backgroundColor: K.site(s.colorIndex), radius: 6),
        const SizedBox(width: 6),
        Text(
          s.name,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        const SizedBox(width: 10),
        if (a != null && b != null)
          Text(
            '${md(a)} 〜 ${md(b)}',
            style: const TextStyle(fontSize: 14, color: K.ink),
          ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            ms.map((t) => '${t.name} ${md(c.snap(t.start))}').join('　'),
            style: const TextStyle(fontSize: 13, color: K.muted),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key(this.i, this.t);
  final IconData i;
  final String t;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(i, size: 14, color: K.muted),
      const SizedBox(width: 3),
      Text(t, style: const TextStyle(fontSize: 12, color: K.muted)),
    ],
  );
}
