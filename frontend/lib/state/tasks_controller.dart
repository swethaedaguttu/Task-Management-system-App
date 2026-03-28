import 'package:flutter/foundation.dart';

import '../models/task.dart';
import '../services/api_client.dart';

class TasksController extends ChangeNotifier {
  final ApiClient apiClient;

  final List<Task> _tasks = [];
  /// True until the first [refresh] completes so the list does not flash “empty” on cold start.
  bool _isLoading = true;
  String? _error;

  /// Last search/filter sent to the API (used for highlighting matches in the list).
  String _searchQuery = '';
  TaskStatus? _statusFilter;
  TaskPriority? _priorityFilter;

  TasksController({required this.apiClient});

  List<Task> get tasks => List.unmodifiable(_tasks);
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  TaskStatus? get statusFilter => _statusFilter;
  TaskPriority? get priorityFilter => _priorityFilter;

  /// Drag-and-drop reorder updates global order; only valid when the list shows all tasks.
  bool get canReorder =>
      _searchQuery.trim().isEmpty &&
      _statusFilter == null &&
      _priorityFilter == null;

  void setListFilters({
    required String searchQuery,
    TaskStatus? statusFilter,
    TaskPriority? priorityFilter,
  }) {
    _searchQuery = searchQuery;
    _statusFilter = statusFilter;
    _priorityFilter = priorityFilter;
    notifyListeners();
  }

  Future<void> refresh() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final q = _searchQuery.trim();
      final loaded = await apiClient.fetchTasks(
        q: q.isEmpty ? null : q,
        status: _statusFilter,
        priority: _priorityFilter,
      );
      _tasks
        ..clear()
        ..addAll(loaded);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Optimistic UI update before [commitReorder] completes.
  void reorderLocal(List<Task> newOrder) {
    _tasks
      ..clear()
      ..addAll(newOrder);
    notifyListeners();
  }

  Future<void> commitReorder(List<int> orderedIds) async {
    await apiClient.reorderTasks(orderedIds);
    await refresh();
  }

  Future<void> deleteTask(int taskId) async {
    await apiClient.deleteTask(taskId);
    await refresh();
  }
}
