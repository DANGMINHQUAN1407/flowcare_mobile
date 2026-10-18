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
  final bool isInProgress;
  final bool isWaitingForResult;

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
    this.isInProgress = false,
    this.isWaitingForResult = false,
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
      if (step.state == JourneyStepState.current && step.isInProgress) {
        return step;
      }
    }
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
    final nursing = summary.nursingIntake;
    final nursingComplete = nursing?.isComplete == true;
    // Queue progress is not proof that the two nursing records were saved.
    // An older/incomplete record remains visible without sending the patient
    // backwards once the consultation or doctor-ordered services have begun.
    final beyondNursing =
        finalized ||
        doctorOrdered ||
        const {'inprogress', 'done'}.contains(queue);
    final nursingCurrent =
        checkedIn &&
        !beyondNursing &&
        !nursingComplete &&
        !preExamUnresolved &&
        (plan == null || servicesResolved);
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

    JourneyStep nursingIntake() => JourneyStep(
      id: 'nursing-intake',
      title: 'Điều dưỡng tiếp nhận & đo sinh hiệu',
      location: summary.roomName?.trim() ?? '',
      statusLabel: nursingComplete
          ? 'Đã ghi nhận đủ thông tin'
          : nursing == null
          ? 'Chưa có cập nhật điều dưỡng'
          : beyondNursing
          ? 'Chưa đủ ghi nhận điều dưỡng'
          : nursing.hasStarted
          ? 'Đang tiếp nhận điều dưỡng'
          : queue == 'called'
          ? 'Đã gọi — mời đến điều dưỡng'
          : 'Chờ điều dưỡng tiếp nhận',
      state: nursingComplete
          ? JourneyStepState.completed
          : nursingCurrent
          ? JourneyStepState.current
          : JourneyStepState.pending,
      instruction: nursing == null
          ? 'Chưa nhận được trạng thái khai báo và sinh hiệu từ bệnh viện.'
          : 'Khai báo sản phụ khoa: ${nursing.hasIntake ? 'Đã lưu' : 'Chưa ghi nhận'}.\n'
                'Sinh hiệu: ${nursing.hasVitalSigns ? 'Đã ghi nhận' : 'Chưa ghi nhận'}.',
      completedAt: nursing?.completedAt,
      queueNumber: nursingCurrent ? summary.queueNumber : null,
      isInProgress: nursingCurrent && nursing?.hasStarted == true,
    );

    JourneyStep consultation({bool beforeServices = false}) {
      final completed = finalized || beforeServices || queue == 'done';
      final blockedByServices =
          !beforeServices &&
          ((plan != null && !servicesResolved) || preExamUnresolved);
      final blockedByNursing = nursingCurrent;
      final state = completed
          ? JourneyStepState.completed
          : !checkedIn || blockedByServices || blockedByNursing
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
            : blockedByNursing
            ? 'Sau tiếp nhận điều dưỡng'
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
        isInProgress: !completed && queue == 'inprogress',
      );
    }

    if (doctorOrdered) {
      steps.add(nursingIntake());
      steps.add(consultation(beforeServices: true));
    }
    if (plan != null) {
      for (final service in plan.steps) {
        final status = service.status.toLowerCase();
        final awaitingPublication =
            service.isCompleted && !service.hasPublishedResult;
        final waiting =
            status == 'waitingresult' ||
            service.isHeldForResult ||
            awaitingPublication;
        final state = service.hasPublishedResult
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
            statusLabel: service.hasPublishedResult
                ? 'Đã có kết quả'
                : service.isSkipped
                ? 'Đã bỏ qua'
                : plan.isProposed
                ? 'Chờ duyệt lộ trình'
                : awaitingPublication
                ? service.isResultFinalized == false
                      ? 'Đã thực hiện · Chờ chốt kết quả'
                      : 'Đã thực hiện · Chưa xác nhận kết quả'
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
            instruction: awaitingPublication
                ? 'Dịch vụ đã thực hiện. Phiếu kết quả cần được nhập đầy đủ và chốt trước khi thông báo đã có kết quả.'
                : service.isSkipped
                ? service.skipReason
                : service.isHeldForResult && service.waitsForResultOf.isNotEmpty
                ? 'Chờ kết quả: ${service.waitsForResultOf.join(', ')}.'
                : service.instruction,
            completedAt: service.hasPublishedResult
                ? service.resultFinalizedAt ?? service.resultReadyTime
                : null,
            estimatedStartTime: service.estimatedStartTime,
            isService: true,
            timing: timing?.steps[service.id],
            isInProgress: !plan.isProposed && status == 'inprogress',
            isWaitingForResult: waiting,
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
            isInProgress: status == 'inprogress',
          ),
        );
      }
    }
    if (!doctorOrdered) {
      steps.add(nursingIntake());
      steps.add(consultation());
    }
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
