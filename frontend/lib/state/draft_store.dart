import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/task.dart';

class TaskCreateDraft {
  final String title;
  final String description;
  final DateTime dueDate;
  final TaskStatus status;
  final TaskPriority priority;
  final bool isRecurring;
  final RecurrenceType? recurrenceType;
  final int? blockedById;

  TaskCreateDraft({
    required this.title,
    required this.description,
    required this.dueDate,
    required this.status,
    required this.priority,
    this.isRecurring = false,
    this.recurrenceType,
    required this.blockedById,
  });
}

class DraftStore {
  static const String _key = 'task_create_draft_v4';
  static const String _legacyV3 = 'task_create_draft_v3';
  static const String _legacyV2 = 'task_create_draft_v2';

  Future<TaskCreateDraft?> loadCreateDraft() async {
    final prefs = await SharedPreferences.getInstance();
    var raw = prefs.getString(_key);
    raw ??= prefs.getString(_legacyV3);
    if (raw == null) return null;

    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final dueDateRaw = decoded['dueDate'] as String?;
    final dueDate = dueDateRaw == null ? null : parseDateOnly(dueDateRaw);
    if (dueDate == null) return null;

    return TaskCreateDraft(
      title: decoded['title'] as String? ?? '',
      description: decoded['description'] as String? ?? '',
      dueDate: dueDate,
      status: taskStatusFromApi(decoded['status'] as String? ?? 'To-Do'),
      priority: taskPriorityFromApi(decoded['priority'] as String?),
      isRecurring: decoded['isRecurring'] as bool? ?? false,
      recurrenceType: recurrenceTypeFromApi(decoded['recurrenceType'] as String?),
      blockedById: decoded['blockedById'] as int?,
    );
  }

  Future<void> saveCreateDraft(TaskCreateDraft draft) async {
    final prefs = await SharedPreferences.getInstance();
    final dueStr = formatDateOnly(draft.dueDate);
    await prefs.setString(
      _key,
      jsonEncode({
        'title': draft.title,
        'description': draft.description,
        'dueDate': dueStr,
        'status': draft.status.apiValue,
        'priority': draft.priority.apiValue,
        'isRecurring': draft.isRecurring,
        'recurrenceType': draft.recurrenceType?.apiValue,
        'blockedById': draft.blockedById,
      }),
    );
    await prefs.remove(_legacyV3);
    await prefs.remove(_legacyV2);
  }

  /// Removes current and legacy keys so no stale draft survives after a successful create.
  Future<void> clearCreateDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await prefs.remove(_legacyV3);
    await prefs.remove(_legacyV2);
    try {
      await prefs.reload();
    } catch (_) {
      // reload not supported on all platforms
    }
  }
}
