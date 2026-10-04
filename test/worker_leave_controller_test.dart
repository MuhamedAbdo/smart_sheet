// test/worker_leave_controller_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_sheet/models/worker_action_model.dart';
import 'package:smart_sheet/controllers/worker_leave_controller.dart';

void main() {
  group('WorkerLeaveController Business Logic Tests', () {
    test(
        'isOverdue returns true when today is after expectedReturnDate and returnDate is null',
        () {
      final action = WorkerAction(
        type: 'إجازة',
        date: DateTime(2026, 4, 10),
        expectedReturnDate: DateTime(2026, 4, 15),
      );

      final today = DateTime(2026, 4, 16);
      expect(WorkerLeaveController.isOverdue(action, today), isTrue);
    });

    test(
        'isOverdue returns false when today is equal to or before expectedReturnDate',
        () {
      final action = WorkerAction(
        type: 'إجازة',
        date: DateTime(2026, 4, 10),
        expectedReturnDate: DateTime(2026, 4, 15),
      );

      // On the same day
      expect(WorkerLeaveController.isOverdue(action, DateTime(2026, 4, 15)),
          isFalse);
      // Before expected return
      expect(WorkerLeaveController.isOverdue(action, DateTime(2026, 4, 14)),
          isFalse);
    });

    test('isOverdue returns false if returnDate is already set', () {
      final action = WorkerAction(
        type: 'إجازة',
        date: DateTime(2026, 4, 10),
        expectedReturnDate: DateTime(2026, 4, 15),
        returnDate: DateTime(2026, 4, 16),
      );

      expect(WorkerLeaveController.isOverdue(action, DateTime(2026, 4, 17)),
          isFalse);
    });

    test('calculateDelayDays computes exact days of delay', () {
      final action = WorkerAction(
        type: 'إجازة',
        date: DateTime(2026, 4, 10),
        expectedReturnDate: DateTime(2026, 4, 15),
      );

      expect(
          WorkerLeaveController.calculateDelayDays(
              action, DateTime(2026, 4, 15)),
          0);
      expect(
          WorkerLeaveController.calculateDelayDays(
              action, DateTime(2026, 4, 16)),
          1);
      expect(
          WorkerLeaveController.calculateDelayDays(
              action, DateTime(2026, 4, 18)),
          3);
    });

    test('OverdueLeaveAction enum contains all 3 required choices', () {
      expect(OverdueLeaveAction.values.length, 3);
      expect(
          OverdueLeaveAction.values, contains(OverdueLeaveAction.extendLeave));
      expect(OverdueLeaveAction.values,
          contains(OverdueLeaveAction.absenceWithoutPermission));
      expect(OverdueLeaveAction.values,
          contains(OverdueLeaveAction.convertAllToAbsence));
    });
  });
}
