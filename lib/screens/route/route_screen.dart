import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/hospital_time.dart';
import '../../models/patient_journey_model.dart';
import '../../providers/home_provider.dart';
import '../../widgets/patient_notifications_sheet.dart';
import '../../widgets/journey_timing_card.dart';

class RouteScreen extends StatelessWidget {
  const RouteScreen({super.key});

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
                  : () => home.loadHomeData(isRefresh: true),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () => home.loadHomeData(isRefresh: true),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                if (home.visits.isNotEmpty) ...[
                  _visitSelector(home),
                  const SizedBox(height: 16),
                ],
                if (home.errorMessage != null)
                  _warning(
                    home.errorMessage!,
                    onRetry: () => home.loadHomeData(isRefresh: true),
                  ),
                if (home.journeyError != null)
                  _warning(
                    home.journeyError!,
                    onRetry: () => home.loadHomeData(isRefresh: true),
                  ),
                if (home.isLoading && journey == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 64),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (journey == null)
                  _emptyState(home)
                else ...[
                  _statusBanner(journey),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Icon(
                        journey.isFinalized
                            ? Icons.history_rounded
                            : home.isRealtimeConnected
                            ? Icons.wifi_rounded
                            : Icons.sync_rounded,
                        size: 15,
                        color: AppColors.textSecondary,
                      ),
                      Text(
                        journey.isFinalized
                            ? 'Lịch sử lượt khám'
                            : home.isRefreshing
                            ? 'Đang cập nhật...'
                            : home.isRealtimeConnected
                            ? 'Đang đồng bộ trực tiếp'
                            : 'Tự cập nhật mỗi 20 giây',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (home.lastUpdatedAt != null)
                        Text(
                          '· ${hospitalTime(home.lastUpdatedAt!, pattern: 'HH:mm:ss')}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                  if (journey.timing != null) ...[
                    const SizedBox(height: 16),
                    JourneyTimingSummary(timing: journey.timing!),
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
                  if (journey.plan?.isProposed == true)
                    _warning(
                      'Lộ trình cận lâm sàng đang chờ nhân viên y tế duyệt. Hãy chờ hướng dẫn trước khi di chuyển.',
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
                        '${hospitalTime(visit.visitTime, pattern: 'dd/MM/yyyy')} · ${visit.serviceTypeName}',
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

  Widget _statusBanner(PatientJourney journey) {
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
          Text(instruction, style: const TextStyle(fontSize: 13, height: 1.5)),
          if (!finalized && current?.location.isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Text(
              current!.location,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
          ],
          if (!finalized && current?.queueNumber != null) ...[
            const SizedBox(height: 10),
            Text(
              'Số thứ tự: #${current!.queueNumber}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: accent,
              ),
            ),
          ],
          if (!finalized && current?.timing != null) ...[
            const SizedBox(height: 12),
            JourneyTravelHighlight(minutes: current!.timing!.travelMinutes),
            const SizedBox(height: 6),
            Text(
              'Chờ trước dịch vụ dự kiến: ${journeyMinutes(current.timing!.waitBeforeServiceMinutes)}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (!finalized &&
              current?.isService == true &&
              current?.estimatedStartTime != null &&
              current!.estimatedStartTime!.isAfter(DateTime.now())) ...[
            const SizedBox(height: 8),
            Text(
              'Dự kiến đến lượt: ${hospitalTime(current.estimatedStartTime!, pattern: 'HH:mm')}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (!finalized &&
              current?.id == 'consultation' &&
              journey.summary.queueStatus?.toLowerCase() == 'waiting' &&
              journey.summary.estimatedWaitMinutes != null &&
              journey.summary.checkInTime != null &&
              isSameHospitalDay(
                journey.summary.checkInTime!,
                DateTime.now(),
              )) ...[
            const SizedBox(height: 8),
            Text(
              'Thời gian chờ ước tính: ~${journey.summary.estimatedWaitMinutes} phút',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
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
        step.isService
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
                    JourneyStepTimingCard(timing: step.timing!),
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
                      !finalized &&
                      state != JourneyStepState.completed) ...[
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
        const Text(
          'Chưa có lượt khám để theo dõi',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          home.currentPhone.isEmpty
              ? 'Tra cứu số điện thoại ở Trang chủ để xem lượt khám của bạn.'
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
