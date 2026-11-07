import 'package:flutter/material.dart';
import '../theme/cupthread_theme.dart';

/// Lightweight Markdown renderer supporting headers, bullet lists, fenced code
/// blocks, bold, and inline code.
///
/// Line-level constructs:
/// - `# `, `## `, `### ` headers
/// - `- ` / `* ` bullet lists
/// - ```` ``` ```` fenced code blocks (the info string after the opening fence
///   is ignored; an unclosed fence renders the remaining lines as code)
///
/// Inline constructs (parsed within headers, bullets, and plain text):
/// - `**bold**` and `__bold__` render bold
/// - `` `code` `` renders as a monospace span with a subtle background;
///   markers inside a code span are never interpreted
///
/// Any other marker (e.g. `*italic*`) renders literally; the parser never
/// drops text.
class MarkdownText extends StatelessWidget {
  final String content;
  final TextStyle? style;

  const MarkdownText({
    super.key,
    required this.content,
    this.style,
  });

  /// Inline markers, tried left to right wherever they appear: a backtick
  /// code span wins over bold markers at the same position, and bold content
  /// is required to be non-empty so `****` renders literally.
  static final RegExp _inlineMarkers = RegExp(
    r'`([^`\n]+)`|\*\*([^*\n]+)\*\*|__([^_\n]+)__',
  );

  /// Parses inline bold and code spans into styled [TextSpan]s for a
  /// [Text.rich] whose parent [TextSpan] carries [base]. Text outside
  /// recognized markers is returned untouched.
  static List<InlineSpan> _parseInline(
    String text,
    CupThreadColors colors,
    TextStyle base,
  ) {
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in _inlineMarkers.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      final code = match[1];
      if (code != null) {
        spans.add(TextSpan(
          text: code,
          style: base.copyWith(
            fontFamily: 'monospace',
            color: colors.chipText,
            background: Paint()..color = colors.chipBg,
          ),
        ));
      } else {
        spans.add(TextSpan(
          text: match[2] ?? match[3],
          style: base.copyWith(fontWeight: FontWeight.bold),
        ));
      }
      cursor = match.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }
    return spans;
  }

  Widget _codeBlock(String code, CupThreadColors colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colors.chipBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        code,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          height: 1.4,
          color: colors.chipText,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (content.isEmpty) return const SizedBox.shrink();

    final colors = CupThreadTheme.of(context);
    final lines = content.split('\n');
    final widgets = <Widget>[];
    final bodyStyle = style ??
        TextStyle(
          fontSize: 14,
          height: 1.4,
          color: colors.textSecondary,
        );

    var i = 0;
    while (i < lines.length) {
      final line = lines[i];
      final trimmed = line.trim();

      if (trimmed.isEmpty) {
        widgets.add(const SizedBox(height: 8));
        i++;
        continue;
      }

      // Fenced code block: swallow lines until the closing fence (an unclosed
      // fence consumes the rest of the content, matching CommonMark).
      if (trimmed.startsWith('```')) {
        final codeLines = <String>[];
        i++;
        while (i < lines.length && !lines[i].trim().startsWith('```')) {
          codeLines.add(lines[i]);
          i++;
        }
        i++; // Skip the closing fence when present.
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: _codeBlock(codeLines.join('\n'), colors),
          ),
        );
        continue;
      }

      if (trimmed.startsWith('# ')) {
        final headerStyle = TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: colors.textPrimary,
        );
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text.rich(
              TextSpan(
                style: headerStyle,
                children: _parseInline(
                  trimmed.substring(2),
                  colors,
                  headerStyle,
                ),
              ),
            ),
          ),
        );
        i++;
        continue;
      }

      if (trimmed.startsWith('## ')) {
        final headerStyle = TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.bold,
          color: colors.textPrimary,
        );
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Text.rich(
              TextSpan(
                style: headerStyle,
                children: _parseInline(
                  trimmed.substring(3),
                  colors,
                  headerStyle,
                ),
              ),
            ),
          ),
        );
        i++;
        continue;
      }

      if (trimmed.startsWith('### ')) {
        final headerStyle = TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: colors.textPrimary,
        );
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text.rich(
              TextSpan(
                style: headerStyle,
                children: _parseInline(
                  trimmed.substring(4),
                  colors,
                  headerStyle,
                ),
              ),
            ),
          ),
        );
        i++;
        continue;
      }

      if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: TextStyle(color: colors.primary, fontSize: 16)),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: bodyStyle,
                      children: _parseInline(
                        trimmed.substring(2),
                        colors,
                        bodyStyle,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        i++;
        continue;
      }

      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text.rich(
            TextSpan(
              style: bodyStyle,
              children: _parseInline(line, colors, bodyStyle),
            ),
          ),
        ),
      );
      i++;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }
}
