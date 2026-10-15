import 'package:flutter_test/flutter_test.dart';
import 'package:flowcare_mobile/core/utils/hospital_time.dart';
import 'package:flowcare_mobile/models/patient_journey_model.dart';

import 'fixtures/journey_fixtures.dart';

void main() {
  test(
    'Finalized visit displays real doctor-ordered services and no waiting step',
    () {
      final journey = PatientJourney.build(summaryFixture(), planFixture());
      expect(journey.isFinalized, isTrue);
      expect(journey.currentStep, isNull);
      expect(
        journey.steps.map((s) => s.title),
        containsAll(['Chụp X-Quang', 'Xét nghiệm máu']),
      );
      expect(
        journey.steps.every((s) => s.state == JourneyStepState.completed),
        isTrue,
      );
      expect(
        journey.steps.map((s) => s.location).join(),
        contains('Phòng X-Quang thực tế'),
      );
      expect(
        journey.steps.map((s) => s.location).join(),
        isNot(contains('Mai Hoa')),
      );
    },
  );

  test('Done consultation ticket does not mean whole journey is finalized', () {
    final journey = PatientJourney.build(
      summaryFixture(status: 'InQueue'),
      planFixture(
        status: 'Active',
        steps: [serviceFixture(status: 'WaitingResult')],
      ),
    );
    expect(journey.isFinalized, isFalse);
    expect(journey.currentStep?.state, JourneyStepState.waiting);
    expect(journey.steps.last.state, JourneyStepState.pending);
    expect(journey.currentStep?.statusLabel, 'Đang chờ kết quả');
  });

  test(
    'Completed services send patient back to doctor before finalization',
    () {
      final journey = PatientJourney.build(
        summaryFixture(status: 'InQueue'),
        planFixture(),
      );
      expect(journey.currentStep?.id, 'conclusion');
      expect(journey.currentStep?.instruction, 'Quay lại bác sĩ đọc kết quả');
      expect(journey.isFinalized, isFalse);
    },
  );

  test(
    'Skipped service is resolved but is never described as a completed result',
    () {
      final journey = PatientJourney.build(
        summaryFixture(status: 'InQueue'),
        planFixture(steps: [serviceFixture(status: 'Skipped')]),
      );
      final service = journey.steps.singleWhere((s) => s.isService);
      expect(service.state, JourneyStepState.skipped);
      expect(service.statusLabel, 'Đã bỏ qua');
      expect(service.instruction, 'Bệnh nhân vắng mặt');
      expect(journey.completedCount, lessThan(journey.resolvedCount));
    },
  );

  test('Held prerequisite is waiting rather than enqueued', () {
    final journey = PatientJourney.build(
      summaryFixture(status: 'PendingPreExam', queueStatus: 'Waiting'),
      planFixture(
        status: 'Active',
        source: 'PreExamOrders',
        steps: [serviceFixture(status: 'Pending', held: true)],
      ),
    );
    expect(journey.currentStep?.state, JourneyStepState.waiting);
    expect(journey.currentStep?.statusLabel, 'Chờ kết quả bước trước');
    expect(
      journey.steps.singleWhere((s) => s.id == 'consultation').state,
      JourneyStepState.pending,
    );
  });

  test(
    'A ready service is shown before a parallel service waiting for its result',
    () {
      final journey = PatientJourney.build(
        summaryFixture(status: 'InQueue'),
        planFixture(
          status: 'Active',
          steps: [
            serviceFixture(id: 'first', status: 'WaitingResult'),
            serviceFixture(id: 'second', status: 'InQueue', order: 2),
          ],
        ),
      );
      expect(journey.currentStep?.id, 'second');
    },
  );

  test(
    'Unapproved route does not claim a patient is already queued for services',
    () {
      final journey = PatientJourney.build(
        summaryFixture(status: 'InQueue', queueStatus: 'InProgress'),
        planFixture(
          status: 'Proposed',
          steps: [serviceFixture(status: 'Pending')],
        ),
      );
      expect(
        journey.steps.singleWhere((s) => s.isService).statusLabel,
        'Chờ duyệt lộ trình',
      );
      expect(
        journey.steps.singleWhere((s) => s.isService).state,
        JourneyStepState.pending,
      );
    },
  );

  test('Consultation status follows queue ticket Called and InProgress', () {
    final called = PatientJourney.build(
      summaryFixture(status: 'InQueue', queueStatus: 'Called'),
      null,
    );
    final started = PatientJourney.build(
      summaryFixture(status: 'InQueue', queueStatus: 'InProgress'),
      null,
    );
    expect(called.currentStep?.statusLabel, 'Đã gọi — mời vào phòng');
    expect(started.currentStep?.statusLabel, 'Đang khám');
  });

  test('Hospital dates stay in Vietnam time across a UTC date boundary', () {
    expect(
      hospitalTime(DateTime.parse('2026-10-11T18:05:00Z')),
      '12/10/2026 01:05',
    );
  });
}
