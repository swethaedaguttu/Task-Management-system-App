import 'package:flutter/material.dart';

/// Builds a single-line title with case-insensitive highlight of [query] segments.
class TaskTitleHighlight extends StatelessWidget {
  final String title;
  final String query;
  final TextStyle? style;

  const TaskTitleHighlight({
    super.key,
    required this.title,
    required this.query,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = style ??
        theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700);
    final q = query.trim();
    if (q.isEmpty) {
      return Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: baseStyle,
      );
    }

    final lowerTitle = title.toLowerCase();
    final lowerQ = q.toLowerCase();
    final spans = <InlineSpan>[];
    var start = 0;
    var idx = lowerTitle.indexOf(lowerQ, start);
    while (idx >= 0) {
      if (idx > start) {
        spans.add(TextSpan(text: title.substring(start, idx), style: baseStyle));
      }
      final matchEnd = idx + lowerQ.length;
      spans.add(
        TextSpan(
          text: title.substring(idx, matchEnd),
          style: baseStyle?.copyWith(
            backgroundColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.85),
            fontWeight: FontWeight.w800,
          ),
        ),
      );
      start = matchEnd;
      idx = lowerTitle.indexOf(lowerQ, start);
    }
    if (start < title.length) {
      spans.add(TextSpan(text: title.substring(start), style: baseStyle));
    }

    return Text.rich(
      TextSpan(children: spans),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
