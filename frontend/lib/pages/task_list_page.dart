import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_scaffold_messenger.dart';
import '../models/task.dart';
import '../state/draft_store.dart';
import '../state/tasks_controller.dart';
import '../widgets/task_card.dart';
import 'task_form_page.dart';

class TaskListPage extends StatefulWidget {
  const TaskListPage({super.key});

  @override
  State<TaskListPage> createState() => _TaskListPageState();
}

class _TaskListPageState extends State<TaskListPage> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  /// After a successful create, next "New task" opens with an empty form (no draft restore).
  bool _openCreateWithEmptyForm = false;

  static const Duration _searchDebounceDuration = Duration(milliseconds: 300);
  static const Duration _initialRefreshDelay = Duration(milliseconds: 48);
  static const EdgeInsets _sectionPad =
      EdgeInsets.symmetric(horizontal: 16, vertical: 10);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(_initialRefreshDelay);
      if (!mounted) return;
      await context.read<TasksController>().refresh();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _scheduleDebouncedApiSearch() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(_searchDebounceDuration, () async {
      if (!mounted) return;
      final controller = context.read<TasksController>();
      controller.setListFilters(
        searchQuery: _searchController.text,
        statusFilter: controller.statusFilter,
        priorityFilter: controller.priorityFilter,
      );
      await controller.refresh();
    });
  }

  void _showAddTaskSheet() {
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            8,
            24,
            24 + MediaQuery.paddingOf(ctx).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Add a task',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Creates a task on your FastAPI server (~2s save) and shows it in the list below. '
                'You can set priority, due date, status, and optional “blocked by”.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _openCreate();
                },
                icon: const Icon(Icons.add_task_rounded),
                label: const Text('Create new task'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openCreate() async {
    final controller = context.read<TasksController>();
    final ignoreDraft = _openCreateWithEmptyForm;
    _openCreateWithEmptyForm = false;

    final didSave = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => TaskFormPage.create(ignoreDraft: ignoreDraft),
      ),
    );
    if (!mounted) return;
    if (didSave == true) {
      await DraftStore().clearCreateDraft();
      _openCreateWithEmptyForm = true;
      showAppSnackBar('Task added successfully.');
      setState(() => _searchController.clear());
      controller.setListFilters(
        searchQuery: '',
        statusFilter: null,
        priorityFilter: null,
      );
      await controller.refresh();
    }
  }

  Future<void> _openEdit(int taskId) async {
    final controller = context.read<TasksController>();
    final didSave = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => TaskFormPage.edit(taskId: taskId)),
    );
    if (!mounted) return;
    if (didSave == true) {
      showAppSnackBar('Task updated successfully.');
      await controller.refresh();
    }
  }

  Future<void> _confirmDelete(Task task) async {
    final controller = context.read<TasksController>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text('“${task.title}” will be removed permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (confirmed != true) return;

    appMessengerKey.currentState?.clearSnackBars();
    appMessengerKey.currentState?.clearMaterialBanners();
    try {
      await controller.deleteTask(task.id);
      if (!mounted) return;
      showAppSnackBar('Task deleted successfully.');
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar('Delete failed: $e', isError: true);
    }
  }

  Widget _taskCardForIndex(
    BuildContext context,
    List<Task> tasks,
    Map<int, Task> tasksById,
    int index,
  ) {
    final task = tasks[index];
    final blockedBy =
        task.blockedById != null ? tasksById[task.blockedById!] : null;
    final isBlocked =
        blockedBy != null && blockedBy.status != TaskStatus.done;
    return TaskCard(
      task: task,
      isBlocked: isBlocked,
      blockedByTitle: blockedBy?.title,
      titleHighlightQuery: _searchController.text,
      onEdit: () => _openEdit(task.id),
      onRequestDelete: () => _confirmDelete(task),
    );
  }

  Widget _labeledChipRow({
    required String label,
    required List<Widget> chips,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: _sectionPad,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: chips),
          ),
        ],
      ),
    );
  }

  List<Widget> _spacedChips(List<Widget> inner) {
    final out = <Widget>[];
    for (var i = 0; i < inner.length; i++) {
      if (i > 0) out.add(const SizedBox(width: 8));
      out.add(inner[i]);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTaskSheet,
        tooltip: 'Add a new task',
        icon: const Icon(Icons.add),
        label: const Text('New task'),
      ),
      body: SafeArea(
        child: Consumer<TasksController>(
          builder: (context, controller, _) {
            if (controller.error != null) {
              return Padding(
                padding: _sectionPad,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.cloud_off_outlined,
                      size: 56,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Cannot load tasks',
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      controller.error!,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      controller.apiClient.baseUrl,
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tip: run the API from the backend folder:\n'
                      'uvicorn main:app --reload --port 8000',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () => controller.refresh(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            final tasksById = {for (final t in controller.tasks) t.id: t};
            final loading = controller.isLoading;
            final tasks = controller.tasks;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (loading) ...[
                  const LinearProgressIndicator(minHeight: 3),
                  Padding(
                    padding: _sectionPad,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Loading tasks… (save waits ~2s on server)',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                Padding(
                  padding: _sectionPad,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Search',
                      hintText: 'Title or description (API, debounced)',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                                _scheduleDebouncedApiSearch();
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    onChanged: (_) {
                      setState(() {});
                      _scheduleDebouncedApiSearch();
                    },
                  ),
                ),
                _labeledChipRow(
                  label: 'Status',
                  chips: _spacedChips([
                    ChoiceChip(
                      label: const Text('All'),
                      selected: controller.statusFilter == null,
                      onSelected: (_) {
                        controller.setListFilters(
                          searchQuery: _searchController.text,
                          statusFilter: null,
                          priorityFilter: controller.priorityFilter,
                        );
                        controller.refresh();
                      },
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    for (final s in TaskStatus.values)
                      ChoiceChip(
                        label: Text(s.apiValue),
                        selected: controller.statusFilter == s,
                        onSelected: (_) {
                          controller.setListFilters(
                            searchQuery: _searchController.text,
                            statusFilter: s,
                            priorityFilter: controller.priorityFilter,
                          );
                          controller.refresh();
                        },
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                  ]),
                ),
                _labeledChipRow(
                  label: 'Priority',
                  chips: _spacedChips([
                    ChoiceChip(
                      label: const Text('All'),
                      selected: controller.priorityFilter == null,
                      onSelected: (_) {
                        controller.setListFilters(
                          searchQuery: _searchController.text,
                          statusFilter: controller.statusFilter,
                          priorityFilter: null,
                        );
                        controller.refresh();
                      },
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    ChoiceChip(
                      label: const Text('High'),
                      selected: controller.priorityFilter == TaskPriority.high,
                      onSelected: (_) {
                        controller.setListFilters(
                          searchQuery: _searchController.text,
                          statusFilter: controller.statusFilter,
                          priorityFilter: TaskPriority.high,
                        );
                        controller.refresh();
                      },
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    ChoiceChip(
                      label: const Text('Medium'),
                      selected: controller.priorityFilter == TaskPriority.medium,
                      onSelected: (_) {
                        controller.setListFilters(
                          searchQuery: _searchController.text,
                          statusFilter: controller.statusFilter,
                          priorityFilter: TaskPriority.medium,
                        );
                        controller.refresh();
                      },
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    ChoiceChip(
                      label: const Text('Low'),
                      selected: controller.priorityFilter == TaskPriority.low,
                      onSelected: (_) {
                        controller.setListFilters(
                          searchQuery: _searchController.text,
                          statusFilter: controller.statusFilter,
                          priorityFilter: TaskPriority.low,
                        );
                        controller.refresh();
                      },
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ]),
                ),
                if (tasks.isNotEmpty && !controller.canReorder)
                  Padding(
                    padding: _sectionPad,
                    child: Text(
                      'Drag to reorder is available when search and filters are cleared.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.65),
                          ),
                    ),
                  ),
                Expanded(
                  child: loading && tasks.isEmpty
                      ? Center(
                          child: Padding(
                            padding: _sectionPad,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const CircularProgressIndicator(),
                                const SizedBox(height: 20),
                                Text(
                                  'Connecting to API…',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                SelectableText(
                                  controller.apiClient.baseUrl,
                                  style: Theme.of(context).textTheme.bodySmall,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () => controller.refresh(),
                          child: tasks.isEmpty
                              ? CustomScrollView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  slivers: [
                                    SliverFillRemaining(
                                      hasScrollBody: false,
                                      child: Padding(
                                        padding: _sectionPad,
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.inbox_outlined,
                                              size: 72,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .outline,
                                            ),
                                            const SizedBox(height: 20),
                                            Text(
                                              'No tasks yet — Add your first task!',
                                              textAlign: TextAlign.center,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleLarge
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              'Tap “New task” below, fill the form, then “Add to list”. '
                                              'Tap any card to edit; trash icon deletes.',
                                              textAlign: TextAlign.center,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium,
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              'High-priority tasks show a colored stripe; overdue dates are highlighted.',
                                              textAlign: TextAlign.center,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall,
                                            ),
                                            const SizedBox(height: 16),
                                            SelectableText(
                                              controller.apiClient.baseUrl,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelSmall,
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : controller.canReorder
                                  ? ReorderableListView(
                                      buildDefaultDragHandles: false,
                                      padding: const EdgeInsets.only(
                                        bottom: 88,
                                      ),
                                      physics:
                                          const AlwaysScrollableScrollPhysics(),
                                      onReorder: (oldIndex, newIndex) async {
                                        var ni = newIndex;
                                        if (oldIndex < ni) ni -= 1;
                                        final list = List<Task>.from(tasks);
                                        final item = list.removeAt(oldIndex);
                                        list.insert(ni, item);
                                        controller.reorderLocal(list);
                                        try {
                                          await controller.commitReorder(
                                            list.map((t) => t.id).toList(),
                                          );
                                        } catch (e) {
                                          if (!context.mounted) return;
                                          await controller.refresh();
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Could not save order: $e',
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                      children: [
                                        for (var i = 0; i < tasks.length; i++)
                                          ReorderableDragStartListener(
                                            key: ValueKey<int>(tasks[i].id),
                                            index: i,
                                            child: _taskCardForIndex(
                                              context,
                                              tasks,
                                              tasksById,
                                              i,
                                            ),
                                          ),
                                      ],
                                    )
                                  : ListView.builder(
                                      padding:
                                          const EdgeInsets.only(bottom: 88),
                                      physics:
                                          const AlwaysScrollableScrollPhysics(),
                                      itemCount: tasks.length,
                                      itemBuilder: (context, index) {
                                        return _taskCardForIndex(
                                          context,
                                          tasks,
                                          tasksById,
                                          index,
                                        );
                                      },
                                    ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
