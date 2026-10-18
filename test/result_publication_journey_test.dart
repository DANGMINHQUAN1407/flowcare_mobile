import 'package:flutter_test/flutter_test.dart';
import 'package:flowcare_mobile/models/paraclinical_plan_model.dart';
import 'package:flowcare_mobile/models/patient_journey_model.dart';

import 'fixtures/journey_fixtures.dart';

void main() {
  for (final title in ['Chụp X-Quang', 'Xét nghiệm máu']) {
    test(
      '$title: completed service without a finalized report is not a published result',
      () {
        final journey = PatientJourney.build(
          summaryFixture(status: 'InQueue'),
          planFixture(
            steps: [serviceFixture(title: title, isResultFinalized: false)],
          ),
        );
        final service = journey.steps.singleWhere((s) => s.isService);
        expect(service.statusLabel, 'Đã thực hiện · Chờ chốt kết quả');
        expect(service.state, JourneyStepState.waiting);
        expect(service.completedAt, isNull);
        expect(journey.steps.last.state, JourneyStepState.pending);
        expect(journey.currentStep?.isService, isTrue);
      },
    );

    test(
      '$title: finalized current report makes the service result available',
      () {
        final journey = PatientJourney.build(
          summaryFixture(status: 'InQueue'),
          planFixture(steps: [serviceFixture(title: title)]),
        );
        expect(
          journey.steps.singleWhere((s) => s.isService).statusLabel,
          'Đã có kết quả',
        );
        expect(journey.currentStep?.id, 'conclusion');
      },
    );
  }

  test('One finalized report never makes the other service result ready', () {
    final journey = PatientJourney.build(
      summaryFixture(status: 'InQueue'),
      planFixture(
        steps: [
          serviceFixture(id: 'lab'),
          serviceFixture(
            id: 'xray',
            title: 'Chụp X-Quang',
            order: 2,
            isResultFinalized: false,
          ),
        ],
      ),
    );
    expect(journey.currentStep?.id, 'xray');
    expect(journey.steps.last.state, JourneyStepState.pending);
    expect(
      journey.steps.singleWhere((s) => s.id == 'lab').state,
      JourneyStepState.completed,
    );
  });

  test('Old API completed state alone cannot prove a result is finalized', () {
    final json = timedPlanJson();
    for (final step in json['steps'] as List) {
      step.remove('isResultFinalized');
      step.remove('requiresFinalizedResult');
    }
    final journey = PatientJourney.build(
      summaryFixture(status: 'InQueue'),
      ParaclinicalPlanModel.fromJson(json),
    );
    expect(
      journey.steps
          .where((s) => s.isService)
          .every(
            (s) => s.statusLabel == 'Đã thực hiện · Chưa xác nhận kết quả',
          ),
      isTrue,
    );
    expect(journey.steps.last.state, JourneyStepState.pending);
  });

  test('Published timestamp comes from report finalization, not service completion', () {
    final json = timedPlanJson();
    (json['steps'] as List).first['resultFinalizedAt'] =
        '2026-10-18T15:05:00+07:00';
    final journey = PatientJourney.build(
      summaryFixture(status: 'InQueue'),
      ParaclinicalPlanModel.fromJson(json),
    );
    expect(
      journey.steps.singleWhere((s) => s.id == 'xray').completedAt,
      DateTime.parse('2026-10-18T15:05:00+07:00'),
    );
  });

  test('Pre-exam completion keeps its own result-ready workflow', () {
    final json = timedPlanJson()..['source'] = 'PreExamOrders';
    for (final step in json['steps'] as List) {
      step['requiresFinalizedResult'] = false;
      step['isResultFinalized'] = null;
    }
    final plan = ParaclinicalPlanModel.fromJson(json);
    expect(plan.steps.every((s) => s.isResolved), isTrue);
  });
}
