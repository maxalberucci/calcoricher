import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../utils/url_safety.dart';

/// Leichtgewichtiger Markdown-Renderer für die App-eigenen Rechtstexte.
///
/// Bewusst nur eine kleine, kontrollierte Teilmenge (wir steuern die Quelle
/// selbst, siehe `assets/legal/`): Überschriften `#`/`##`/`###`, Aufzählungen
/// `- `, Zitate `> `, Trennlinien `---`, Codeblöcke ```` ``` ````, einfache
/// Tabellen `| … |` sowie inline `**fett**`, ``code`` und sichere
/// `[Text](https://…)`-Links. So sparen wir eine zusätzliche Abhängigkeit.
class MarkdownLite extends StatefulWidget {
  final String data;

  const MarkdownLite(this.data, {super.key});

  @override
  State<MarkdownLite> createState() => _MarkdownLiteState();
}

class _MarkdownLiteState extends State<MarkdownLite> {
  final List<TapGestureRecognizer> _recognizers = [];
  late List<Widget> _blocks;

  @override
  void initState() {
    super.initState();
    _blocks = _parse(widget.data);
  }

  @override
  void didUpdateWidget(MarkdownLite oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _disposeRecognizers();
      _blocks = _parse(widget.data);
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _blocks,
    );
  }

  // --- Parser --------------------------------------------------------------

  List<Widget> _parse(String data) {
    final lines = data.replaceAll('\r\n', '\n').split('\n');
    final blocks = <Widget>[];
    final paragraph = <String>[];

    void flushParagraph() {
      if (paragraph.isEmpty) return;
      blocks.add(Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text.rich(
          _inline(paragraph.join(' ')),
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 14,
            height: 1.55,
          ),
        ),
      ));
      paragraph.clear();
    }

    for (var i = 0; i < lines.length; i++) {
      final raw = lines[i];
      final line = raw.trimRight();
      final trimmed = line.trim();

      // Leerzeile -> Absatzgrenze.
      if (trimmed.isEmpty) {
        flushParagraph();
        continue;
      }

      // Codeblock ```
      if (trimmed.startsWith('```')) {
        flushParagraph();
        final code = <String>[];
        i++;
        while (i < lines.length && !lines[i].trim().startsWith('```')) {
          code.add(lines[i]);
          i++;
        }
        blocks.add(_codeBlock(code.join('\n')));
        continue;
      }

      // Trennlinie ---
      if (trimmed == '---' || trimmed == '***') {
        flushParagraph();
        blocks.add(const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Divider(color: AppTheme.divider, height: 1),
        ));
        continue;
      }

      // Überschriften
      if (trimmed.startsWith('### ')) {
        flushParagraph();
        blocks.add(_heading(trimmed.substring(4), 3));
        continue;
      }
      if (trimmed.startsWith('## ')) {
        flushParagraph();
        blocks.add(_heading(trimmed.substring(3), 2));
        continue;
      }
      if (trimmed.startsWith('# ')) {
        flushParagraph();
        blocks.add(_heading(trimmed.substring(2), 1));
        continue;
      }

      // Aufzählung
      if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        flushParagraph();
        blocks.add(_bullet(trimmed.substring(2)));
        continue;
      }

      // Zitat / Hinweis (zusammenhängende > … Zeilen)
      if (trimmed.startsWith('>')) {
        flushParagraph();
        final quote = <String>[];
        while (i < lines.length && lines[i].trim().startsWith('>')) {
          quote.add(lines[i].trim().replaceFirst(RegExp(r'^>\s?'), ''));
          i++;
        }
        i--;
        blocks.add(_quote(quote.join(' ')));
        continue;
      }

      // Tabelle (zusammenhängende Zeilen mit |)
      if (trimmed.startsWith('|') && trimmed.endsWith('|')) {
        flushParagraph();
        final rows = <String>[];
        while (i < lines.length && lines[i].trim().startsWith('|')) {
          rows.add(lines[i].trim());
          i++;
        }
        i--;
        blocks.add(_table(rows));
        continue;
      }

      paragraph.add(trimmed);
    }
    flushParagraph();
    return blocks;
  }

  // --- Block-Builder -------------------------------------------------------

  Widget _heading(String text, int level) {
    final size = switch (level) { 1 => 24.0, 2 => 18.0, _ => 15.0 };
    return Padding(
      padding: EdgeInsets.only(top: level == 1 ? 4 : 18, bottom: 8),
      child: Text.rich(
        _inline(text),
        style: AppTheme.serif(TextStyle(
          color: AppTheme.gold,
          fontSize: size,
          fontWeight: FontWeight.bold,
          height: 1.25,
        )),
      ),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2, right: 8),
            child: Icon(Icons.circle, size: 6, color: AppTheme.gold),
          ),
          Expanded(
            child: Text.rich(
              _inline(text),
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quote(String text) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.gold.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: const Border(
          left: BorderSide(color: AppTheme.gold, width: 3),
        ),
      ),
      child: Text.rich(
        _inline(text),
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 13.5,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _codeBlock(String code) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.divider),
      ),
      child: SelectableText(
        code,
        style: const TextStyle(
          color: AppTheme.champagne,
          fontFamily: 'monospace',
          fontSize: 13,
          height: 1.45,
        ),
      ),
    );
  }

  Widget _table(List<String> rows) {
    List<String> cells(String row) {
      final parts = row.split('|');
      // Erste/letzte (leer durch Rand-Pipes) entfernen.
      if (parts.isNotEmpty && parts.first.trim().isEmpty) parts.removeAt(0);
      if (parts.isNotEmpty && parts.last.trim().isEmpty) {
        parts.removeLast();
      }
      return parts.map((c) => c.trim()).toList();
    }

    bool isSeparator(String row) =>
        cells(row).every((c) => RegExp(r'^:?-{2,}:?$').hasMatch(c));

    final dataRows = rows.where((r) => !isSeparator(r)).toList();
    if (dataRows.isEmpty) return const SizedBox.shrink();

    final header = cells(dataRows.first);
    final body = dataRows.skip(1).map(cells).toList();

    TableRow buildRow(List<String> values, {required bool head}) {
      return TableRow(
        decoration: head
            ? BoxDecoration(color: AppTheme.gold.withValues(alpha: 0.10))
            : null,
        children: List.generate(header.length, (c) {
          final value = c < values.length ? values[c] : '';
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Text.rich(
              _inline(value),
              style: TextStyle(
                color: head ? AppTheme.gold : AppTheme.textPrimary,
                fontSize: 12.5,
                height: 1.4,
                fontWeight: head ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        }),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.divider),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Table(
          border: const TableBorder.symmetric(
            inside: BorderSide(color: AppTheme.divider, width: 0.5),
          ),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            buildRow(header, head: true),
            for (final row in body) buildRow(row, head: false),
          ],
        ),
      ),
    );
  }

  // --- Inline-Parser (**fett**, `code`, [Text](url)) -----------------------

  TextSpan _inline(String text) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(
      r'\*\*(.+?)\*\*|`([^`]+?)`|\[([^\]]+?)\]\((https?:\/\/[^\s)]+)\)',
    );

    var index = 0;
    for (final m in pattern.allMatches(text)) {
      if (m.start > index) {
        spans.add(TextSpan(text: text.substring(index, m.start)));
      }
      if (m.group(1) != null) {
        spans.add(TextSpan(
          text: m.group(1),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.platinum,
          ),
        ));
      } else if (m.group(2) != null) {
        spans.add(TextSpan(
          text: m.group(2),
          style: const TextStyle(
            fontFamily: 'monospace',
            color: AppTheme.champagne,
            fontSize: 13,
          ),
        ));
      } else {
        final label = m.group(3)!;
        final url = m.group(4)!;
        spans.add(_link(label, url));
      }
      index = m.end;
    }
    if (index < text.length) {
      spans.add(TextSpan(text: text.substring(index)));
    }
    return TextSpan(children: spans);
  }

  InlineSpan _link(String label, String url) {
    final recognizer = TapGestureRecognizer()..onTap = () => _openUrl(url);
    _recognizers.add(recognizer);
    return TextSpan(
      text: label,
      style: const TextStyle(
        color: AppTheme.gold,
        decoration: TextDecoration.underline,
        decorationColor: AppTheme.goldDark,
      ),
      recognizer: recognizer,
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !UrlSafety.isSafeWebUri(uri)) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
