// ignore_for_file: avoid_print
/// Plain markdown -> PDF converter (A4 portrait, black on white, no colors).
/// Supports the subset used by PITCH.md: #/##/### headings, paragraphs,
/// **bold** spans, - lists, ![alt](path) images, --- rules.
///
/// Usage: dart run tool/md_to_pdf.dart PITCH.md [output.pdf]
/// Output defaults to <input>.pdf.
import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

Future<void> main(List<String> args) async {
  final input = args.isNotEmpty ? args.first : 'PITCH.md';
  final output = args.length > 1
      ? args[1]
      : '${File(input).uri.pathSegments.last.replaceAll('.md', '')}.pdf';

  final md = File(input).readAsStringSync();
  final doc = pw.Document();
  final bold = await pw.Font.helveticaBold();
  final regular = await pw.Font.helvetica();

  pw.TextStyle style({double size = 11, bool isBold = false}) => pw.TextStyle(
        font: isBold ? bold : regular,
        fontSize: size,
        color: PdfColors.black,
        height: 1.45,
      );

  /// Split a line into bold/plain text spans.
  List<pw.TextSpan> spans(String text, {double size = 11}) {
    final out = <pw.TextSpan>[];
    final re = RegExp(r'\*\*(.+?)\*\*');
    var cursor = 0;
    for (final m in re.allMatches(text)) {
      if (m.start > cursor) {
        out.add(pw.TextSpan(
            text: text.substring(cursor, m.start), style: style(size: size)));
      }
      out.add(pw.TextSpan(
          text: m.group(1),
          style: style(size: size, isBold: true)));
      cursor = m.end;
    }
    if (cursor < text.length) {
      out.add(pw.TextSpan(
          text: text.substring(cursor), style: style(size: size)));
    }
    return out;
  }

  pw.Widget? block(String raw) {
    final line = raw.trim();
    if (line.isEmpty) return pw.SizedBox(height: 6);
    if (line == '---') {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 8),
        child: pw.Container(
            height: 0.7, color: PdfColors.grey400),
      );
    }
    if (line.startsWith('### ')) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(top: 10, bottom: 4),
        child: pw.Text(line.substring(4),
            style: style(size: 13, isBold: true)),
      );
    }
    if (line.startsWith('## ')) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
        child: pw.Text(line.substring(3),
            style: style(size: 17, isBold: true)),
      );
    }
    if (line.startsWith('# ')) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(top: 6, bottom: 10),
        child: pw.Text(line.substring(2),
            style: style(size: 24, isBold: true)),
      );
    }
    final img = RegExp(r'!\[(.*?)\]\((.+?)\)').firstMatch(line);
    if (img != null) {
      final path = img.group(2)!;
      final f = File(path);
      if (!f.existsSync()) {
        print('WARNING: missing image $path');
        return pw.SizedBox(height: 6);
      }
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 6),
        child: pw.Center(
          child: pw.Image(
            pw.MemoryImage(f.readAsBytesSync()),
            width: 300,
            height: 300 * 2622 / 1206,
            fit: pw.BoxFit.cover,
          ),
        ),
      );
    }
    if (line.startsWith('- ')) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(left: 12, bottom: 4),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('•  ', style: style()),
            pw.Expanded(
              child: pw.RichText(text: pw.TextSpan(children: spans(line.substring(2)))),
            ),
          ],
        ),
      );
    }
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.RichText(text: pw.TextSpan(children: spans(line))),
    );
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(48),
      build: (context) => [
        for (final raw in md.split('\n'))
          if (block(raw) != null) block(raw)!,
      ],
    ),
  );

  final file = File(output)
    ..writeAsBytesSync(await doc.save());
  print('Wrote ${file.path} (${(file.lengthSync() / 1024).ceil()} KB)');
}
