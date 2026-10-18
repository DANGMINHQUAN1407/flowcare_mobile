import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/hospital_time.dart';
import '../../models/patient_journey_model.dart';
import '../../providers/home_provider.dart';
import '../../widgets/patient_notifications_sheet.dart';
import '../../widgets/journey_timing_card.dart';
import '../../widgets/journey_next_stop.dart';
import '../../widgets/route_assistance_card.dart';
import '../../services/route_assistance_service.dart';
import '../../services/patient_session_service.dart';

class RouteScreen extends StatelessWidget {
  final RouteAssistanceService? assistanceService;
  const RouteScreen({super.key, this.assistanceService});

  @override
  Widget build(BuildContext context) => Consumer<HomeProvider>(
    builder: (context, home, _) {
      final journey = home.journey;
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Lộ trình khám Sản - Phụ khoa'),
          actions: [
            IconButton(
              tooltip: 'Thông báo lượt khám',
              onPressed: () => showPatientNotifications(context),
              icon: Badge(
                isLabelVisible: home.unreadNoticeCount > 0,
                label: Text(home.unreadNoticeCount.toString()),
                child: const Icon(Icons.notifications_none_rounded),
              ),
            ),
            IconButton(
              tooltip: 'Cập nhật lộ trình',
              onPressed: home.isRefreshing
                  ? null
                  : () => home.refreshJourney(includeFinalized: true),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () => home.refreshJourney(includeFinalized: true),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                if (home.visits.length > 1) ...[
                  _visitSelector(home),
                  const SizedBox(height: 16),
                ],
                if (home.errorMessage != null)
                  _warning(
                    home.errorMessage!,
                    onRetry: () => home.loadHomeData(isRefresh: true),
                  ),
                if (home.journeyError != null && journey == null)
                  _warning(
                    home.journeyError!,
                    onRetry: () => home.refreshJourney(includeFinalized: true),
                  ),
                if (home.isLoading && journey == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 64),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (journey == null)
                  _emptyState(home)
                else ...[
                  _syncStatus(home),
                  const SizedBox(height: 12),
                  _statusBanner(
                    journey,
                    isStale: home.isJourneyStale,
                    hasSnapshot: home.lastUpdatedAt != null,
                  ),
                  if (journey.plan?.followsOriginalOrder == true) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Lộ trình ban đầu theo thứ tự chỉ định. Bạn có thể nhờ tối ưu; phương án mới cần bác sĩ duyệt trước khi áp dụng.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  if (!journey.isFinalized &&
                      !PatientSessionService().isDemo &&
                      home.patientId != null) ...[
                    const SizedBox(height: 16),
                    RouteAssistanceCard(
                      key: ValueKey(
                        'support:${PatientSessionService().version}:${home.encounterSummary!.encounterId}',
                      ),
                      encounterId: home.encounterSummary!.encounterId,
                      patientId: home.patientId!,
                      isStale: home.isJourneyStale,
                      refreshToken: home.lastUpdatedAt,
                      service: assistanceService,
                      onApplied: () =>
                          home.refreshJourney(includeFinalized: true),
                    ),
                  ],
                  if (journey.timing != null) ...[
                    const SizedBox(height: 16),
                    JourneyTimingSummary(
                      timing: journey.timing!,
                      historical: journey.isFinalized,
                    ),
                  ],
                  const SizedBox(height: 22),
                  Text(
                    journey.isFinalized
                        ? 'Hành trình khám đã hoàn tất'
                        : 'Hành trình khám của bạn',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${journey.resolvedCount}/${journey.steps.length} bước đã xử lý',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: journey.steps.isEmpty
                          ? 0
                          : journey.resolvedCount / journey.steps.length,
                      minHeight: 6,
                      backgroundColor: AppColors.border,
                      color: journey.isFinalized
                          ? AppColors.success
                          : AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 22),
                  for (var i = 0; i < journey.steps.length; i++)
                    _stepTile(
                      journey.steps[i],
                      i,
                      isLast: i == journey.steps.length - 1,
                      finalized: journey.isFinalized,
                    ),
                  const SizedBox(height: 12),
                  const Text(
                    'Tiến trình được cập nhật từ thao tác của bác sĩ và nhân viên tại các phòng khám.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _visitSelector(HomeProvider home) {
    final selected = home.encounterSummary?.encounterId;
    final exists = home.visits.any((v) => v.encounterId == selected);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lượt khám',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: exists ? selected : null,
              isExpanded: true,
              hint: const Text('Chọn lượt khám'),
              items: home.visits
                  .map(
                    (visit) => DropdownMenuItem(
                      value: visit.encounterId,
                      child: Text(
                        '${visit.visitTime.millisecondsSinceEpoch == 0 ? 'Chưa có ngày khám' : hospitalTime(visit.visitTime, pattern: 'dd/MM/yyyy')} · ${visit.serviceTypeName}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: home.isLoading
                  ? null
                  : (id) {
                      if (id != null) home.selectVisit(id);
                    },
            ),
          ),
        ],
      ),
    );
  }

  Widget _syncStatus(HomeProvider home) {
    final stale = home.isJourneyStale;
    final finalized = home.journey?.isFinalized == true;
    final title = home.isRefreshing
        ? 'Đang cập nhật lộ trình…'
        : home.isJourneyOffline
        ? 'Mất kết nối máy chủ'
        : stale
        ? 'Chưa cập nhật được lộ trình'
        : finalized
        ? 'Lịch sử lượt khám'
        : home.isRealtimeConnected
        ? 'Đang đồng bộ trực tiếp'
        : home.updatesEnabled
        ? 'Đang cập nhật định kỳ'
        : 'Đã tải lộ trình';
    final color = stale ? AppColors.warning : AppColors.textSecondary;
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const ValueKey('journey-sync-status'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: stale ? AppColors.warningLight : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  home.isJourneyOffline
                      ? Icons.wifi_off_rounded
                      : stale
                      ? Icons.sync_problem_rounded
                      : finalized
                      ? Icons.history_rounded
                      : Icons.sync_rounded,
                  color: color,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              home.lastUpdatedAt == null
                  ? 'Chưa có lần cập nhật đầy đủ.'
                  : '${stale ? 'Đang hiển thị dữ liệu cập nhật lúc' : 'Cập nhật lúc'} ${hospitalTime(home.lastUpdatedAt!, pattern: 'dd/MM HH:mm:ss')}',
              style: const TextStyle(
                fontSize: 11,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
            if (stale ||
                (!finalized &&
                    home.updatesEnabled &&
                    !home.isRealtimeConnected)) ...[
              const SizedBox(height: 4),
              Text(
                home.updatesEnabled && (!finalized || stale)
                    ? 'Tự kiểm tra lại mỗi 20 giây. Bạn cũng có thể bấm cập nhật.'
                    : 'Bấm cập nhật để thử kết nối lại.',
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusBanner(
    PatientJourney journey, {
    required bool isStale,
    required bool hasSnapshot,
  }) {
    final finalized = journey.isFinalized;
    final current = journey.currentStep;
    final emergency = journey.summary.isEmergency && !finalized;
    final accent = finalized
        ? AppColors.success
        : emergency
        ? AppColors.emergency
        : AppColors.primary;
    final title = finalized
        ? 'Đã hoàn tất lượt khám'
        : emergency
        ? 'Lượt khám ưu tiên cấp cứu'
        : current?.statusLabel ?? 'Đang chờ cập nhật tiến trình';
    final instruction = finalized
        ? 'Bạn có thể xem lại các bước và phòng đã thực hiện bên dưới.'
        : emergency
        ? 'Vui lòng làm theo hướng dẫn trực tiếp của nhân viên y tế.'
        : current?.title ?? 'Nhân viên y tế sẽ hướng dẫn bước tiếp theo.';
    return Container(
      key: const ValueKey('journey-status-banner'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                finalized ? Icons.check_circle_rounded : Icons.route_rounded,
                color: accent,
                size: 28,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            journey.summary.patientName,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          if (journey.summary.checkInTime != null) ...[
            const SizedBox(height: 3),
            Text(
              'Lượt khám ngày ${hospitalTime(journey.summary.checkInTime!, pattern: 'dd/MM/yyyy')}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (finalized || emergency)
            Text(instruction, style: const TextStyle(fontSize: 13, height: 1.5))
          else if (isStale && !hasSnapshot)
            const Text(
              'Chưa đủ dữ liệu để hướng dẫn di chuyển. Hãy cập nhật lại hoặc hỏi nhân viên y tế.',
              style: TextStyle(fontSize: 13, height: 1.5),
            )
          else
            JourneyNextStop(journey: journey, isStale: isStale),
        ],
      ),
    );
  }

  Widget _stepTile(
    JourneyStep step,
    int index, {
    required bool isLast,
    required bool finalized,
  }) {
    final state = step.state;
    final color = switch (state) {
      JourneyStepState.completed => AppColors.success,
      JourneyStepState.current => AppColors.primary,
      JourneyStepState.waiting => AppColors.warning,
      JourneyStepState.skipped => AppColors.textSecondary,
      JourneyStepState.pending => AppColors.textTertiary,
    };
    final icon = switch (state) {
      JourneyStepState.completed => Icons.check_rounded,
      JourneyStepState.waiting => Icons.hourglass_bottom_rounded,
      JourneyStepState.skipped => Icons.skip_next_rounded,
      _ =>
        step.id == 'nursing-intake'
            ? Icons.health_and_safety_outlined
            : step.isService
            ? Icons.biotech_rounded
            : Icons.medical_services_outlined,
    };
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.13),
                  ),
                  child: Icon(icon, color: color, size: 21),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      color: AppColors.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: isLast ? 0 : 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: state == JourneyStepState.current
                      ? color
                      : AppColors.border,
                  width: state == JourneyStepState.current ? 1.5 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${index + 1}. ${step.title}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      step.statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                  if (step.location.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      step.location,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                  if (step.timing != null) ...[
                    const SizedBox(height: 12),
                    JourneyStepTimingCard(
                      timing: step.timing!,
                      historical:
                          finalized ||
                          state == JourneyStepState.completed ||
                          state == JourneyStepState.skipped,
                    ),
                  ],
                  if (step.queueNumber != null && !finalized) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Số thứ tự #${step.queueNumber}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                  if (step.completedAt != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      hospitalTime(step.completedAt!, pattern: 'dd/MM HH:mm'),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  if (step.instruction?.isNotEmpty == true &&
                      (step.id == 'nursing-intake' ||
                          (!finalized &&
                              state != JourneyStepState.completed))) ...[
                    const SizedBox(height: 8),
                    Text(
                      step.instruction!,
                      style: const TextStyle(fontSize: 12, height: 1.5),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _warning(String message, {VoidCallback? onRetry}) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.warningLight,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message, style: const TextStyle(fontSize: 12, height: 1.5)),
        if (onRetry != null)
          TextButton(onPressed: onRetry, child: const Text('Thử lại')),
      ],
    ),
  );

  Widget _emptyState(HomeProvider home) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48),
    child: Column(
      children: [
        const Icon(
          Icons.route_outlined,
          size: 52,
          color: AppColors.textTertiary,
        ),
        const SizedBox(height: 18),
        Text(
          home.isJourneyStale
              ? 'Chưa tải được lộ trình'
              : 'Chưa có lượt khám để theo dõi',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          home.isJourneyStale
              ? 'Hãy thử cập nhật lại khi kết nối đến máy chủ hoạt động.'
              : 'Lộ trình sẽ hiển thị sau khi bệnh viện tiếp nhận lượt khám.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.6,
          ),
        ),
      ],
    ),
  );
}
