// ignore_for_file: avoid_print
/// Builds the Finavig product pitch PDF from live app screenshots captured
/// by tool/capture_pitch_shots.sh (integration_test/app_pitch_screenshots_test.dart).
///
/// Usage: dart run tool/build_pitch_pdf.dart [output.pdf]
/// Output defaults to docs/finavig-product-pitch.pdf.
import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

const _indigo = PdfColor.fromInt(0xFF4F46E5);
const _indigoDeep = PdfColor.fromInt(0xFF312E81);
const _indigoBright = PdfColor.fromInt(0xFF818CF8);
const _emerald = PdfColor.fromInt(0xFF10B981);
const _indigoBright50 = PdfColor.fromInt(0x80818CF8); // 50% alpha
const _ink = PdfColor.fromInt(0xFF0C0E14);
const _white = PdfColors.white;

const _shotsDir = 'build/pitch/shots';

Future<void> main(List<String> args) async {
  final outPath = args.isNotEmpty
      ? args.first
      : 'docs/finavig-product-pitch.pdf';

  final doc = pw.Document();

  final shots = <String, pw.MemoryImage?>{
    '01_home': _loadShot('01_home'),
    '02_documents': _loadShot('02_documents'),
    '03_money': _loadShot('03_money'),
    '04_expiry_list': _loadShot('04_expiry_list'),
    '05_budgets': _loadShot('05_budgets'),
    '06_ai_summary': _loadShot('06_ai_summary'),
  };

  final home = shots['01_home'];
  if (home != null) {
    doc.addPage(_cover(home));
  } else {
    doc.addPage(_cover(null));
  }
  doc.addPage(_problem());
  doc.addPage(_solution());

  doc.addPage(_shotPage(
    kicker: 'LIVE SCREEN - HOME',
    title: 'Your whole business day, on one screen',
    intro:
        'Open FV and see everything that needs attention today: documents '
        'approaching their deadline, cash position, and quick actions. No '
        'digging through folders.',
    bullets: [
      'Urgency rings surface documents by deadline, not alphabet.',
      'Quick actions: scan a document or log money in two taps.',
      'Hold the sparkle button to talk - Ask FV AI does the typing.',
    ],
    shot: shots['01_home'],
  ));

  doc.addPage(_shotPage(
    kicker: 'LIVE SCREEN - DOCUMENTS',
    title: 'Every licence, ID and visa in one vault',
    intro:
        'Trade licences, Emirates IDs, passports, visas, Mulkiya, insurance, '
        'contracts. Scan with the camera and the AI extracts the dates, '
        'amounts and vendors for you.',
    bullets: [
      'OCR scan: point the camera, get structured data back.',
      'Multi-company workspaces keep client entities separate.',
      'Files stay on your phone; nothing is sold or shared.',
    ],
    shot: shots['02_documents'],
  ));

  doc.addPage(_shotPage(
    kicker: 'LIVE SCREEN - DEADLINES',
    title: 'Renewal alerts before the fines do',
    intro:
        'FV watches every expiry and warns you at 90, 60, 30, 14, 7 and 1 '
        'day. Lead times are customizable, and each document tracks its '
        'renewal fee so you can plan the cash.',
    bullets: [
      'A single ranked list of what expires next across all entities.',
      'Renewal fees feed straight into your cash-flow forecast.',
      'Log the renewal payment against the document in one tap.',
    ],
    shot: shots['04_expiry_list'],
    accent: _emerald,
  ));

  doc.addPage(_shotPage(
    kicker: 'LIVE SCREEN - MONEY',
    title: 'Money in and money out, finally organized',
    intro:
        'Expenses and income in GCC currencies, auto-categorized against a '
        'UAE merchant dictionary. Recurring bills log themselves, and '
        'sudden price jumps raise a flag.',
    bullets: [
      'Say it once: "Spent 85 AED on Uber" - category and date handled.',
      'Recurring rent, salaries and subscriptions auto-log when due.',
      'Anomaly detection alerts on 35%+ jumps in recurring costs.',
    ],
    shot: shots['03_money'],
  ));

  doc.addPage(_shotPage(
    kicker: 'LIVE SCREEN - BUDGETS',
    title: 'Budgets that warn you before you overspend',
    intro:
        'Set a monthly limit per category and FV tracks the burn, warns you '
        'as you approach it, and folds everything into a 90-day cash-flow '
        'forecast.',
    bullets: [
      'Category envelopes with proactive overspend warnings.',
      '90-day cash forecast: balance, bills, renewals combined.',
      'Budget alerts delivered as notifications, not nag screens.',
    ],
    shot: shots['05_budgets'],
    accent: _emerald,
  ));

  doc.addPage(_shotPage(
    kicker: 'LIVE SCREEN - AI',
    title: 'An executive summary, generated for you',
    intro:
        'FV reads your month - spending, budgets, upcoming renewals - and '
        'writes the executive brief: what changed, what is coming, what to '
        'decide.',
    bullets: [
      'AI budget planner turns "I want to buy X" into a savings plan.',
      'Smart templates work out of the box; bring your own key for more.',
      'One-tap expense and income logging from natural language.',
    ],
    shot: shots['06_ai_summary'],
  ));

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

pw.Page _darkScaffold({
  required pw.Widget child,
}) {
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
                'Document deadlines, company money and AI insights in one '
                'local-first app.\nBuilt in the UAE, for the way business '
                'actually runs here.',
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
                  'PRODUCT PITCH  -  FIRST LOOK',
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
          'One app. Four pillars.',
          style: pw.TextStyle(
            color: _white,
            fontSize: 30,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          'Finavig (FV) unifies what GCC businesses juggle today across '
          'four or more disconnected tools.',
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

pw.Page _shotPage({
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
          'Every screen in this deck is the live app running with demo data - '
          'not mockups. Here is how it ships:',
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
