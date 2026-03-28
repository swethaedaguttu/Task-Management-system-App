import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_scaffold_messenger.dart';
import 'pages/task_list_page.dart';
import 'services/api_client.dart';
import 'state/tasks_controller.dart';

void main() {
  runApp(const TaskManagementApp());
}

class TaskManagementApp extends StatelessWidget {
  const TaskManagementApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TasksController(apiClient: ApiClient()),
      child: MaterialApp(
        scaffoldMessengerKey: appMessengerKey,
        title: 'Task Management',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
          useMaterial3: true,
          cardTheme: const CardThemeData(
            elevation: 0.5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
          ),
          appBarTheme: const AppBarTheme(
            centerTitle: false,
          ),
        ),
        home: const TaskListPage(),
      ),
    );
  }
}

