import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/task.dart';
import '../services/api_client.dart';
import '../state/draft_store.dart';
import '../state/tasks_controller.dart';

class TaskFormPage extends StatefulWidget {
  final int? taskId;

  /// When true (next open after a successful create), skip loading SharedPreferences so the form stays empty.
  final bool ignoreDraft;

  TaskFormPage.create({super.key, this.ignoreDraft = false}) : taskId = null;

  TaskFormPage.edit({
    required this.taskId,
    super.key,
  }) : ignoreDraft = false;

  bool get isEditing => taskId != null;

  @override
  State<TaskFormPage> createState() => _TaskFormPageState();
}

class _TaskFormPageState extends State<TaskFormPage> with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();

  late final ApiClient _apiClient;
  final DraftStore _draftStore = DraftStore();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  TaskStatus _status = TaskStatus.todo;
  TaskPriority _priority = TaskPriority.medium;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));
  bool _isRecurring = false;
  RecurrenceType? _recurrenceType;
  int? _blockedById;

  List<Task> _taskOptions = const [];

  bool _isLoadingInitial = true;
  bool _isSaving = false;
  /// After a successful create we clear storage; dispose must not re-save the same text or the next "new task" form reloads the old draft.
  bool _skipDraftPersistence = false;

  Timer? _draftDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _apiClient = context.read<TasksController>().apiClient;
    _initialize();
  }

  Future<void> _persistCreateDraftNow() async {
    if (widget.isEditing || _skipDraftPersistence) return;
    // While create is saving, never write draft (avoids async save finishing after clear).
    if (!widget.isEditing && _isSaving) return;
    await _draftStore.saveCreateDraft(
      TaskCreateDraft(
        title: _titleController.text,
        description: _descriptionController.text,
        dueDate: _dueDate,
        status: _status,
        priority: _priority,
        isRecurring: _isRecurring,
        recurrenceType: _recurrenceType,
        blockedById: _blockedById,
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.isEditing || _skipDraftPersistence) return;
    if (!widget.isEditing && _isSaving) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      unawaited(_persistCreateDraftNow());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _draftDebounce?.cancel();
    if (!widget.isEditing && !_skipDraftPersistence) {
      unawaited(_persistCreateDraftNow());
    }
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final futures = <Future>[
        _apiClient.fetchTasks(),
      ];

      if (widget.isEditing) {
        futures.add(_apiClient.fetchTask(widget.taskId!));
      }

      final results = await Future.wait(futures);
      final fetchedOptions = results[0] as List<Task>;

      Task? editingTask;
      if (widget.isEditing) {
        editingTask = results[1] as Task;
      }

      _taskOptions = fetchedOptions;

      if (widget.isEditing) {
        final t = editingTask as Task;
        _titleController.text = t.title;
        _descriptionController.text = t.description;
        _dueDate = t.dueDate;
        _status = t.status;
        _priority = t.priority;
        _isRecurring = t.isRecurring;
        _recurrenceType = t.recurrenceType;
        _blockedById = t.blockedById;
      } else if (!widget.ignoreDraft) {
        final draft = await _draftStore.loadCreateDraft();
        if (draft != null) {
          _titleController.text = draft.title;
          _descriptionController.text = draft.description;
          _dueDate = draft.dueDate;
          _status = draft.status;
          _priority = draft.priority;
          _isRecurring = draft.isRecurring;
          _recurrenceType =
              draft.isRecurring ? (draft.recurrenceType ?? RecurrenceType.daily) : null;
          _blockedById = draft.blockedById;
        }
      }
    } catch (_) {
      // Errors will be surfaced in UI via SnackBars on save; keep init simple.
    } finally {
      if (mounted) setState(() => _isLoadingInitial = false);
    }
  }

  void _queueDraftSave() {
    if (widget.isEditing || _skipDraftPersistence) return;
    if (!widget.isEditing && _isSaving) return;
    _draftDebounce?.cancel();
    _draftDebounce = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted || _skipDraftPersistence) return;
      await _draftStore.saveCreateDraft(
        TaskCreateDraft(
          title: _titleController.text,
          description: _descriptionController.text,
          dueDate: _dueDate,
          status: _status,
          priority: _priority,
          isRecurring: _isRecurring,
          recurrenceType: _recurrenceType,
          blockedById: _blockedById,
        ),
      );
    });
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => _dueDate = picked);
    _queueDraftSave();
  }

  Future<void> _onSave() async {
    final form = _formKey.currentState;
    if (form == null) return;
    if (!form.validate()) return;
    if (_isSaving) return; // Prevent double-tap.

    if (_isRecurring && _recurrenceType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick Daily or Weekly for recurring tasks.')),
      );
      return;
    }

    if (!widget.isEditing) {
      _draftDebounce?.cancel();
    }

    setState(() => _isSaving = true);
    try {
      final title = _titleController.text.trim();
      final description = _descriptionController.text.trim();
      final recurrence = _isRecurring ? _recurrenceType : null;

      if (widget.isEditing) {
        await _apiClient.updateTask(
          taskId: widget.taskId!,
          title: title,
          description: description,
          dueDate: _dueDate,
          status: _status,
          priority: _priority,
          isRecurring: _isRecurring,
          recurrenceType: recurrence,
          blockedById: _blockedById,
        );
      } else {
        // Before slow network: block all draft writes so lifecycle/debounced
        // saves cannot race after [clearCreateDraft].
        _skipDraftPersistence = true;
        await _apiClient.createTask(
          title: title,
          description: description,
          dueDate: _dueDate,
          status: _status,
          priority: _priority,
          isRecurring: _isRecurring,
          recurrenceType: recurrence,
          blockedById: _blockedById,
        );
        await _draftStore.clearCreateDraft();
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!widget.isEditing) {
        _skipDraftPersistence = false;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.isEditing;
    final title = isEditing ? 'Edit task' : 'Create task';

    final blockedOptions = _taskOptions.where((t) {
      if (widget.isEditing && t.id == widget.taskId) return false;
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (!_isLoadingInitial)
            if (_isSaving)
              const Padding(
                padding: EdgeInsets.only(right: 16),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              TextButton.icon(
                onPressed: _onSave,
                icon: Icon(isEditing ? Icons.check : Icons.playlist_add),
                label: Text(isEditing ? 'Save' : 'Add to list'),
              ),
        ],
      ),
      body: SafeArea(
        child: _isLoadingInitial
            ? const Center(child: CircularProgressIndicator())
            : AbsorbPointer(
                absorbing: _isSaving,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _titleController,
                          enabled: !_isSaving,
                          decoration: const InputDecoration(
                            labelText: 'Title',
                            prefixIcon: Icon(Icons.title),
                            border: OutlineInputBorder(),
                          ),
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            final v = value?.trim() ?? '';
                            if (v.isEmpty) return 'Title is required';
                            return null;
                          },
                          onChanged: (_) => _queueDraftSave(),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _descriptionController,
                          enabled: !_isSaving,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            prefixIcon: Icon(Icons.description_outlined),
                            alignLabelWithHint: true,
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 4,
                          minLines: 3,
                          validator: (value) {
                            final v = value?.trim() ?? '';
                            if (v.isEmpty) return 'Description is required';
                            return null;
                          },
                          onChanged: (_) => _queueDraftSave(),
                        ),
                        const SizedBox(height: 14),
                        InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Due Date',
                            border: OutlineInputBorder(),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                tooltip: 'Pick due date',
                                onPressed: _isSaving ? null : _pickDueDate,
                                icon: const Icon(Icons.calendar_month_outlined),
                              ),
                              Expanded(
                                child: Text(
                                  formatDateOnly(_dueDate),
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Priority',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final p in TaskPriority.values)
                              ChoiceChip(
                                label: Text(p.apiValue),
                                selected: _priority == p,
                                onSelected: _isSaving
                                    ? null
                                    : (_) {
                                        setState(() => _priority = p);
                                        _queueDraftSave();
                                      },
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Recurring task'),
                          subtitle: Text(
                            _isRecurring
                                ? 'When marked Done, a new copy is created (To-Do) with the next due date.'
                                : 'Optional — Daily or Weekly follow-up tasks.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          value: _isRecurring,
                          onChanged: _isSaving
                              ? null
                              : (v) {
                                  setState(() {
                                    _isRecurring = v;
                                    _recurrenceType =
                                        v ? (_recurrenceType ?? RecurrenceType.daily) : null;
                                  });
                                  _queueDraftSave();
                                },
                        ),
                        if (_isRecurring) ...[
                          const SizedBox(height: 8),
                          DropdownButtonFormField<RecurrenceType>(
                            key: ValueKey(_recurrenceType),
                            initialValue: _recurrenceType ?? RecurrenceType.daily,
                            decoration: const InputDecoration(
                              labelText: 'Repeat',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.repeat_outlined),
                            ),
                            items: RecurrenceType.values
                                .map(
                                  (r) => DropdownMenuItem(
                                    value: r,
                                    child: Text(r.label),
                                  ),
                                )
                                .toList(),
                            onChanged: _isSaving
                                ? null
                                : (value) {
                                    if (value == null) return;
                                    setState(() => _recurrenceType = value);
                                    _queueDraftSave();
                                  },
                          ),
                        ],
                        const SizedBox(height: 14),
                        DropdownButtonFormField<TaskStatus>(
                          key: ValueKey(_status),
                          initialValue: _status,
                          decoration: const InputDecoration(
                            labelText: 'Status',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.flag_outlined),
                          ),
                          items: TaskStatus.values
                              .map(
                                (s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(s.apiValue),
                                ),
                              )
                              .toList(),
                          onChanged: _isSaving
                              ? null
                              : (value) {
                                  if (value == null) return;
                                  setState(() => _status = value);
                                  _queueDraftSave();
                                },
                        ),
                        const SizedBox(height: 14),
                        InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Blocked By (optional)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.block_outlined),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int?>(
                              value: _blockedById,
                              isExpanded: true,
                              items: [
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('None'),
                                ),
                                for (final t in blockedOptions)
                                  DropdownMenuItem<int?>(
                                    value: t.id,
                                    child: Text(t.title),
                                  ),
                              ],
                              onChanged: _isSaving
                                  ? null
                                  : (value) {
                                      setState(() => _blockedById = value);
                                      _queueDraftSave();
                                    },
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: _isSaving ? null : _onSave,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Icon(isEditing ? Icons.save_outlined : Icons.add_task),
                          label: Text(
                            _isSaving
                                ? (isEditing ? 'Saving…' : 'Adding…')
                                : (isEditing ? 'Save changes' : 'Add to list'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (widget.isEditing == false)
                          Text(
                            'Adds your task to the main list after the server saves (~2s). '
                            'Drafts are saved while you type.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.7),
                                ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

