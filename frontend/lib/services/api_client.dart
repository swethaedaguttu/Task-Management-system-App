import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_base_url.dart';
import '../models/task.dart';

class ApiClient {
  final String baseUrl;
  final http.Client _http;

  static const Duration _readTimeout = Duration(seconds: 15);
  static const Duration _writeTimeout = Duration(seconds: 45);

  ApiClient({String? baseUrl, http.Client? httpClient})
      : baseUrl = baseUrl ?? resolveDefaultApiBaseUrl(),
        _http = httpClient ?? http.Client();

  Future<http.Response> _get(Uri uri) => _run(() => _http.get(uri), _readTimeout);

  Future<http.Response> _delete(Uri uri) => _run(() => _http.delete(uri), _readTimeout);

  Future<http.Response> _post(Uri uri, {required String body}) =>
      _run(() => _http.post(uri, headers: {'Content-Type': 'application/json'}, body: body), _writeTimeout);

  Future<http.Response> _put(Uri uri, {required String body}) =>
      _run(() => _http.put(uri, headers: {'Content-Type': 'application/json'}, body: body), _writeTimeout);

  Future<http.Response> _patch(Uri uri, {required String body}) =>
      _run(() => _http.patch(uri, headers: {'Content-Type': 'application/json'}, body: body), _writeTimeout);

  Future<http.Response> _run(Future<http.Response> Function() fn, Duration timeout) async {
    try {
      return await fn().timeout(timeout);
    } on TimeoutException {
      throw StateError(
        'Request timed out after ${timeout.inSeconds}s. Is FastAPI running at $baseUrl ?',
      );
    } catch (e) {
      throw StateError(
        'Cannot reach API at $baseUrl (start backend: uvicorn main:app --port 8000). Details: $e',
      );
    }
  }

  Uri _tasksUri({String? q, TaskStatus? status, TaskPriority? priority}) {
    final params = <String, String>{};
    if (q != null && q.trim().isNotEmpty) {
      params['q'] = q.trim();
    }
    if (status != null) {
      params['status'] = status.apiValue;
    }
    if (priority != null) {
      params['priority'] = priority.apiValue;
    }
    return Uri.parse(baseUrl).replace(path: '/tasks', queryParameters: params.isEmpty ? null : params);
  }

  Uri _taskUri(int taskId) => Uri.parse(baseUrl).replace(path: '/tasks/$taskId');

  Uri get _reorderUri => Uri.parse(baseUrl).replace(path: '/tasks/reorder');

  Future<List<Task>> fetchTasks({
    String? q,
    TaskStatus? status,
    TaskPriority? priority,
  }) async {
    final res = await _get(_tasksUri(q: q, status: status, priority: priority));
    if (res.statusCode != 200) {
      throw StateError('Failed to load tasks (${res.statusCode}).');
    }
    final decoded = jsonDecode(res.body) as List<dynamic>;
    return decoded.map((e) => Task.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Task> fetchTask(int taskId) async {
    final res = await _get(_taskUri(taskId));
    if (res.statusCode != 200) {
      throw StateError('Task not found (${res.statusCode}).');
    }
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    return Task.fromJson(decoded);
  }

  Future<Task> createTask({
    required String title,
    required String description,
    required DateTime dueDate,
    required TaskStatus status,
    required TaskPriority priority,
    required bool isRecurring,
    required RecurrenceType? recurrenceType,
    required int? blockedById,
  }) async {
    final body = <String, dynamic>{
      'title': title,
      'description': description,
      'due_date': formatDateOnly(dueDate),
      'status': status.apiValue,
      'priority': priority.apiValue,
      'is_recurring': isRecurring,
      'blocked_by_id': blockedById,
    };
    if (isRecurring && recurrenceType != null) {
      body['recurrence_type'] = recurrenceType.apiValue;
    } else {
      body['recurrence_type'] = null;
    }

    final res = await _post(
      Uri.parse(baseUrl).replace(path: '/tasks'),
      body: jsonEncode(body),
    );

    if (res.statusCode != 201) {
      throw StateError('Failed to create task (${res.statusCode}).');
    }
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    return Task.fromJson(decoded);
  }

  Future<Task> updateTask({
    required int taskId,
    required String title,
    required String description,
    required DateTime dueDate,
    required TaskStatus status,
    required TaskPriority priority,
    required bool isRecurring,
    required RecurrenceType? recurrenceType,
    required int? blockedById,
  }) async {
    final body = <String, dynamic>{
      'title': title,
      'description': description,
      'due_date': formatDateOnly(dueDate),
      'status': status.apiValue,
      'priority': priority.apiValue,
      'is_recurring': isRecurring,
      'blocked_by_id': blockedById,
    };
    if (isRecurring && recurrenceType != null) {
      body['recurrence_type'] = recurrenceType.apiValue;
    } else {
      body['recurrence_type'] = null;
    }

    final res = await _put(
      _taskUri(taskId),
      body: jsonEncode(body),
    );

    if (res.statusCode != 200) {
      throw StateError('Failed to update task (${res.statusCode}).');
    }
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    return Task.fromJson(decoded);
  }

  Future<void> deleteTask(int taskId) async {
    final res = await _delete(_taskUri(taskId));
    if (res.statusCode != 204) {
      throw StateError('Failed to delete task (${res.statusCode}).');
    }
  }

  /// Persists global order. [taskIds] must list every task id exactly once.
  Future<void> reorderTasks(List<int> taskIds) async {
    final res = await _patch(
      _reorderUri,
      body: jsonEncode({'task_ids': taskIds}),
    );
    if (res.statusCode != 204) {
      throw StateError('Failed to reorder tasks (${res.statusCode}).');
    }
  }
}
