import 'package:flutter_test/flutter_test.dart';
import 'package:flowcare_mobile/models/encounter_summary_model.dart';
import 'package:flowcare_mobile/models/patient_journey_model.dart';

import 'fixtures/journey_fixtures.dart';

void main() {
  final intakeTime = DateTime.parse('2026-10-18T14:15:00+07:00');
  final vitalTime = DateTime.parse('2026-10-18T14:17:00+07:00');
  JourneyStep nursing(PatientJourney journey) =>
      journey.steps.singleWhere((s) => s.id == 'nursing-intake');

  test('Called patient sees nursing before consultation, without invented services', () {
    final journey = PatientJourney.build(
      summaryFixture(
        status: 'InQueue',
        queueStatus: 'Called',
        nursingIntake: const NursingIntakeProgressModel(),
      ),
      null,
    );
    expect(journey.steps.map((s) => s.id), [
      'reception',
      'nursing-intake',
      'consultation',
      'conclusion',
    ]);
    expect(journey.currentStep?.id, 'nursing-intake');
    expect(journey.currentStep?.statusLabel, 'Đã gọi — mời đến điều dưỡng');
    expect(journey.resolvedCount, 1);
    expect(journey.steps.any((s) => s.isService), isFalse);
    expect(journey.steps[2].statusLabel, 'Sau tiếp nhận điều dưỡng');
  });

  test(
    'Saving intake alone keeps nursing current until vitals are recorded',
    () {
      final journey = PatientJourney.build(
        summaryFixture(
          status: 'InQueue',
          queueStatus: 'Called',
          nursingIntake: NursingIntakeProgressModel(intakeSavedAt: intakeTime),
        ),
        null,
      );
      expect(journey.currentStep?.id, 'nursing-intake');
      expect(
        nursing(journey).instruction,
        contains('Khai báo sản phụ khoa: Đã lưu'),
      );
      expect(
        nursing(journey).instruction,
        contains('Sinh hiệu: Chưa ghi nhận'),
      );
      expect(nursing(journey).completedAt, isNull);
    },
  );

  test('Vitals alone do not mark intake saved', () {
    final journey = PatientJourney.build(
      summaryFixture(
        status: 'InQueue',
        queueStatus: 'Called',
        nursingIntake: NursingIntakeProgressModel(
          vitalSignsRecordedAt: vitalTime,
        ),
      ),
      null,
    );
    expect(journey.currentStep?.id, 'nursing-intake');
    expect(
      nursing(journey).instruction,
      contains('Khai báo sản phụ khoa: Chưa ghi nhận'),
    );
    expect(nursing(journey).instruction, contains('Sinh hiệu: Đã ghi nhận'));
  });

  test('Both real timestamps complete nursing and hand over to the doctor', () {
    final journey = PatientJourney.build(
      summaryFixture(
        status: 'InQueue',
        queueStatus: 'Called',
        nursingIntake: NursingIntakeProgressModel(
          intakeSavedAt: intakeTime,
          vitalSignsRecordedAt: vitalTime,
        ),
      ),
      null,
    );
    expect(nursing(journey).state, JourneyStepState.completed);
    expect(nursing(journey).completedAt, vitalTime);
    expect(journey.currentStep?.id, 'consultation');
    expect(journey.currentStep?.statusLabel, 'Đã gọi — mời vào phòng');
    expect(journey.resolvedCount, 2);
  });

  test('Doctor progress never fabricates missing nursing records or sends patient backwards', () {
    for (final status in ['InProgress', 'Done']) {
      final journey = PatientJourney.build(
        summaryFixture(
          status: 'InQueue',
          queueStatus: status,
          nursingIntake: const NursingIntakeProgressModel(),
        ),
        null,
      );
      expect(nursing(journey).state, JourneyStepState.pending);
      expect(nursing(journey).statusLabel, 'Chưa đủ ghi nhận điều dưỡng');
      expect(journey.currentStep?.id, isNot('nursing-intake'));
    }
  });

  test('Approved medical orders add six steps in the actual route order', () {
    final journey = PatientJourney.build(
      summaryFixture(status: 'InQueue'),
      planFixture(
        status: 'Active',
        steps: [
          serviceFixture(id: 'lab', order: 1, status: 'InQueue'),
          serviceFixture(
            id: 'xray',
            title: 'Chụp X-Quang',
            order: 2,
            status: 'Pending',
          ),
        ],
      ),
    );
    expect(journey.steps.map((s) => s.id), [
      'reception',
      'nursing-intake',
      'consultation',
      'lab',
      'xray',
      'conclusion',
    ]);
    expect(journey.currentStep?.id, 'lab');
  });

  test('Pre-exam services stay before nursing and consultation', () {
    final journey = PatientJourney.build(
      summaryFixture(
        status: 'PendingPreExam',
        queueStatus: 'Waiting',
        nursingIntake: const NursingIntakeProgressModel(),
      ),
      planFixture(
        source: 'PreExamOrders',
        status: 'Active',
        steps: [serviceFixture(id: 'lab', status: 'InQueue')],
      ),
    );
    expect(journey.steps.map((s) => s.id), [
      'reception',
      'lab',
      'nursing-intake',
      'consultation',
      'conclusion',
    ]);
    expect(journey.currentStep?.id, 'lab');
  });

  test(
    'Old API is explicit about missing data instead of marking nursing done',
    () {
      final oldJson = summaryFixture(
        status: 'InQueue',
        queueStatus: 'Called',
      ).toJson()..remove('nursingIntake');
      final journey = PatientJourney.build(
        EncounterSummaryModel.fromJson(oldJson),
        null,
      );
      expect(journey.currentStep?.id, 'nursing-intake');
      expect(nursing(journey).state, JourneyStepState.current);
      expect(nursing(journey).statusLabel, 'Chưa có cập nhật điều dưỡng');
      expect(nursing(journey).completedAt, isNull);
    },
  );

  test(
    'Progress timestamps survive API parsing and do not accept invalid dates',
    () {
      final json = summaryFixture().toJson()
        ..['nursingIntake'] = {
          'intakeSavedAt': intakeTime.toIso8601String(),
          'vitalSignsRecordedAt': vitalTime.toIso8601String(),
        };
      final parsed = EncounterSummaryModel.fromJson(json).nursingIntake!;
      expect(parsed.isComplete, isTrue);
      expect(parsed.completedAt, vitalTime);
      expect(
        NursingIntakeProgressModel.fromJson({
          'intakeSavedAt': 'bad',
          'vitalSignsRecordedAt': null,
        }).isComplete,
        isFalse,
      );
    },
  );
}
