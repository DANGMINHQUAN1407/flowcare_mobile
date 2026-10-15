import 'paraclinical_plan_model.dart';

class JourneyStepTiming {
  final double? travelMinutes;
  final double? waitBeforeServiceMinutes;
  final double? serviceMinutes;
  final double? resultWaitMinutes;
  final double? elapsedBeforeStartMinutes;
  final double? actualServiceMinutes;
  final double? actualResultWaitMinutes;

  const JourneyStepTiming({
    this.travelMinutes,
    this.waitBeforeServiceMinutes,
    this.serviceMinutes,
    this.resultWaitMinutes,
    this.elapsedBeforeStartMinutes,
    this.actualServiceMinutes,
    this.actualResultWaitMinutes,
  });
}

class JourneyTiming {
  final Map<String, JourneyStepTiming> steps;
  final double? travelMinutes;
  final double? waitBeforeServiceMinutes;
  final double? totalMinutes;

  const JourneyTiming._(
    this.steps,
    this.travelMinutes,
    this.waitBeforeServiceMinutes,
    this.totalMinutes,
  );

  factory JourneyTiming.fromPlan(ParaclinicalPlanModel plan) {
    final services = [...plan.steps]
      ..sort((a, b) => a.stepOrder.compareTo(b.stepOrder));
    if (services.isEmpty) {
      return JourneyTiming._({}, null, null, plan.estimatedTotalMinutes);
    }
    // Activated plans shift estimates to their first queue entry. Creation time
    // is only an origin for a proposal; using it for an approved plan invents waiting.
    final origin = plan.isProposed
        ? plan.createdAt
        : services.first.waitsForResultOf.isEmpty
        ? services.first.enqueuedAt
        : null;
    final before = <String, double?>{};
    double? previousEnd = 0;
    var consistent = origin != null;
    var latestResult = 0.0;
    for (final service in services) {
      final start = origin != null && service.estimatedStartTime != null
          ? service.estimatedStartTime!.difference(origin).inMilliseconds /
                60000.0
          : null;
      final travel = service.estimatedTravelMinutes;
      final duration = service.estimatedDurationMinutes;
      final resultWait = service.estimatedResultWaitMinutes;
      final wait = start != null && previousEnd != null && travel != null
          ? start - previousEnd - travel
          : null;
      // Allow sub-second timestamp drift only. A negative or incomplete
      // timeline is unknown, rather than a zero-minute wait.
      if (wait == null ||
          wait < -0.02 ||
          duration == null ||
          resultWait == null) {
        consistent = false;
      }
      before[service.id] = wait == null || wait < -0.02
          ? null
          : wait < 0.02
          ? 0
          : wait;
      previousEnd = start != null && duration != null ? start + duration : null;
      if (previousEnd != null &&
          resultWait != null &&
          previousEnd + resultWait > latestResult) {
        latestResult = previousEnd + resultWait;
      }
    }
    if (plan.estimatedTotalMinutes == null ||
        (latestResult - plan.estimatedTotalMinutes!).abs() > 0.02) {
      consistent = false;
    }
    final rows = <String, JourneyStepTiming>{};
    for (final service in services) {
      rows[service.id] = JourneyStepTiming(
        travelMinutes: service.estimatedTravelMinutes,
        waitBeforeServiceMinutes: consistent && service.waitsForResultOf.isEmpty
            ? before[service.id]
            : null,
        serviceMinutes: service.estimatedDurationMinutes,
        resultWaitMinutes: service.estimatedResultWaitMinutes,
        elapsedBeforeStartMinutes: _elapsed(
          service.enqueuedAt,
          service.actualStartTime,
        ),
        actualServiceMinutes: _elapsed(
          service.actualStartTime,
          service.actualEndTime,
        ),
        actualResultWaitMinutes: _elapsed(
          service.actualEndTime,
          service.resultReadyTime,
        ),
      );
    }
    return JourneyTiming._(
      Map.unmodifiable(rows),
      services.every((s) => s.estimatedTravelMinutes != null)
          ? services.fold<double>(
              0,
              (total, s) => total + s.estimatedTravelMinutes!,
            )
          : null,
      rows.values.every((s) => s.waitBeforeServiceMinutes != null)
          ? rows.values.fold<double>(
              0,
              (total, s) => total + s.waitBeforeServiceMinutes!,
            )
          : null,
      plan.estimatedTotalMinutes,
    );
  }
}

double? _elapsed(DateTime? start, DateTime? end) {
  if (start == null || end == null || end.isBefore(start)) return null;
  return end.difference(start).inMilliseconds / 60000.0;
}
