import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/hospital_time.dart';
import '../../models/patient_journey_model.dart';
import '../../providers/home_provider.dart';
import '../../widgets/medical_payment_dialog.dart';
import '../../widgets/patient_notifications_sheet.dart';
import '../../widgets/journey_timing_card.dart';
import '../../widgets/journey_next_stop.dart';
import '../../widgets/route_optimization_card.dart';
import '../../services/route_optimization_service.dart';
import '../../services/medical_payment_service.dart';
import '../../services/patient_session_service.dart';

class RouteScreen extends StatefulWidget {
  final RouteOptimizationService? optimizationService;
  final MedicalPaymentService? paymentService;
  final bool isVisible;

  const RouteScreen({
    super.key,
    this.optimizationService,
    this.paymentService,
    this.isVisible = true,
  });

  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen> {
  late final MedicalPaymentService _paymentService =
      widget.paymentService ?? MedicalPaymentService();
  bool _paymentDialogOpen = false;
  (int, String, String)? _reviewedRoute;
  (int, int, String, DateTime?)? _billingKey;
  Future<Map<String, double>>? _billing;

  Future<void> _refreshRoute(HomeProvider home) {
    setState(() => _billing = null);
    return home.refreshJourney(includeFinalized: true);
  }

  @override
  void didUpdateWidget(covariant RouteScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible && !oldWidget.isVisible) _billing = null;
  }

  @override
  void dispose() {
    if (widget.paymentService == null) _paymentService.close();
    super.dispose();
  }

  PatientJourney? _paymentJourney(HomeProvider home) {
    final journey = home.journey;
    final session = PatientSessionService();
    if (journey == null ||
        journey.isFinalized ||
        journey.summary.isEmergency ||
        home.isJourneyStale ||
        session.isDemo ||
        !session.isAuthenticated ||
        home.patientId == null ||
        home.patientId != session.patientId ||
        ApiClient.authToken == null) {
      return null;
    }
    return journey;
  }

  List<MedicalPaymentOrder> _plannedOrders(PatientJourney? journey) {
    final plan = journey?.plan;
    if (journey == null ||
        plan == null ||
        plan.status.toLowerCase() != 'active' ||
        plan.encounterId != journey.summary.encounterId) {
      return const [];
    }
    return [
      for (final step in plan.steps)
        if (step.medicalOrderId case final id?
            when id.isNotEmpty &&
                ['pending', 'inqueue'].contains(step.status.toLowerCase()))
          (id: id, name: step.serviceTypeName),
    ];
  }

  bool _needsReview(PatientJourney? journey, List<MedicalPaymentOrder> orders) {
    final plan = journey?.plan;
    return orders.length >= 2 &&
        plan != null &&
        !plan.isLocked &&
        plan.acceptedOfferSavedMinutes == null &&
        _reviewedRoute !=
            (PatientSessionService().version, plan.encounterId, plan.id);
  }

  Future<Map<String, double>> _billingFor(
    HomeProvider home,
    String encounterId,
  ) {
    final key = (
      PatientSessionService().version,
      ApiClient.sessionVersion,
      encounterId,
      home.lastUpdatedAt,
    );
    if (_billingKey != key) {
      _billingKey = key;
      _billing = null;
    }
    return _billing ??= _paymentService.getOutstandingMedicalOrders(
      encounterId,
      home.patientId!,
    );
  }

  Future<void> _showPayment(HomeProvider home, String encounterId) async {
    final session = (PatientSessionService().version, ApiClient.sessionVersion);
    bool canPay() {
      final journey = _paymentJourney(home);
      final orders = _plannedOrders(journey);
      return mounted &&
          widget.isVisible &&
          session ==
              (PatientSessionService().version, ApiClient.sessionVersion) &&
          journey?.summary.encounterId == encounterId &&
          !_needsReview(journey, orders) &&
          orders.isNotEmpty;
    }

    if (_paymentDialogOpen || !canPay()) return;
    _paymentDialogOpen = true;
    try {
      setState(() => _billing = null);
      Map<String, double> balances;
      try {
        balances = await _billingFor(home, encounterId);
      } catch (_) {
        return; // The payment panel reports the billing error and offers a retry.
      }
      if (!mounted || !canPay()) return;
      final orders = _plannedOrders(_paymentJourney(home))
          .where((item) => balances.containsKey(item.id))
          .toList();
      if (orders.isEmpty) return;
      final outstanding = orders.fold<double>(
        0,
        (sum, item) => sum + balances[item.id]!,
      );
      const serviceName = 'phí cận lâm sàng';
      final payment = await showMedicalPaymentReminder(
        context,
        encounterId: encounterId,
        patientId: home.patientId!,
        orderIds: orders.map((item) => item.id).toList(),
        serviceName: serviceName,
        outstanding: outstanding,
        paymentService: _paymentService,
      );
      final sameVisitSession =
          mounted &&
          session ==
              (PatientSessionService().version, ApiClient.sessionVersion) &&
          home.encounterSummary?.encounterId == encounterId;
      if (payment != null && sameVisitSession) {
        final transferredAmount = payment.transferredAmount;
        var message = payment.billChanged
            ? 'Bảng kê đã thay đổi. Vui lòng kiểm tra tổng tiền mới.'
            : 'Phí cận lâm sàng đã được thanh toán.';
        if (transferredAmount != null) {
          final formattedAmount = formatMedicalPaymentAmount(transferredAmount);
          message =
              'Đã chuyển tiền thành công $formattedAmount cho $serviceName.';
          if (payment.orderCode case final code?) {
            home.addPaymentSuccessNotice(
              encounterId: encounterId,
              orderId: code.toString(),
              message: message,
            );
          }
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: payment.billChanged ? null : AppColors.success,
              content: Text(message),
            ),
          );
        }
        setState(() => _billing = null);
        await home.refreshJourney(includeFinalized: true);
      } else if (canPay()) {
        setState(() => _billing = null);
      }
    } finally {
      _paymentDialogOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) => Consumer<HomeProvider>(
    builder: (context, home, _) {
      final journey = home.journey;
      final paymentJourney = _paymentJourney(home);
      final orders = _plannedOrders(paymentJourney);
      final encounterId = journey?.summary.encounterId;
      final session = PatientSessionService().version;
      final needsReview = _needsReview(paymentJourney, orders);
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Lộ trình khám Sản - Phụ khoa'),
          actions: [
            IconButton(
              tooltip: 'Thông báo lượt khám',
              onPressed: () => showPatientNotifications(
                context,
                optimizationService: widget.optimizationService,
              ),
              icon: Badge(
                isLabelVisible: home.unreadNoticeCount > 0,
                label: Text(home.unreadNoticeCount.toString()),
                child: const Icon(Icons.notifications_none_rounded),
              ),
            ),
            IconButton(
              tooltip: 'Cập nhật lộ trình',
              onPressed: home.isRefreshing ? null : () => _refreshRoute(home),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () => _refreshRoute(home),
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
                      'Lộ trình hiện tại theo thứ tự bác sĩ chỉ định.',
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
                    RouteOptimizationCard(
                      key: ValueKey(
                        'optimize:${PatientSessionService().version}:${home.encounterSummary!.encounterId}',
                      ),
                      encounterId: home.encounterSummary!.encounterId,
                      patientId: home.patientId!,
                      currentPlan: journey.plan,
                      isStale: home.isJourneyStale,
                      allowOptimization: orders.length >= 2,
                      refreshToken: home.lastUpdatedAt,
                      service: widget.optimizationService,
                      onRouteReviewed: orders.length < 2
                          ? null
                          : (planId) {
                              if (mounted &&
                                  session == PatientSessionService().version) {
                                setState(
                                  () => _reviewedRoute = (
                                    session,
                                    encounterId!,
                                    planId,
                                  ),
                                );
                              }
                            },
                      onChanged: () =>
                          home.refreshJourney(includeFinalized: true),
                    ),
                  ],
                  if (encounterId != null &&
                      orders.isNotEmpty &&
                      widget.isVisible)
                    _paymentPanel(home, encounterId, orders, needsReview),
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

  Widget _paymentPanel(
    HomeProvider home,
    String encounterId,
    List<MedicalPaymentOrder> orders,
    bool needsReview,
  ) => FutureBuilder<Map<String, double>>(
    future: _billingFor(home, encounterId),
    builder: (context, billing) {
      if (billing.connectionState != ConnectionState.done) {
        return const SizedBox.shrink();
      }
      if (billing.hasError) {
        return _warning(
          'Chưa xác minh được các khoản còn phải trả.',
          onRetry: () => setState(() => _billing = null),
        );
      }
      final outstanding = billing.data!;
      final payable = orders
          .where((order) => outstanding.containsKey(order.id))
          .toList();
      if (payable.isEmpty) return const SizedBox.shrink();
      if (needsReview) {
        return const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text('Kiểm tra phương án tối ưu trước khi thanh toán.'),
        );
      }
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Thanh toán cận lâm sàng',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              for (final order in payable)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    '${order.name} · ${formatMedicalPaymentAmount(outstanding[order.id]!)}',
                  ),
                ),
              const SizedBox(height: 8),
              _paymentButton(
                payable.fold<double>(
                  0,
                  (sum, order) => sum + outstanding[order.id]!,
                ),
                () => _showPayment(home, encounterId),
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _paymentButton(double amount, VoidCallback onPressed) => SizedBox(
    width: double.infinity,
    child: OutlinedButton.icon(
      style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft),
      onPressed: onPressed,
      icon: const Icon(Icons.qr_code_2_rounded),
      label: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Thanh toán tổng phí'),
            Text(
              'Tổng còn phải trả: ${formatMedicalPaymentAmount(amount)}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    ),
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
