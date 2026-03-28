import 'package:flutter_test/flutter_test.dart';

import 'package:task_management/main.dart';

void main() {
  testWidgets('Task list shell loads', (WidgetTester tester) async {
    await tester.pumpWidget(const TaskManagementApp());
    await tester.pump();
    expect(find.text('Tasks'), findsOneWidget);
    // TaskListPage schedules a short delayed refresh; flush timers before dispose.
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });
}
