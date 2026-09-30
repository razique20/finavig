// ignore_for_file: avoid_print
/// Builds the mobile-view Finavig pitch PDF: phone-shaped portrait pages
/// that read like a landing page, using every live screenshot captured by
/// tool/capture_pitch_shots.sh. Structured as Why -> How -> What.
///
/// Usage: dart run tool/build_pitch_mobile_pdf.dart [output.pdf]
/// Output defaults to finavig-pitch-mobile.pdf (project root).
import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

const _indigo = PdfColor.fromInt(0xFF4F46E5);
const _indigoDeep = PdfColor.fromInt(0xFF312E81);
const _indigoBright = PdfColor.fromInt(0xFF818CF8);
const _indigoBright50 = PdfColor.fromInt(0x80818CF8); // 50% alpha
const _emerald = PdfColor.fromInt(0xFF10B981);
const _ink = PdfColor.fromInt(0xFF0C0E14);
const _white = PdfColors.white;

/// Phone-shaped page (roughly iPhone logical size, slightly taller so a
/// full-width screenshot fits under its copy on one page).
const _page = PdfPageFormat(375, 1150);
const _margin = 24.0;

const _shotsDir = 'build/pitch/shots';

Future<void> main(List<String> args) async {
  final outPath = args.isNotEmpty ? args.first : 'finavig-pitch-mobile.pdf';

  final doc = pw.Document();
  pw.MemoryImage? shot(String name) => _loadShot(name);

  // ── Cover ──────────────────────────────────────────────────────────────
  doc.addPage(_page_(pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _fvMark(size: 58),
      pw.SizedBox(height: 22),
      pw.Text('FINAVIG',
          style: pw.TextStyle(
            color: _white,
            fontSize: 36,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 5,
          )),
      pw.SizedBox(height: 6),
      pw.Text('F I N A N C I A L   &   D O C U M E N T\nI N T E L L I G E N C E',
          style: pw.TextStyle(color: _indigoBright, fontSize: 10, height: 1.5)),
      pw.SizedBox(height: 24),
      pw.Text('The command center\nfor GCC businesses.',
          style: pw.TextStyle(
            color: _white,
            fontSize: 26,
            fontWeight: pw.FontWeight.bold,
            height: 1.2,
          )),
      pw.SizedBox(height: 14),
      pw.Text(
        'Document deadlines, company money and AI insights in one '
        'local-first app. Every screen in this deck is the live app with '
        'demo data.',
        style: pw.TextStyle(color: PdfColors.white, fontSize: 12.5, height: 1.5),
      ),
      pw.SizedBox(height: 20),
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: pw.BoxDecoration(
          borderRadius: pw.BorderRadius.circular(99),
          border: pw.Border.all(color: _indigoBright, width: 1),
        ),
        child: pw.Text('WHY  ·  HOW  ·  WHAT',
            style: pw.TextStyle(
              color: _indigoBright,
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 2,
            )),
      ),
      pw.SizedBox(height: 28),
      if (shot('01_home') != null)
        pw.Container(alignment: pw.Alignment.center, child: _phone(shot('01_home')!, width: 230)),
    ],
  )));

  // ── WHY ────────────────────────────────────────────────────────────────
  doc.addPage(_page_(pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _kicker('WHY'),
      pw.SizedBox(height: 10),
      _h1('Paper deadlines eat profits.'),
      pw.SizedBox(height: 12),
      pw.Text(
        'Every GCC company juggles the same three failures - and the tools '
        'that should help were built for someone else.',
        style: pw.TextStyle(color: PdfColors.white, fontSize: 12.5, height: 1.5),
      ),
      pw.SizedBox(height: 20),
      _card(
        'Missed renewals mean fines',
        'Trade licences, Emirates IDs, visas, insurance, Mulkiya. They live '
        'in WhatsApp threads and desk drawers, and every missed date '
        'converts straight into government fines and blocked services.',
      ),
      pw.SizedBox(height: 12),
      _card(
        'Money is scattered',
        'Receipts in shoeboxes, salaries in one sheet, supplier payments in '
        'another. Nobody can answer "what do we actually have left this '
        'month?" without an hour of archaeology.',
      ),
      pw.SizedBox(height: 12),
      _card(
        'Generic apps do not fit',
        'Global finance apps ignore renewals entirely. Document managers '
        'ignore money. GCC businesses need both in one place, speaking AED '
        'and Arabic-name reality.',
      ),
      pw.SizedBox(height: 24),
      _quote(
          'One missed trade licence can cost more than a year of FV - in '
          'fines alone.'),
    ],
  )));

  doc.addPage(_page_(pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _kicker('WHY IT WORKS'),
      pw.SizedBox(height: 10),
      _h1('Urgency, not alphabet.'),
      pw.SizedBox(height: 12),
      pw.Text(
        'Spreadsheets list documents by name. FV ranks them by how soon '
        'they bite: a live countdown, colored by urgency, with the renewal '
        'fee attached so the cash is planned too.',
        style: pw.TextStyle(color: PdfColors.white, fontSize: 12.5, height: 1.5),
      ),
      pw.SizedBox(height: 16),
      if (shot('05_expiry_list') != null)
        pw.Container(alignment: pw.Alignment.center, child: _phone(shot('05_expiry_list')!, width: 240)),
      pw.SizedBox(height: 14),
      _quote('Alerts fire at 90, 60, 30, 14, 7 and 1 day - you choose.'),
    ],
  )));

  // ── HOW ────────────────────────────────────────────────────────────────
  doc.addPage(_page_(pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _kicker('HOW'),
      pw.SizedBox(height: 10),
      _h1('Four steps. Zero spreadsheets.'),
      pw.SizedBox(height: 20),
      _step('1', 'Scan or add a document',
          'Point the camera at a trade licence, Emirates ID or visa. Files '
          'stay on your phone.'),
      pw.SizedBox(height: 14),
      _step('2', 'AI reads it for you',
          'Expiry date, renewal fee, vendor and document type are extracted '
          'automatically - no typing marathons.'),
      pw.SizedBox(height: 14),
      _step('3', 'Log money in one sentence',
          '"Spent 85 AED on Uber." FV picks the category, date and currency. '
          'Recurring bills log themselves.'),
      pw.SizedBox(height: 14),
      _step('4', 'Get warned, then relax',
          'Escalating reminders before every deadline, budget warnings as '
          'you approach limits, and a 90-day cash forecast.'),
      pw.SizedBox(height: 24),
      _quote('Setup takes minutes. The first alert usually saves a fine '
          'within the month.'),
    ],
  )));

  doc.addPage(_page_(pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _kicker('HOW IT IS BUILT'),
      pw.SizedBox(height: 10),
      _h1('Local-first. Private by design.'),
      pw.SizedBox(height: 12),
      pw.Text(
        'Your documents and records live on your device and sync to your '
        'private cloud account. Fast offline access, no vendor lock-in, and '
        'a one-tap export whenever you want out.',
        style: pw.TextStyle(color: PdfColors.white, fontSize: 12.5, height: 1.5),
      ),
      pw.SizedBox(height: 18),
      _bullet('Works fully offline - syncs when you reconnect.'),
      _bullet('We never sell your data or train public AI models on it.'),
      _bullet('Multi-company workspaces: one login, every entity tidy.'),
      _bullet('Built-in AI key to start; bring your own for deeper reads.'),
      pw.SizedBox(height: 20),
      if (shot('06_global_search') != null)
        pw.Container(alignment: pw.Alignment.center, child: _phone(shot('06_global_search')!, width: 230)),
      pw.SizedBox(height: 12),
      _quote('Find any document in seconds - by name, number or your own '
          'notes.'),
    ],
  )));

  // ── WHAT: one page per screen ─────────────────────────────────────────
  const screens = <(String, String, String, List<String>, String, PdfColor)>[
    (
      'WHAT - HOME',
      'Home base',
      'Open FV and see what needs attention today: documents nearing '
          'deadline, plan status, one-tap actions.',
      [
        'Urgency-sorted feed - what expires soonest floats to the top.',
        'Scan or log money in two taps from the quick-action grid.',
        'Everything important is one tap deep, never more.',
      ],
      '01_home',
      _indigoBright,
    ),
    (
      'WHAT - DOCUMENTS',
      'The document vault',
      'Trade licences, IDs, passports, visas, Mulkiya, insurance, contracts '
          '- one searchable place, per company or client.',
      [
        'Camera scan with AI extraction of dates, fees and vendors.',
        'Separate workspaces keep every entity and client tidy.',
        'Attach files, notes and renewal steps to each document.',
      ],
      '02_documents',
      _indigoBright,
    ),
    (
      'WHAT - MONEY',
      'Money, auto-organized',
      'Type or speak one sentence and the transaction is logged, '
          'categorized and dated against a UAE merchant dictionary.',
      [
        'Recurring rent, salaries and subscriptions auto-log when due.',
        'Anomaly alerts on 35%+ jumps in recurring costs.',
        'Everything categorized for clean month-end reviews.',
      ],
      '03_money',
      _indigoBright,
    ),
    (
      'WHAT - DOCUMENT DETAIL',
      'Every detail, one tap away',
      'Countdown, renewal fee, stored files and history for any document - '
          'renew, pay and share from one screen.',
      [
        'Live countdown with urgency color so nothing sneaks up.',
        'Log the renewal payment against the document in one tap.',
        'Share the file or export the details instantly.',
      ],
      '04_document_detail',
      _indigoBright,
    ),
    (
      'WHAT - DEADLINES',
      'Renewals ranked by urgency',
      'One ranked list of everything expiring across all your companies, '
          'with lead times you control.',
      [
        'Never pay an avoidable late-renewal fine again.',
        'Filter by company, type or urgency band.',
        'Export the list as CSV or PDF for your accountant.',
      ],
      '05_expiry_list',
      _emerald,
    ),
    (
      'WHAT - SEARCH',
      'Find anything in seconds',
      'Search across every document by name, number or notes - built for '
          'the "send me the licence now" moments.',
      [
        'Instant results across all workspaces.',
        'Search by plate number, licence ID or your own notes.',
        'Open, share or renew straight from the result.',
      ],
      '06_global_search',
      _indigoBright,
    ),
    (
      'WHAT - BUDGETS',
      'Budgets that warn you',
      'Set a monthly limit per category. FV tracks the burn and warns you '
          'as you approach it - before the money is gone.',
      [
        'Category budgets with proactive overspend warnings.',
        'Renewal fees fold into the plan automatically.',
        'Alerts arrive as notifications you can act on.',
      ],
      '07_budgets',
      _emerald,
    ),
    (
      'WHAT - ENVELOPES',
      'Envelope saving',
      'Set money aside for the things you know are coming: renewal season, '
          'Eid stock-ups, the new chiller.',
      [
        'One envelope per goal with progress at a glance.',
        'Move money between envelopes when priorities shift.',
        'Pairs with budgets for complete control.',
      ],
      '08_envelopes',
      _indigoBright,
    ),
    (
      'WHAT - RECORDS',
      'A clean ledger',
      'Every transaction, searchable and filterable. Your accountant will '
          'thank you - so will future-you in VAT season.',
      [
        'Filter by category, kind, date range or collection.',
        'Edit or duplicate entries in two taps.',
        'Export for bookkeeping whenever you need it.',
      ],
      '09_records',
      _indigoBright,
    ),
    (
      'WHAT - CASH FLOW',
      '90-day cash forecast',
      'Balance, recurring bills and renewal fees combined - see the tight '
          'weeks coming while there is time to act.',
      [
        'Sees renewal fees coming before they hit.',
        'Visual chart of the next 90 days.',
        'Plan hiring, stock and expansion on facts.',
      ],
      '10_cash_flow',
      _emerald,
    ),
    (
      'WHAT - AI SUMMARY',
      'Your executive brief',
      'FV reads your month and writes the summary a good CFO would: what '
          'changed, what is coming, what needs a decision.',
      [
        'Works out of the box; bring your own key for more depth.',
        'Executive tone, GCC context, zero setup.',
        'Regenerate anytime as new data lands.',
      ],
      '11_ai_summary',
      _indigoBright,
    ),
    (
      'WHAT - AI PLANNER',
      'Say the goal, get the plan',
      '"I want to buy a delivery van by March." The planner turns that '
          'into a monthly savings plan tracked in your budgets.',
      [
        'Natural-language goals become concrete monthly plans.',
        'Plans live in Budgets and warn you when you drift.',
        'Great for Hajj trips, equipment, expansions, stock-ups.',
      ],
      '12_ai_budget_plan',
      _indigoBright,
    ),
    (
      'WHAT - PROFILE',
      'Yours, and portable',
      'Workspaces, plan, backup and preferences in one hub - with a full '
          'data export, always.',
      [
        'One-tap data export: your data, take it anywhere.',
        'Reminder health check so alerts always reach you.',
        'Upgrade to Plus or Business when you outgrow Free.',
      ],
      '13_profile',
      _indigoBright,
    ),
    (
      'WHAT - ALERTS',
      'Reminders that fire',
      'A dedicated center for every alert: renewals, budget warnings, '
          'anomalies - tuned to how you work.',
      [
        '90/60/30/14/7/1-day escalation ladder for renewals.',
        'Notification deep links open the exact document.',
        'Set-up helper for notification permissions.',
      ],
      '14_alerts',
      _indigoBright,
    ),
  ];

  for (final s in screens) {
    doc.addPage(_screenPage(s.$1, s.$2, s.$3, s.$4, shot(s.$5), s.$6));
  }

  // ── Closing ────────────────────────────────────────────────────────────
  doc.addPage(_page_(pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _kicker('PRICING & NEXT STEP'),
      pw.SizedBox(height: 10),
      _h1('Be our first user.'),
      pw.SizedBox(height: 8),
      pw.Text(
        'You have now seen every screen. Here is how it ships:',
        style: pw.TextStyle(color: PdfColors.white, fontSize: 12.5),
      ),
      pw.SizedBox(height: 18),
      _tier('Free', 'AED 0',
          'Core document tracking, one workspace, manual money logging, '
          'renewal alerts. Everything a single company needs.'),
      pw.SizedBox(height: 10),
      _tier('Plus', 'monthly',
          'AI summaries, budget plans, multi-year history, advanced '
          'forecasts and priority support.'),
      pw.SizedBox(height: 10),
      _tier('Business', 'per seat',
          'Multi-company workspaces, team access, exports and reporting for '
          'accountants and PRO teams.'),
      pw.SizedBox(height: 22),
      pw.Container(
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(
          color: _white,
          borderRadius: pw.BorderRadius.circular(14),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _fvMark(size: 38),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: pw.Text(
                'Founding-user offer: onboarding, data import help and a '
                'direct line to the builder. Your feedback shapes the '
                'roadmap - and you keep it for free.',
                style: pw.TextStyle(
                  color: _indigoDeep,
                  fontSize: 11.5,
                  fontWeight: pw.FontWeight.bold,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 14),
      pw.Text('Made for the GCC. (c) 2026 Finavig.',
          style: pw.TextStyle(color: _indigoBright, fontSize: 9)),
    ],
  )));

  final file = File(outPath)
    ..createSync(recursive: true)
    ..writeAsBytesSync(await doc.save());
  print('Wrote ${file.path} (${(file.lengthSync() / 1024).ceil()} KB)');
}

pw.MemoryImage? _loadShot(String name) {
  final f = File('$_shotsDir/$name.png');
  if (!f.existsSync()) {
    print('WARNING: missing screenshot $_shotsDir/$name.png');
    return null;
  }
  return pw.MemoryImage(f.readAsBytesSync());
}

pw.Page _page_(pw.Widget child) {
  return pw.Page(
    pageFormat: _page,
    margin: const pw.EdgeInsets.all(_margin),
    build: (context) => pw.Container(
      decoration: const pw.BoxDecoration(
        gradient: pw.LinearGradient(
          begin: pw.Alignment.topCenter,
          end: pw.Alignment.bottomCenter,
          colors: [_indigoDeep, _ink],
        ),
      ),
      child: child,
    ),
  );
}

pw.Widget _kicker(String text, {PdfColor color = _indigoBright}) {
  return pw.Text(text.toUpperCase(),
      style: pw.TextStyle(
        color: color,
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
        letterSpacing: 2.2,
      ));
}

pw.Widget _h1(String text) {
  return pw.Text(text,
      style: pw.TextStyle(
        color: _white,
        fontSize: 27,
        fontWeight: pw.FontWeight.bold,
        height: 1.15,
      ));
}

pw.Widget _card(String title, String body) {
  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(16),
    decoration: pw.BoxDecoration(
      color: _white,
      borderRadius: pw.BorderRadius.circular(14),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title,
            style: pw.TextStyle(
              color: _indigoDeep,
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            )),
        pw.SizedBox(height: 6),
        pw.Text(body,
            style: pw.TextStyle(
              color: PdfColors.grey800,
              fontSize: 11,
              height: 1.45,
            )),
      ],
    ),
  );
}

pw.Widget _step(String no, String title, String body) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Container(
        width: 34,
        height: 34,
        alignment: pw.Alignment.center,
        decoration: pw.BoxDecoration(
          gradient: const pw.LinearGradient(
            colors: [_indigoBright, _indigo],
            begin: pw.Alignment.topLeft,
            end: pw.Alignment.bottomRight,
          ),
          borderRadius: pw.BorderRadius.circular(10),
        ),
        child: pw.Text(no,
            style: pw.TextStyle(
              color: _white,
              fontSize: 15,
              fontWeight: pw.FontWeight.bold,
            )),
      ),
      pw.SizedBox(width: 12),
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title,
                style: pw.TextStyle(
                  color: _white,
                  fontSize: 14.5,
                  fontWeight: pw.FontWeight.bold,
                )),
            pw.SizedBox(height: 4),
            pw.Text(body,
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 11.5,
                  height: 1.45,
                )),
          ],
        ),
      ),
    ],
  );
}

pw.Widget _bullet(String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 10),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          margin: const pw.EdgeInsets.only(top: 4),
          width: 7,
          height: 7,
          decoration: const pw.BoxDecoration(
            color: _indigoBright,
            shape: pw.BoxShape.circle,
          ),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          child: pw.Text(text,
              style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 11.5,
                height: 1.45,
              )),
        ),
      ],
    ),
  );
}

pw.Widget _quote(String text) {
  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(14),
    decoration: pw.BoxDecoration(
      borderRadius: pw.BorderRadius.circular(12),
      border: pw.Border.all(color: _indigoBright50),
    ),
    child: pw.Text(text,
        style: pw.TextStyle(
          color: _indigoBright,
          fontSize: 11.5,
          fontWeight: pw.FontWeight.bold,
          height: 1.45,
        )),
  );
}

pw.Widget _fvMark({double size = 46}) {
  return pw.Container(
    width: size,
    height: size,
    alignment: pw.Alignment.center,
    decoration: pw.BoxDecoration(
      borderRadius: pw.BorderRadius.circular(size * 0.24),
      gradient: const pw.LinearGradient(
        begin: pw.Alignment.topLeft,
        end: pw.Alignment.bottomRight,
        colors: [_indigoBright, _indigo],
      ),
    ),
    child: pw.Text('FV',
        style: pw.TextStyle(
          color: _white,
          fontSize: size * 0.4,
          fontWeight: pw.FontWeight.bold,
        )),
  );
}

/// Full-width phone screenshot with a thin glowing frame.
pw.Widget _phone(pw.MemoryImage image, {double width = 327}) {
  final height = width * 2622 / 1206;
  return pw.Container(
    width: width + 8,
    height: height + 8,
    padding: const pw.EdgeInsets.all(4),
    decoration: pw.BoxDecoration(
      borderRadius: pw.BorderRadius.circular(22),
      color: _ink,
      border: pw.Border.all(color: _indigoBright, width: 1.2),
    ),
    child: pw.ClipRRect(
      horizontalRadius: 18,
      verticalRadius: 18,
      child: pw.Image(image, fit: pw.BoxFit.cover),
    ),
  );
}

pw.Page _screenPage(
  String kicker,
  String title,
  String intro,
  List<String> bullets,
  pw.MemoryImage? shot,
  PdfColor accent,
) {
  return _page_(pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _kicker(kicker, color: accent),
      pw.SizedBox(height: 8),
      pw.Text(title,
          style: pw.TextStyle(
            color: _white,
            fontSize: 23,
            fontWeight: pw.FontWeight.bold,
          )),
      pw.SizedBox(height: 8),
      pw.Text(intro,
          style: pw.TextStyle(
            color: PdfColors.white,
            fontSize: 11.5,
            height: 1.45,
          )),
      pw.SizedBox(height: 12),
      for (final b in bullets) _bullet(b),
      pw.SizedBox(height: 8),
      if (shot != null)
        pw.Container(alignment: pw.Alignment.center, child: _phone(shot))
      else
        pw.Container(
          width: 327,
          height: 327 * 2622 / 1206,
          alignment: pw.Alignment.center,
          decoration: pw.BoxDecoration(
            borderRadius: pw.BorderRadius.circular(22),
            border: pw.Border.all(color: _indigoBright),
          ),
          child: pw.Text('screenshot',
              style: pw.TextStyle(color: _indigoBright, fontSize: 11)),
        ),
    ],
  ));
}

pw.Widget _tier(String name, String price, String body) {
  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(14),
    decoration: pw.BoxDecoration(
      borderRadius: pw.BorderRadius.circular(12),
      border: pw.Border.all(color: _indigoBright50),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(name,
                style: pw.TextStyle(
                  color: _white,
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                )),
            pw.Text(price,
                style: pw.TextStyle(color: _indigoBright, fontSize: 11)),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Text(body,
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 10.5,
              height: 1.4,
            )),
      ],
    ),
  );
}
