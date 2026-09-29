// ignore_for_file: avoid_print
/// Builds the Finavig user pitch PDF from live app screenshots captured by
/// tool/capture_pitch_shots.sh (integration_test/app_pitch_screenshots_test.dart).
///
/// Usage: dart run tool/build_pitch_pdf.dart [output.pdf]
/// Output defaults to docs/finavig-product-pitch.pdf.
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

const _shotsDir = 'build/pitch/shots';

Future<void> main(List<String> args) async {
  final outPath =
      args.isNotEmpty ? args.first : 'docs/finavig-product-pitch.pdf';

  final doc = pw.Document();
  pw.MemoryImage? shot(String name) => _loadShot(name);

  // ── Opening ────────────────────────────────────────────────────────────
  doc.addPage(_cover(shot('01_home')));
  doc.addPage(_problem());
  doc.addPage(_solution());

  // ── Part 1: Documents ─────────────────────────────────────────────────
  doc.addPage(_chapter('PART 1', 'Your documents, under control',
      'Every licence, ID and deadline in one vault - scanned, understood, '
      'and never missed again.'));
  doc.addPage(_screen(
    kicker: 'SCREEN - HOME',
    title: 'Home base: your day at a glance',
    intro:
        'The moment you open FV you see what needs attention: documents '
        'nearing deadline, plan status, and one-tap actions. Everything '
        'important is one tap deep, never more.',
    bullets: [
      'Urgency-sorted feed: what expires soonest floats to the top.',
      'Scan or log money in two taps from the quick-action grid.',
      'Works offline - your data lives on the device first.',
    ],
    shot: shot('01_home'),
  ));
  doc.addPage(_screen(
    kicker: 'SCREEN - DOCUMENTS',
    title: 'The company document vault',
    intro:
        'Trade licences, Emirates IDs, passports, visas, Mulkiya, insurance, '
        'contracts, subscriptions - all in one searchable place, organized '
        'per company or client.',
    bullets: [
      'Scan with the camera; AI extracts dates, fees and vendors.',
      'Separate workspaces keep every entity and client tidy.',
      'Attach files, notes and renewal steps to each document.',
    ],
    shot: shot('02_documents'),
  ));
  doc.addPage(_screen(
    kicker: 'SCREEN - DOCUMENT DETAIL',
    title: 'Every detail, ready when you need it',
    intro:
        'Open any document to see its expiry countdown, renewal fee, stored '
        'files and history. Renew it, log the payment, share it with your '
        'PRO - all from one screen.',
    bullets: [
      'Live countdown with urgency color so nothing sneaks up.',
      'Log the renewal payment against the document in one tap.',
      'Share the file or export the details instantly.',
    ],
    shot: shot('04_document_detail'),
  ));
  doc.addPage(_screen(
    kicker: 'SCREEN - DEADLINES',
    title: 'Renewals ranked by urgency',
    intro:
        'One ranked list of everything expiring across all your companies. '
        'FV alerts you at 90, 60, 30, 14, 7 and 1 day - lead times are '
        'customizable per document.',
    bullets: [
      'Never pay an avoidable late-renewal fine again.',
      'Filter by company, type or urgency band.',
      'Export the whole list as CSV or PDF for your accountant.',
    ],
    shot: shot('05_expiry_list'),
    accent: _emerald,
  ));
  doc.addPage(_screen(
    kicker: 'SCREEN - SEARCH',
    title: 'Find any document in seconds',
    intro:
        'Search across every document by name, number or notes. Perfect for '
        'the "send me the licence now" moments.',
    bullets: [
      'Instant results across all workspaces.',
      'Search by plate number, licence ID or your own notes.',
      'Open, share or renew straight from the result.',
    ],
    shot: shot('06_global_search'),
  ));

  // ── Part 2: Money ─────────────────────────────────────────────────────
  doc.addPage(_chapter('PART 2', 'Your money, finally clear',
      'GCC-currency bookkeeping that logs itself, warns you early, and '
      'answers "can we afford it?" before you commit.'));
  doc.addPage(_screen(
    kicker: 'SCREEN - MONEY',
    title: 'Income and expenses, auto-organized',
    intro:
        'Log money by typing or speaking one sentence - "Spent 85 AED on '
        'Uber". FV picks the category, date and currency automatically '
        'against a UAE merchant dictionary.',
    bullets: [
      'Recurring rent, salaries and subscriptions auto-log when due.',
      'Anomaly alerts on 35%+ jumps in recurring costs.',
      'Everything categorized for clean month-end reviews.',
    ],
    shot: shot('03_money'),
  ));
  doc.addPage(_screen(
    kicker: 'SCREEN - BUDGETS',
    title: 'Budgets that warn you, not scold you',
    intro:
        'Set a monthly limit per category. FV tracks the burn and warns you '
        'as you approach it - before the money is gone, not after.',
    bullets: [
      'Category budgets with proactive overspend warnings.',
      'Renewal fees fold into the plan automatically.',
      'Budget alerts arrive as notifications you can act on.',
    ],
    shot: shot('07_budgets'),
    accent: _emerald,
  ));
  doc.addPage(_screen(
    kicker: 'SCREEN - ENVELOPES',
    title: 'Envelope saving for big goals',
    intro:
        'Set money aside for the things you know are coming: renewal season, '
        'Eid stock-ups, the new chiller. Fill envelopes gradually and spend '
        'without stress.',
    bullets: [
      'One envelope per goal with progress at a glance.',
      'Move money between envelopes when priorities shift.',
      'Pairs with budgets for complete control.',
    ],
    shot: shot('08_envelopes'),
  ));
  doc.addPage(_screen(
    kicker: 'SCREEN - RECORDS',
    title: 'A clean ledger of everything',
    intro:
        'Every transaction, searchable and filterable. Your accountant will '
        'thank you - and so will future-you during VAT season.',
    bullets: [
      'Filter by category, kind, date range or collection.',
      'Edit or duplicate entries in two taps.',
      'Export for bookkeeping whenever you need it.',
    ],
    shot: shot('09_records'),
  ));
  doc.addPage(_screen(
    kicker: 'SCREEN - CASH FLOW',
    title: '90-day cash forecast',
    intro:
        'Bank balance, upcoming recurring bills and document renewal fees '
        'combined into one forecast - so you see the tight weeks coming '
        'while there is still time to act.',
    bullets: [
      'Sees renewal fees coming before they hit.',
      'Visual chart of the next 90 days.',
      'Plan hiring, stock and expansion on facts.',
    ],
    shot: shot('10_cash_flow'),
    accent: _emerald,
  ));

  // ── Part 3: AI ────────────────────────────────────────────────────────
  doc.addPage(_chapter('PART 3', 'Your AI copilot',
      'Not a gimmick: AI that does the boring parts of running a company - '
      'typing, categorizing, summarizing and planning.'));
  doc.addPage(_screen(
    kicker: 'SCREEN - AI SUMMARY',
    title: 'Your executive brief, generated',
    intro:
        'FV reads your month - spending, budgets, upcoming renewals - and '
        'writes the summary a good CFO would: what changed, what is coming, '
        'what needs a decision.',
    bullets: [
      'Works out of the box with a built-in key; bring your own for more.',
      'Executive tone, GCC context, zero setup.',
      'Regenerate anytime as new data lands.',
    ],
    shot: shot('11_ai_summary'),
  ));
  doc.addPage(_screen(
    kicker: 'SCREEN - AI PLANNER',
    title: 'Say the goal, get the plan',
    intro:
        '"I want to buy a delivery van by March." The AI budget planner '
        'turns that into a monthly savings plan and tracks it in your '
        'budgets automatically.',
    bullets: [
      'Natural-language goals become concrete monthly plans.',
      'Plans live in the Budgets tab and warn you when you drift.',
      'Great for Hajj trips, equipment, expansions, stock-ups.',
    ],
    shot: shot('12_ai_budget_plan'),
  ));

  // ── Part 4: Account ───────────────────────────────────────────────────
  doc.addPage(_chapter('PART 4', 'Yours, and private by design',
      'Local-first storage, your data exportable anytime, and reminders '
      'that actually reach you.'));
  doc.addPage(_screen(
    kicker: 'SCREEN - PROFILE',
    title: 'Your account and controls',
    intro:
        'Manage workspaces, plan, backup and preferences from one hub. '
        'Download your entire dataset as JSON whenever you want - no '
        'lock-in, ever.',
    bullets: [
      'One-tap data export: it is your data, take it anywhere.',
      'Reminder health check so alerts always reach you.',
      'Upgrade to Plus or Business when you outgrow Free.',
    ],
    shot: shot('13_profile'),
  ));
  doc.addPage(_screen(
    kicker: 'SCREEN - ALERTS',
    title: 'Reminders that actually fire',
    intro:
        'A dedicated center for every alert FV sends: renewals, budget '
        'warnings, anomalies. Tune lead times and channels to match how '
        'you work.',
    bullets: [
      '90/60/30/14/7/1-day escalation ladder for renewals.',
      'Notification deep links open the exact document.',
      'Set-up helper for notification permissions.',
    ],
    shot: shot('14_alerts'),
  ));

  // ── Closing ───────────────────────────────────────────────────────────
  doc.addPage(_closing());

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

pw.Page _darkScaffold({required pw.Widget child}) {
  return pw.Page(
    pageFormat: PdfPageFormat.a4.landscape,
    margin: pw.EdgeInsets.zero,
    build: (context) => pw.Container(
      decoration: const pw.BoxDecoration(
        gradient: pw.LinearGradient(
          begin: pw.Alignment.topLeft,
          end: pw.Alignment.bottomRight,
          colors: [_ink, _indigoDeep],
        ),
      ),
      child: pw.Padding(padding: const pw.EdgeInsets.all(40), child: child),
    ),
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
    child: pw.Text(
      'FV',
      style: pw.TextStyle(
        color: _white,
        fontSize: size * 0.4,
        fontWeight: pw.FontWeight.bold,
      ),
    ),
  );
}

pw.Widget _kicker(String text, {PdfColor color = _indigoBright}) {
  return pw.Text(
    text.toUpperCase(),
    style: pw.TextStyle(
      color: color,
      fontSize: 10,
      fontWeight: pw.FontWeight.bold,
      letterSpacing: 2.2,
    ),
  );
}

pw.Page _cover(pw.MemoryImage? home) {
  return _darkScaffold(
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              _fvMark(size: 64),
              pw.SizedBox(height: 26),
              pw.Text(
                'FINAVIG',
                style: pw.TextStyle(
                  color: _white,
                  fontSize: 44,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 6,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'F I N A N C I A L   &   D O C U M E N T   I N T E L L I G E N C E',
                style: pw.TextStyle(color: _indigoBright, fontSize: 11),
              ),
              pw.SizedBox(height: 28),
              pw.Text(
                'The command center for GCC businesses.',
                style: pw.TextStyle(
                  color: _white,
                  fontSize: 21,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Every screen in this deck is the live app running with demo '
                'data.\nDocument deadlines, company money and AI insights - '
                'one local-first app.',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 13,
                  lineSpacing: 4,
                ),
              ),
              pw.SizedBox(height: 30),
              pw.Container(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: pw.BoxDecoration(
                  borderRadius: pw.BorderRadius.circular(99),
                  border: pw.Border.all(color: _indigoBright, width: 1),
                ),
                child: pw.Text(
                  'USER PITCH  -  ALL SCREENS & USES',
                  style: pw.TextStyle(
                    color: _indigoBright,
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (home != null)
          _phoneFrame(home, width: 205)
        else
          pw.SizedBox(width: 205),
      ],
    ),
  );
}

pw.Page _problem() {
  pw.Widget card(String title, String body) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(20),
        decoration: pw.BoxDecoration(
          color: _white,
          borderRadius: pw.BorderRadius.circular(14),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(
                color: _indigoDeep,
                fontSize: 15,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              body,
              style: pw.TextStyle(
                color: PdfColors.grey800,
                fontSize: 11.5,
                lineSpacing: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  return _darkScaffold(
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _kicker('THE PROBLEM'),
        pw.SizedBox(height: 12),
        pw.Text(
          'Paper deadlines eat profits.',
          style: pw.TextStyle(
            color: _white,
            fontSize: 30,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          'Every GCC company juggles the same three failures - and the '
          'tools that should help were built for someone else.',
          style: pw.TextStyle(color: PdfColors.white, fontSize: 13),
        ),
        pw.SizedBox(height: 26),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            card(
              'Missed renewals mean fines',
              'Trade licences, Emirates IDs, visas, insurance, Mulkiya. '
              'They live in WhatsApp threads and desk drawers, and every '
              'missed date converts straight into government fines and '
              'blocked services.',
            ),
            pw.SizedBox(width: 16),
            card(
              'Money is scattered',
              'Receipts in shoeboxes, salaries in one sheet, supplier '
              'payments in another. Nobody can answer "what do we actually '
              'have left this month?" without an hour of archaeology.',
            ),
            pw.SizedBox(width: 16),
            card(
              'Generic apps do not fit',
              'Global finance apps ignore renewals entirely. Document '
              'managers ignore money. GCC businesses need both in one '
              'place, speaking AED and Arabic-name reality.',
            ),
          ],
        ),
      ],
    ),
  );
}

pw.Page _solution() {
  pw.Widget pillar(String no, String title, String body) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(18),
        decoration: pw.BoxDecoration(
          borderRadius: pw.BorderRadius.circular(14),
          border: pw.Border.all(color: _indigoBright50),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              no,
              style: pw.TextStyle(
                color: _indigoBright,
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              title,
              style: pw.TextStyle(
                color: _white,
                fontSize: 13.5,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              body,
              style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 10.5,
                lineSpacing: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  return _darkScaffold(
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _kicker('THE SOLUTION'),
        pw.SizedBox(height: 12),
        pw.Text(
          'One app. Four pillars. Fourteen screens.',
          style: pw.TextStyle(
            color: _white,
            fontSize: 30,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          'Finavig (FV) replaces the four or more disconnected tools GCC '
          'businesses juggle today. The next pages walk every screen and '
          'what it does for you.',
          style: pw.TextStyle(color: PdfColors.white, fontSize: 13),
        ),
        pw.SizedBox(height: 26),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pillar(
              '1',
              'Documents & expiry',
              'Scan, store and track every company document. Deadline '
              'alerts at 90/60/30/14/7/1 days, renewal fees included.',
            ),
            pw.SizedBox(width: 14),
            pillar(
              '2',
              'Money & budgets',
              'GCC-currency expenses and income, auto-categorized, with '
              'category budgets and a 90-day cash-flow forecast.',
            ),
            pw.SizedBox(width: 14),
            pillar(
              '3',
              'Multi-company',
              'Separate workspaces per entity or client, so PROs and '
              'accountants keep everyone organized in one login.',
            ),
            pw.SizedBox(width: 14),
            pillar(
              '4',
              'AI built in',
              'Ask FV AI logs money or documents from one sentence. '
              'Executive summaries and budget plans, generated.',
            ),
          ],
        ),
        pw.SizedBox(height: 22),
        pw.Container(
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            color: _white,
            borderRadius: pw.BorderRadius.circular(12),
          ),
          child: pw.Text(
            'Local-first by design: your documents and records live on your '
            'device and sync to your private cloud account - fast offline '
            'access, no vendor lock-in, data export anytime.',
            style: pw.TextStyle(
              color: _indigoDeep,
              fontSize: 11.5,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );
}

pw.Page _chapter(String part, String title, String intro) {
  return _darkScaffold(
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.center,
      children: [
        _kicker(part),
        pw.SizedBox(height: 14),
        pw.Text(
          title,
          style: pw.TextStyle(
            color: _white,
            fontSize: 36,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 14),
        pw.SizedBox(
          width: 320,
          child: pw.Text(
            intro,
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 14,
              lineSpacing: 5,
            ),
          ),
        ),
      ],
    ),
  );
}

pw.Widget _phoneFrame(pw.MemoryImage image, {double width = 216}) {
  final height = width * 2622 / 1206;
  return pw.Container(
    width: width + 10,
    height: height + 10,
    padding: const pw.EdgeInsets.all(5),
    decoration: pw.BoxDecoration(
      borderRadius: pw.BorderRadius.circular(26),
      color: _ink,
      border: pw.Border.all(color: _indigoBright, width: 1.2),
    ),
    child: pw.ClipRRect(
      horizontalRadius: 21,
      verticalRadius: 21,
      child: pw.Image(image, fit: pw.BoxFit.cover),
    ),
  );
}

pw.Page _screen({
  required String kicker,
  required String title,
  required String intro,
  required List<String> bullets,
  pw.MemoryImage? shot,
  PdfColor accent = _indigoBright,
}) {
  return _darkScaffold(
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              _kicker(kicker, color: accent),
              pw.SizedBox(height: 10),
              pw.Text(
                title,
                style: pw.TextStyle(
                  color: _white,
                  fontSize: 25,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                intro,
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 12.5,
                  lineSpacing: 4,
                ),
              ),
              pw.SizedBox(height: 18),
              for (final b in bullets)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 10),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        margin: const pw.EdgeInsets.only(top: 4),
                        width: 7,
                        height: 7,
                        decoration: pw.BoxDecoration(
                          color: accent,
                          shape: pw.BoxShape.circle,
                        ),
                      ),
                      pw.SizedBox(width: 10),
                      pw.Expanded(
                        child: pw.Text(
                          b,
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 11.5,
                            lineSpacing: 3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        pw.SizedBox(width: 18),
        if (shot != null)
          _phoneFrame(shot)
        else
          pw.Container(
            width: 216,
            height: 216 * 2622 / 1206,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
              borderRadius: pw.BorderRadius.circular(26),
              border: pw.Border.all(color: _indigoBright),
            ),
            child: pw.Text(
              'screenshot',
              style: pw.TextStyle(color: _indigoBright, fontSize: 11),
            ),
          ),
      ],
    ),
  );
}

pw.Page _closing() {
  pw.Widget tier(String name, String price, String body) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(
          borderRadius: pw.BorderRadius.circular(12),
          border: pw.Border.all(color: _indigoBright50),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              name,
              style: pw.TextStyle(
                color: _white,
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              price,
              style: pw.TextStyle(color: _indigoBright, fontSize: 11),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              body,
              style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 10,
                lineSpacing: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  return _darkScaffold(
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _kicker('PRICING & NEXT STEP'),
        pw.SizedBox(height: 12),
        pw.Text(
          'Be our first user.',
          style: pw.TextStyle(
            color: _white,
            fontSize: 30,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'You have now seen every screen. Here is how it ships:',
          style: pw.TextStyle(color: PdfColors.white, fontSize: 12.5),
        ),
        pw.SizedBox(height: 20),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            tier(
              'Free',
              'AED 0',
              'Core document tracking, one workspace, manual money logging, '
              'renewal alerts. Everything a single company needs to start.',
            ),
            pw.SizedBox(width: 14),
            tier(
              'Plus',
              'monthly',
              'AI summaries, budget plans, multi-year history, advanced '
              'forecasts and priority support.',
            ),
            pw.SizedBox(width: 14),
            tier(
              'Business',
              'per seat',
              'Multi-company workspaces, team access, exports and reporting '
              'for accountants and PRO teams.',
            ),
          ],
        ),
        pw.SizedBox(height: 24),
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            color: _white,
            borderRadius: pw.BorderRadius.circular(12),
          ),
          child: pw.Row(
            children: [
              _fvMark(size: 40),
              pw.SizedBox(width: 14),
              pw.Expanded(
                child: pw.Text(
                  'Founding-user offer: onboarding, data import help and a '
                  'direct line to the builder. Your feedback shapes the '
                  'roadmap - and you keep it for free.',
                  style: pw.TextStyle(
                    color: _indigoDeep,
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          'Made for the GCC. (c) 2026 Finavig.',
          style: pw.TextStyle(color: _indigoBright, fontSize: 9),
        ),
      ],
    ),
  );
}
