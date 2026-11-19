import 'package:flutter/material.dart';

import '../core/days.dart';
import '../core/holidays.dart';
import '../core/models.dart';
import '../core/schedule.dart';
import 'theme.dart';

enum Zoom { twoWeeks, month, quarter }

extension ZoomX on Zoom {
  double get col => switch (this) {
    Zoom.twoWeeks => 40,
    Zoom.month => 26,
    Zoom.quarter => 12,
  };
  String get label => switch (this) {
    Zoom.twoWeeks => '2週間',
    Zoom.month => '1ヶ月',
    Zoom.quarter => '3ヶ月',
  };
}

/// 表示する1行
class BoardRow {
  BoardRow.site(this.site) : task = null;
  BoardRow.task(this.site, this.task);
  final Site site;
  final Task? task;
  bool get isHeader => task == null;
  double get height => isHeader ? 30 : 34;
}

/// 工程表の見た目の設定（画面と書き出しで共通）
class BoardSpec {
  BoardSpec({
    required this.sites,
    required this.cal,
    required this.from,
    required this.days,
    required this.colW,
    required this.today,
    this.compact = false,
    this.showTentative = true,
    this.clipToRange = false,
  }) {
    rows = [];
    final last = addDays(from, days - 1);
    for (final s in sites) {
      rows.add(BoardRow.site(s));
      if (compact) continue;
      final c = cal.forSite(s);
      for (final t in s.tasks) {
        if (!showTentative && t.tentative) continue;
        if (clipToRange &&
            (c.endOf(t).isBefore(from) || c.snap(t.start).isAfter(last))) {
          continue;
        }
        rows.add(BoardRow.task(s, t));
      }
    }
  }

  final List<Site> sites;
  final WorkCalendar cal;
  final DateTime from;
  final int days;
  final double colW;
  final DateTime today;

  /// まとめ表示: 現場1行に工程を並べる
  final bool compact;
  final bool showTentative;

  /// 書き出し: 範囲の外の工程は行ごと省く
  final bool clipToRange;
  late final List<BoardRow> rows;

  static const headerH = 50.0;

  double get width => days * colW;
  double get bodyHeight {
    var h = 0.0;
    for (final r in rows) {
      h += compact ? 40 : r.height;
    }
    return h;
  }

  double rowH(BoardRow r) => compact ? 40 : r.height;

  int colOf(DateTime d) => daysBetween(from, d);
  DateTime dayAt(double x) => addDays(from, (x / colW).floor());

  /// y → 行
  BoardRow? rowAt(double y) {
    var top = 0.0;
    for (final r in rows) {
      final h = rowH(r);
      if (y >= top && y < top + h) return r;
      top += h;
    }
    return null;
  }

  double rowTop(BoardRow target) {
    var top = 0.0;
    for (final r in rows) {
      if (identical(r, target)) return top;
      top += rowH(r);
    }
    return top;
  }

  /// その行・その x にある工程
  Task? taskAt(BoardRow r, double x) {
    final c = cal.forSite(r.site);
    final candidates = r.isHeader
        ? (compact ? r.site.tasks : const <Task>[])
        : [r.task!];
    for (final t in candidates.reversed) {
      final s = colOf(c.snap(t.start)) * colW;
      final e = (colOf(c.endOf(t)) + 1) * colW;
      final pad = t.isMilestone ? colW * 0.6 : 0;
      if (x >= s - pad && x <= e + pad) return t;
    }
    return null;
  }
}

TextPainter _tp(
  String s,
  double size,
  Color c, {
  FontWeight w = FontWeight.w400,
  double? maxW,
}) {
  final tp = TextPainter(
    text: TextSpan(
      text: s,
      style: TextStyle(
        fontFamily: 'NotoSansJP',
        fontSize: size,
        color: c,
        fontWeight: w,
        height: 1.1,
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: maxW ?? double.infinity);
  return tp;
}

void _icon(Canvas canvas, IconData i, Offset at, double size, Color c) {
  final tp = TextPainter(
    text: TextSpan(
      text: String.fromCharCode(i.codePoint),
      style: TextStyle(
        fontFamily: i.fontFamily,
        package: i.fontPackage,
        fontSize: size,
        color: c,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, at);
}

Color dayLabelColor(WorkCalendar cal, DateTime d) {
  if (d.weekday == DateTime.sunday || holidayName(d) != null) return K.sunday;
  if (d.weekday == DateTime.saturday) return K.saturday;
  return K.ink;
}

/// 日付の見出し
class HeaderPainter extends CustomPainter {
  HeaderPainter(this.spec, {this.scrollX}) : super(repaint: scrollX);
  final BoardSpec spec;
  final ScrollController? scrollX;

  @override
  void paint(Canvas canvas, Size size) {
    final w = spec.colW;
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final line = Paint()
      ..color = K.grid
      ..strokeWidth = 1;
    for (var i = 0; i < spec.days; i++) {
      final d = addDays(spec.from, i);
      final x = i * w;
      final off = spec.cal.offReason(d) != null;
      if (off) {
        canvas.drawRect(
          Rect.fromLTWH(x, 18, w, size.height - 18),
          Paint()..color = K.off,
        );
      }
      if (sameDay(d, spec.today)) {
        canvas.drawRect(
          Rect.fromLTWH(x, 18, w, size.height - 18),
          Paint()..color = K.orange,
        );
      }
      if (d.day == 1 || i == 0) {
        _tp(
          '${d.month}月',
          12,
          K.ink,
          w: FontWeight.w700,
        ).paint(canvas, Offset(x + 3, 2));
        canvas.drawLine(
          Offset(x, 0),
          Offset(x, size.height),
          line..color = K.muted,
        );
        line.color = K.grid;
      }
      final today = sameDay(d, spec.today);
      final col = today ? Colors.white : dayLabelColor(spec.cal, d);
      final showEvery = w >= 20 || d.weekday == DateTime.monday || d.day == 1;
      if (showEvery) {
        final n = _tp('${d.day}', w >= 20 ? 13 : 10, col, w: FontWeight.w700);
        n.paint(canvas, Offset(x + (w - n.width) / 2, 19));
        if (w >= 20) {
          final k = _tp(wd(d), 10, col);
          k.paint(canvas, Offset(x + (w - k.width) / 2, 35));
        }
      }
      canvas.drawLine(Offset(x, 18), Offset(x, size.height), line);
    }
    canvas.drawLine(
      Offset(0, size.height - 0.5),
      Offset(size.width, size.height - 0.5),
      Paint()..color = K.muted,
    );
    // 左端の月（スクロールしても残す）
    final off = (scrollX != null && scrollX!.hasClients)
        ? scrollX!.offset
        : 0.0;
    if (off > 0) {
      final d = spec.dayAt(off + 1);
      final next = (d.month == 12)
          ? DateTime(d.year + 1, 1, 1)
          : DateTime(d.year, d.month + 1, 1);
      final nextX = spec.colOf(next) * w;
      final tp = _tp('${d.month}月', 12, K.ink, w: FontWeight.w700);
      final x = (off + 3).clamp(0.0, nextX - tp.width - 6).toDouble();
      canvas.drawRect(
        Rect.fromLTWH(x - 3, 0, tp.width + 6, 17),
        Paint()..color = Colors.white,
      );
      tp.paint(canvas, Offset(x, 2));
    }
  }

  @override
  bool shouldRepaint(covariant HeaderPainter old) => true;
}

/// 本体（帯）
class BodyPainter extends CustomPainter {
  BodyPainter(
    this.spec, {
    this.scrollX,
    this.dragTaskId,
    this.dragDx = 0,
    this.viewportW,
  }) : super(repaint: scrollX);
  final BoardSpec spec;
  final ScrollController? scrollX;
  final String? dragTaskId;
  final double dragDx;
  final double? viewportW;

  double get _offset =>
      (scrollX != null && scrollX!.hasClients) ? scrollX!.offset : 0;

  @override
  void paint(Canvas canvas, Size size) {
    final w = spec.colW;
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    // 列（休み・今日）
    for (var i = 0; i < spec.days; i++) {
      final d = addDays(spec.from, i);
      final x = i * w;
      if (spec.cal.offReason(d) != null) {
        canvas.drawRect(
          Rect.fromLTWH(x, 0, w, size.height),
          Paint()..color = K.off,
        );
      }
      if (sameDay(d, spec.today)) {
        canvas.drawRect(
          Rect.fromLTWH(x, 0, w, size.height),
          Paint()..color = K.todayFill,
        );
      }
      final p = Paint()
        ..color = (d.day == 1) ? K.muted.withValues(alpha: 0.5) : K.grid
        ..strokeWidth = 1;
      if (w >= 20 || d.weekday == DateTime.monday || d.day == 1) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
      }
    }
    // 行
    var top = 0.0;
    final headerTops = <(Site, double)>[];
    for (final r in spec.rows) {
      if (r.isHeader) headerTops.add((r.site, top));
      top += spec.rowH(r);
    }
    for (final (s, t) in headerTops) {
      _stopColumns(canvas, s, t, icons: false);
    }
    top = 0.0;
    for (final r in spec.rows) {
      final h = spec.rowH(r);
      if (r.isHeader) {
        _siteHeader(canvas, r.site, top, h, size.width);
      } else {
        _taskBar(canvas, r.site, r.task!, top, h);
      }
      top += h;
    }
    for (final (s, t) in headerTops) {
      _stopColumns(canvas, s, t, icons: true);
    }
    // 今日の線
    final tc = spec.colOf(spec.today);
    if (tc >= 0 && tc < spec.days) {
      final x = tc * w + w / 2;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()
          ..color = K.orange
          ..strokeWidth = 2,
      );
    }
  }

  /// 雨などで止めた日: 現場のかたまり全体を薄い青に、空いている行に傘
  void _stopColumns(Canvas canvas, Site s, double top, {required bool icons}) {
    final stops = s.logs.where((l) => l.stopDay).toList();
    if (stops.isEmpty) return;
    final rows = spec.rows.where((r) => identical(r.site, s)).toList();
    final blockH = rows.fold<double>(0, (a, r) => a + spec.rowH(r));
    final c = spec.cal.forSite(s);
    for (final l in stops) {
      final col = spec.colOf(l.day);
      if (col < 0 || col >= spec.days) continue;
      final x = col * spec.colW;
      if (!icons) {
        canvas.drawRect(
          Rect.fromLTWH(x, top, spec.colW, blockH),
          Paint()..color = const Color(0x262F80C8),
        );
        continue;
      }
      var y = top;
      for (final r in rows) {
        final h = spec.rowH(r);
        if (!r.isHeader) {
          final t = r.task!;
          final covered =
              !l.day.isBefore(c.snap(t.start)) &&
              !l.day.isAfter(c.endOf(t)) &&
              !t.isMilestone;
          final iconSize = spec.colW < 16 ? spec.colW - 2 : 14.0;
          if (covered || iconSize >= 10) {
            _icon(
              canvas,
              l.reason == ShiftReason.rain ? Icons.umbrella : Icons.block,
              Offset(x + (spec.colW - iconSize) / 2, y + (h - iconSize) / 2),
              iconSize,
              const Color(0xFF1F5F99).withValues(alpha: covered ? 1 : 0.45),
            );
          }
        }
        y += h;
      }
    }
  }

  void _siteHeader(Canvas canvas, Site s, double top, double h, double width) {
    final color = K.site(s.colorIndex);
    canvas.drawRect(
      Rect.fromLTWH(0, top, width, h),
      Paint()..color = color.withValues(alpha: 0.10),
    );
    canvas.drawLine(
      Offset(0, top),
      Offset(width, top),
      Paint()..color = color.withValues(alpha: 0.5),
    );
    final c = spec.cal.forSite(s);
    if (spec.compact) {
      for (final t in s.tasks) {
        if (!spec.showTentative && t.tentative) continue;
        _bar(canvas, s, t, c, top + 6, h - 12, label: true);
      }
    }
    // 現場名（スクロールしても左に残る）
    final end = handoverDay(s, spec.cal);
    final name = _tp(s.name, 13, K.ink, w: FontWeight.w700, maxW: 180);
    final x0 = _offset + 6;
    final tag = end == null ? null : _tp('引渡 ${md(end)}', 11, K.muted);
    final boxW = 16 + name.width + (tag == null ? 0 : tag.width + 8) + 8;
    final y = spec.compact ? top + 1 : top + (h - name.height) / 2;
    if (spec.compact) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x0 - 2, y - 1, boxW, name.height + 2),
          const Radius.circular(4),
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.85),
      );
    }
    canvas.drawCircle(
      Offset(x0 + 5, y + name.height / 2),
      5,
      Paint()..color = color,
    );
    name.paint(canvas, Offset(x0 + 14, y));
    tag?.paint(canvas, Offset(x0 + 22 + name.width, y + 2));
  }

  void _taskBar(Canvas canvas, Site s, Task t, double top, double h) {
    final c = spec.cal.forSite(s);
    canvas.drawLine(
      Offset(0, top + h),
      Offset(spec.width, top + h),
      Paint()..color = K.grid.withValues(alpha: 0.6),
    );
    _bar(canvas, s, t, c, top + 6, h - 12, label: true);
  }

  void _bar(
    Canvas canvas,
    Site s,
    Task t,
    WorkCalendar c,
    double y,
    double h, {
    bool label = true,
  }) {
    final w = spec.colW;
    final color = K.site(s.colorIndex);
    final dx = t.id == dragTaskId ? dragDx : 0.0;
    final sc = spec.colOf(c.snap(t.start));
    final ec = spec.colOf(c.endOf(t));
    if (ec < 0 || sc >= spec.days) return;
    if (t.isMilestone) {
      final cx = sc * w + w / 2 + dx;
      final cy = y + h / 2;
      final r = h / 2 + 1;
      final path = Path()
        ..moveTo(cx, cy - r)
        ..lineTo(cx + r, cy)
        ..lineTo(cx, cy + r)
        ..lineTo(cx - r, cy)
        ..close();
      final handover = t.milestone == MilestoneType.handover;
      canvas.drawPath(path, Paint()..color = handover ? K.orange : K.ink);
      if (label) {
        final tp = _tp(t.name, 11, K.ink, w: FontWeight.w700);
        tp.paint(canvas, Offset(cx + r + 3, cy - tp.height / 2));
      }
      return;
    }
    final left = sc * w + dx;
    final right = (ec + 1) * w + dx;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTRB(left + 1, y, right - 1, y + h),
      const Radius.circular(5),
    );
    final fill = Paint()
      ..color = t.tentative ? color.withValues(alpha: 0.28) : color;
    canvas.drawRRect(rect, fill);
    // 休み・止まった日は薄く
    for (var i = sc; i <= ec; i++) {
      final d = addDays(spec.from, i);
      if (!c.isWorkDay(d)) {
        canvas.save();
        canvas.clipRRect(rect);
        canvas.drawRect(
          Rect.fromLTWH(i * w + dx, y, w, h),
          Paint()..color = Colors.white.withValues(alpha: 0.62),
        );
        canvas.restore();
      }
    }
    if (t.tentative) {
      final p = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      _dashedRRect(canvas, rect, p);
    }
    if (t.id == dragTaskId) {
      canvas.drawRRect(
        rect.inflate(2),
        Paint()
          ..color = K.orange
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    if (!label) return;
    final text = '${t.tentative ? '仮・' : ''}${t.name}';
    final inside = right - left - 8;
    final tp = _tp(
      text,
      12,
      t.tentative ? K.ink : Colors.white,
      w: FontWeight.w700,
    );
    if (tp.width <= inside) {
      tp.paint(canvas, Offset(left + 5, y + (h - tp.height) / 2));
    } else {
      final o = _tp(text, 11, K.ink, w: FontWeight.w700);
      o.paint(canvas, Offset(right + 3, y + (h - o.height) / 2));
    }
  }

  void _dashedRRect(Canvas canvas, RRect r, Paint p) {
    final path = Path()..addRRect(r);
    for (final m in path.computeMetrics()) {
      var dist = 0.0;
      while (dist < m.length) {
        canvas.drawPath(m.extractPath(dist, dist + 4), p);
        dist += 7;
      }
    }
  }

  @override
  bool shouldRepaint(covariant BodyPainter old) => true;
}
