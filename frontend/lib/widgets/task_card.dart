import 'package:flutter/material.dart';

import '../models/task.dart';
import 'task_title_highlight.dart';

Color _priorityStripeColor(TaskPriority p, ColorScheme scheme) {
  switch (p) {
    case TaskPriority.high:
      return scheme.error;
    case TaskPriority.medium:
      return scheme.tertiary;
    case TaskPriority.low:
      return scheme.primary;
  }
}

class TaskCard extends StatelessWidget {
  final Task task;
  final bool isBlocked;
  final String? blockedByTitle;
  final String titleHighlightQuery;
  final VoidCallback onEdit;
  final VoidCallback onRequestDelete;

  const TaskCard({
    super.key,
    required this.task,
    required this.isBlocked,
    this.blockedByTitle,
    this.titleHighlightQuery = '',
    required this.onEdit,
    required this.onRequestDelete,
  });

  @override
  Widget build(BuildContext context) {
    final due = formatDateOnly(task.dueDate);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final overdue = taskIsOverdue(task);
    final stripe = _priorityStripeColor(task.priority, scheme);

    final statusColor = switch (task.status) {
      TaskStatus.todo => scheme.primary,
      TaskStatus.inProgress => scheme.tertiary,
      TaskStatus.done => scheme.secondary,
    };

    final cardBg = isBlocked
        ? scheme.surfaceContainerHighest.withValues(alpha: 0.65)
        : overdue
            ? scheme.errorContainer.withValues(alpha: 0.35)
            : scheme.surface;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: cardBg,
        elevation: 0.5,
        shadowColor: scheme.shadow.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onEdit,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    color: stripe,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 4, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (overdue && task.status != TaskStatus.done)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  size: 18,
                                  color: scheme.error,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Overdue',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: scheme.error,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TaskTitleHighlight(
                                title: task.title,
                                query: titleHighlightQuery,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.circle,
                                    size: 8,
                                    color: statusColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    task.status.apiValue,
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      color: statusColor,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          task.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.78),
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 14,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.event_outlined,
                                  size: 18,
                                  color: scheme.onSurface.withValues(alpha: 0.6),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  due,
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: overdue
                                        ? scheme.error
                                        : scheme.onSurface.withValues(alpha: 0.75),
                                  ),
                                ),
                              ],
                            ),
                            if (task.isRecurring)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.repeat,
                                    size: 18,
                                    color: scheme.tertiary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    task.recurrenceType?.label ?? 'Recurring',
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: scheme.onSurface.withValues(alpha: 0.75),
                                    ),
                                  ),
                                ],
                              ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.flag_outlined,
                                  size: 18,
                                  color: stripe,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  task.priority.apiValue,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: scheme.onSurface.withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                            if (isBlocked)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.lock_outline,
                                    size: 18,
                                    color: scheme.onSurface.withValues(alpha: 0.55),
                                  ),
                                  const SizedBox(width: 4),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 180),
                                    child: Text(
                                      blockedByTitle != null &&
                                              blockedByTitle!.isNotEmpty
                                          ? 'Blocked by: $blockedByTitle'
                                          : 'Blocked',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.labelMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: scheme.onSurface.withValues(alpha: 0.65),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Delete task',
                  icon: Icon(Icons.delete_outline, color: scheme.outline),
                  onPressed: onRequestDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
