enum TaskStatus {
  todo,
  inProgress,
  done,
}

extension TaskStatusX on TaskStatus {
  String get apiValue {
    switch (this) {
      case TaskStatus.todo:
        return 'To-Do';
      case TaskStatus.inProgress:
        return 'In Progress';
      case TaskStatus.done:
        return 'Done';
    }
  }
}

TaskStatus taskStatusFromApi(String value) {
  switch (value) {
    case 'To-Do':
      return TaskStatus.todo;
    case 'In Progress':
      return TaskStatus.inProgress;
    case 'Done':
      return TaskStatus.done;
    default:
      return TaskStatus.todo;
  }
}

enum TaskPriority {
  high,
  medium,
  low,
}

extension TaskPriorityX on TaskPriority {
  String get apiValue {
    switch (this) {
      case TaskPriority.high:
        return 'High';
      case TaskPriority.medium:
        return 'Medium';
      case TaskPriority.low:
        return 'Low';
    }
  }

  String get shortLabel {
    switch (this) {
      case TaskPriority.high:
        return 'High';
      case TaskPriority.medium:
        return 'Med';
      case TaskPriority.low:
        return 'Low';
    }
  }
}

TaskPriority taskPriorityFromApi(String? value) {
  switch (value) {
    case 'High':
      return TaskPriority.high;
    case 'Low':
      return TaskPriority.low;
    case 'Medium':
    default:
      return TaskPriority.medium;
  }
}

enum RecurrenceType {
  daily,
  weekly,
}

extension RecurrenceTypeX on RecurrenceType {
  String get apiValue {
    switch (this) {
      case RecurrenceType.daily:
        return 'daily';
      case RecurrenceType.weekly:
        return 'weekly';
    }
  }

  String get label {
    switch (this) {
      case RecurrenceType.daily:
        return 'Daily';
      case RecurrenceType.weekly:
        return 'Weekly';
    }
  }
}

RecurrenceType? recurrenceTypeFromApi(String? value) {
  switch (value) {
    case 'daily':
      return RecurrenceType.daily;
    case 'weekly':
      return RecurrenceType.weekly;
    default:
      return null;
  }
}

/// True when due date is before today (local) and task is not Done.
bool taskIsOverdue(Task task) {
  if (task.status == TaskStatus.done) return false;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final due = DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
  return due.isBefore(today);
}

String formatDateOnly(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)}';
}

DateTime parseDateOnly(String iso) {
  final parts = iso.split('-');
  if (parts.length != 3) {
    return DateTime.parse(iso);
  }
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}

class Task {
  final int id;
  final String title;
  final String description;
  final DateTime dueDate;
  final TaskStatus status;
  final TaskPriority priority;
  final bool isRecurring;
  final RecurrenceType? recurrenceType;
  final int position;
  final int? blockedById;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.dueDate,
    required this.status,
    required this.priority,
    this.isRecurring = false,
    this.recurrenceType,
    this.position = 0,
    required this.blockedById,
  });

  Task copyWith({
    int? id,
    String? title,
    String? description,
    DateTime? dueDate,
    TaskStatus? status,
    TaskPriority? priority,
    bool? isRecurring,
    RecurrenceType? recurrenceType,
    int? position,
    int? blockedById,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      isRecurring: isRecurring ?? this.isRecurring,
      recurrenceType: recurrenceType ?? this.recurrenceType,
      position: position ?? this.position,
      blockedById: blockedById ?? this.blockedById,
    );
  }

  factory Task.fromJson(Map<String, dynamic> json) {
    final dueDateStr = json['due_date'] as String;
    return Task(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String,
      dueDate: parseDateOnly(dueDateStr),
      status: taskStatusFromApi(json['status'] as String),
      priority: taskPriorityFromApi(json['priority'] as String?),
      isRecurring: json['is_recurring'] as bool? ?? false,
      recurrenceType: recurrenceTypeFromApi(json['recurrence_type'] as String?),
      position: json['position'] as int? ?? 0,
      blockedById: json['blocked_by_id'] as int?,
    );
  }
}
