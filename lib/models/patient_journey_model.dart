import 'encounter_summary_model.dart';
import 'paraclinical_plan_model.dart';
import 'journey_timing_model.dart';

enum JourneyStepState { pending, current, waiting, completed, skipped }

class JourneyStep {
  final String id;
  final String title;
  final String location;
  final String statusLabel;
  final JourneyStepState state;
  final String? instruction;
  final int? queueNumber;
  final DateTime? completedAt;
  final DateTime? estimatedStartTime;
  final bool isService;
  final JourneyStepTiming? timing;

  const JourneyStep({
    required this.id,
    required this.title,
    required this.location,
    required this.statusLabel,
    required this.state,
    this.instruction,
    this.queueNumber,
    this.completedAt,
    this.estimatedStartTime,
    this.isService = false,
    this.timing,
  });
}

class PatientJourney {
  final EncounterSummaryModel summary;
  final ParaclinicalPlanModel? plan;
  final List<JourneyStep> steps;

  const PatientJourney._(this.summary, this.plan, this.steps);

  bool get isFinalized => summary.isFinalized;
  JourneyTiming? get timing =>
      plan == null ? null : JourneyTiming.fromPlan(plan!);
  int get completedCount =>
      steps.where((s) => s.state == JourneyStepState.completed).length;
  int get resolvedCount => steps
      .where(
        (s) =>
            s.state == JourneyStepState.completed ||
            s.state == JourneyStepState.skipped,
      )
      .length;
  JourneyStep? get currentStep {
    if (isFinalized) return null;
    for (final step in steps) {
      if (step.state == JourneyStepState.current) return step;
    }
    for (final step in steps) {
      if (step.state == JourneyStepState.waiting) return step;
    }
    return null;
  }

  factory PatientJourney.build(
    EncounterSummaryModel summary,
    ParaclinicalPlanModel? plan,
  ) {
    final finalized = summary.isFinalized;
    final timing = plan == null ? null : JourneyTiming.fromPlan(plan);
    final queue = summary.queueStatus?.toLowerCase() ?? '';
    final checkedIn =
        summary.checkInTime != null ||
        !const {
          '',
          'draft',
          'pendingpayment',
        }.contains(summary.encounterStatus.toLowerCase());
    final doctorOrdered = plan?.isDoctorOrdered == true;
    final servicesResolved =
        plan != null &&
        !plan.isProposed &&
        plan.steps.every((s) => s.isResolved);
    final preExamUnresolved = summary.preExamOrders.any(
      (o) => !const {'completed', 'cancelled'}.contains(o.status.toLowerCase()),
    );
    final consultLocation = [
      if (summary.roomName?.trim().isNotEmpty == true) summary.roomName!,
      if (summary.doctorName?.trim().isNotEmpty == true) summary.doctorName!,
    ].join(' · ');
    final steps = <JourneyStep>[
      JourneyStep(
        id: 'reception',
        title: 'Tiếp đón & check-in',
        location: 'Quầy tiếp đón',
        statusLabel: checkedIn ? 'Đã tiếp nhận' : 'Chờ check-in',
        state: checkedIn
            ? JourneyStepState.completed
            : JourneyStepState.current,
        completedAt: summary.checkInTime,
      ),
    ];

    JourneyStep consultation({bool beforeServices = false}) {
      final completed = finalized || beforeServices || queue == 'done';
      final blockedByServices =
          !beforeServices &&
          ((plan != null && !servicesResolved) || preExamUnresolved);
      final state = completed
          ? JourneyStepState.completed
          : !checkedIn || blockedByServices
          ? JourneyStepState.pending
          : JourneyStepState.current;
      return JourneyStep(
        id: 'consultation',
        title: 'Khám bác sĩ',
        location: consultLocation,
        statusLabel: completed
            ? 'Đã khám'
            : blockedByServices
            ? 'Sau cận lâm sàng'
            : queue == 'inprogress'
            ? 'Đang khám'
            : queue == 'called'
            ? 'Đã gọi — mời vào phòng'
            : queue == 'skipped'
            ? 'Đã bỏ lượt — liên hệ nhân viên'
            : checkedIn
            ? 'Đang chờ gọi số'
            : 'Chờ tiếp đón',
        state: state,
        queueNumber: completed ? null : summary.queueNumber,
      );
    }

    if (doctorOrdered) steps.add(consultation(beforeServices: true));
    if (plan != null) {
      for (final service in plan.steps) {
        final status = service.status.toLowerCase();
        final waiting = status == 'waitingresult' || service.isHeldForResult;
        final state = service.isCompleted
            ? JourneyStepState.completed
            : service.isSkipped
            ? JourneyStepState.skipped
            : waiting
            ? JourneyStepState.waiting
            : !plan.isProposed &&
                  const {'inqueue', 'inprogress'}.contains(status)
            ? JourneyStepState.current
            : JourneyStepState.pending;
        steps.add(
          JourneyStep(
            id: service.id,
            title: service.serviceTypeName,
            location: service.location,
            statusLabel: service.isCompleted
                ? 'Đã có kết quả'
                : service.isSkipped
                ? 'Đã bỏ qua'
                : plan.isProposed
                ? 'Chờ duyệt lộ trình'
                : service.isHeldForResult
                ? 'Chờ kết quả bước trước'
                : status == 'waitingresult'
                ? 'Đang chờ kết quả'
                : status == 'inprogress'
                ? 'Đang thực hiện'
                : status == 'inqueue'
                ? 'Đang chờ gọi số'
                : 'Chưa đến lượt',
            state: state,
            queueNumber:
                !plan.isProposed &&
                    !service.isHeldForResult &&
                    const {'inqueue', 'inprogress'}.contains(status)
                ? service.queueNumber
                : null,
            instruction: service.isSkipped
                ? service.skipReason
                : service.isHeldForResult && service.waitsForResultOf.isNotEmpty
                ? 'Chờ kết quả: ${service.waitsForResultOf.join(', ')}.'
                : service.instruction,
            completedAt: service.resultReadyTime,
            estimatedStartTime: service.estimatedStartTime,
            isService: true,
            timing: timing?.steps[service.id],
          ),
        );
      }
    } else {
      for (final order in summary.preExamOrders) {
        final status = order.status.toLowerCase();
        steps.add(
          JourneyStep(
            id: order.id,
            title: order.serviceTypeName,
            location: '',
            statusLabel: status == 'completed'
                ? 'Đã hoàn tất'
                : status == 'cancelled'
                ? 'Đã hủy'
                : status == 'inprogress'
                ? 'Đang thực hiện'
                : 'Chờ phân phòng',
            state: status == 'completed'
                ? JourneyStepState.completed
                : status == 'cancelled'
                ? JourneyStepState.skipped
                : status == 'inprogress'
                ? JourneyStepState.current
                : JourneyStepState.pending,
            completedAt: order.completedAt,
            isService: true,
          ),
        );
      }
    }
    if (!doctorOrdered) steps.add(consultation());
    final readyForConclusion = doctorOrdered
        ? servicesResolved
        : queue == 'done';
    steps.add(
      JourneyStep(
        id: 'conclusion',
        title: doctorOrdered
            ? 'Bác sĩ đọc kết quả & kết luận'
            : 'Kết luận & hướng dẫn sau khám',
        location: consultLocation,
        statusLabel: finalized
            ? 'Đã hoàn tất lượt khám'
            : readyForConclusion
            ? 'Chờ bác sĩ kết luận'
            : 'Bước tiếp theo',
        state: finalized
            ? JourneyStepState.completed
            : readyForConclusion
            ? JourneyStepState.current
            : JourneyStepState.pending,
        instruction: !finalized && doctorOrdered && servicesResolved
            ? plan.nextAfterPlan
            : null,
      ),
    );
    return PatientJourney._(summary, plan, List.unmodifiable(steps));
  }
}
