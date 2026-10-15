import 'package:flutter_test/flutter_test.dart';
import 'package:flowcare_mobile/models/journey_timing_model.dart';
import 'package:flowcare_mobile/models/paraclinical_plan_model.dart';

import 'fixtures/journey_fixtures.dart';

void main() {
  JourneyTiming timing(Map<String, dynamic> json) =>
      JourneyTiming.fromPlan(ParaclinicalPlanModel.fromJson(json));

  test(
    'Completed plan retains walking estimates and overlapping result waits',
    () {
      final result = timing(timedPlanJson());
      expect(result.travelMinutes, 6);
      expect(result.steps['xray']!.travelMinutes, 3);
      expect(result.steps['lab']!.travelMinutes, 3);
      expect(result.waitBeforeServiceMinutes, 0);
      expect(result.steps['xray']!.resultWaitMinutes, 15);
      expect(result.steps['lab']!.resultWaitMinutes, 60);
      expect(result.totalMinutes, 76);
    },
  );

  test('Queue delay is separate from walking and result waiting', () {
    final json = timedPlanJson();
    final steps = json['steps'] as List;
    steps[0]['estimatedStartTime'] = '2026-10-12T12:54:58.360+07:00';
    steps[1]['estimatedStartTime'] = '2026-10-12T13:02:58.360+07:00';
    json['estimatedTotalMinutes'] = 81;
    final result = timing(json);
    expect(result.travelMinutes, 6);
    expect(result.steps['xray']!.waitBeforeServiceMinutes, closeTo(5, .001));
    expect(result.steps['lab']!.waitBeforeServiceMinutes, 0);
    expect(result.waitBeforeServiceMinutes, closeTo(5, .001));
  });

  test(
    'Missing or contradictory timestamps never become a zero-minute wait',
    () {
      for (final missing in [true, false]) {
        final json = timedPlanJson();
        (json['steps'] as List)[0]['estimatedStartTime'] = missing
            ? null
            : '2026-10-12T12:40:00+07:00';
        final result = timing(json);
        expect(result.waitBeforeServiceMinutes, isNull);
        expect(result.steps['xray']!.waitBeforeServiceMinutes, isNull);
        expect(result.travelMinutes, 6);
      }
    },
  );

  test(
    'Unmatched total or result dependency suppresses inferred queue waiting',
    () {
      final json = timedPlanJson()..['estimatedTotalMinutes'] = 90;
      expect(timing(json).waitBeforeServiceMinutes, isNull);
      final held = timedPlanJson();
      (held['steps'] as List)[1]['waitsForResultOf'] = ['xray'];
      expect(timing(held).steps['lab']!.waitBeforeServiceMinutes, isNull);
      expect(timing(held).steps['lab']!.travelMinutes, 3);
    },
  );

  test(
    'Missing and invalid travel are unknown, while genuine zero remains zero',
    () {
      for (final input in [null, -1, double.nan, '3']) {
        final json = timedPlanJson();
        (json['steps'] as List)[0]['estimatedTravelMinutes'] = input;
        expect(timing(json).steps['xray']!.travelMinutes, isNull);
        expect(timing(json).travelMinutes, isNull);
      }
      final zero = timedPlanJson();
      (zero['steps'] as List)[0]['estimatedTravelMinutes'] = 0;
      expect(timing(zero).steps['xray']!.travelMinutes, 0);
      expect(timing(zero).travelMinutes, 3);
    },
  );

  test(
    'Recorded elapsed time is preserved without subtracting estimated walking',
    () {
      final result = timing(timedPlanJson());
      expect(
        result.steps['xray']!.elapsedBeforeStartMinutes,
        closeTo(62.173 / 60, .0001),
      );
      expect(
        result.steps['lab']!.elapsedBeforeStartMinutes,
        closeTo(668.368 / 60, .0001),
      );
      expect(
        result.steps['xray']!.actualServiceMinutes,
        closeTo(626.020 / 60, .0001),
      );
      expect(
        result.steps['lab']!.actualResultWaitMinutes,
        closeTo(22.852 / 60, .0001),
      );
    },
  );

  test('Reversed or missing actual timestamps have no recorded duration', () {
    final json = timedPlanJson();
    (json['steps'] as List)[0]['actualStartTime'] = '2026-10-12T12:30:00+07:00';
    (json['steps'] as List)[1]['actualEndTime'] = null;
    final result = timing(json);
    expect(result.steps['xray']!.elapsedBeforeStartMinutes, isNull);
    expect(result.steps['lab']!.actualServiceMinutes, isNull);
    expect(result.steps['lab']!.actualResultWaitMinutes, isNull);
  });
}
