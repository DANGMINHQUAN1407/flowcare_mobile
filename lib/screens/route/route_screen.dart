import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/encounter_summary_model.dart';
import '../../providers/home_provider.dart';

class RouteScreen extends StatelessWidget {
  const RouteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<HomeProvider>(
      builder: (context, homeProvider, child) {
        final hasEncounter = homeProvider.hasActiveEncounter;
        final summary = homeProvider.encounterSummary;
        final isEmergency = summary?.isEmergency ?? false;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Lộ trình khám Sản - Phụ khoa'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Cập nhật lộ trình',
                onPressed: () => homeProvider.loadHomeData(isRefresh: true),
              ),
            ],
          ),
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: () => homeProvider.loadHomeData(isRefresh: true),
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Banner
                    _buildStatusBanner(summary, hasEncounter, isEmergency),

                    const SizedBox(height: 20),

                    // Pre-exam Orders Section (Nếu có chỉ định cận lâm sàng)
                    if (hasEncounter && summary!.preExamOrders.isNotEmpty) ...[
                      _buildPreExamOrdersSection(summary.preExamOrders),
                      const SizedBox(height: 20),
                    ],

                    // Dynamic Journey Timeline
                    Text(
                      hasEncounter ? 'Hành trình khám trực tiếp của bạn' : 'Quy trình khám Sản - Phụ khoa tiêu chuẩn',
                      style: AppTextStyles.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasEncounter
                          ? 'Vị trí hiện tại được hệ thống AI tự động cập nhật theo tiến trình khám.'
                          : 'Lộ trình tối ưu hóa giúp mẹ & bé giảm thiểu di chuyển giữa các tầng.',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 14),

                    _buildJourneyTimeline(summary),

                    const SizedBox(height: 24),

                    // AI Routing explanation card
                    _buildAiRoutingGuideCard(),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBanner(EncounterSummaryModel? summary, bool hasEncounter, bool isEmergency) {
    if (!hasEncounter) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.secondaryLight.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.secondary.withValues(alpha: 0.2)),
        ),
        child: const Row(
          children: [
            Icon(Icons.alt_route_rounded, color: AppColors.secondary, size: 26),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trạng thái: Chưa check-in tại viện',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Sau khi tiếp tân check-in, số thứ tự và phòng khám AI sẽ tự động hiển thị tại đây.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final deptName = summary?.departmentName ?? 'Khoa Khám Sản - Phụ Khoa';
    final waitMin = summary?.estimatedWaitMinutes ?? 5;
    final queueNum = summary?.queueNumber;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isEmergency ? AppColors.emergencyLight : AppColors.primaryLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isEmergency ? AppColors.emergency : AppColors.primary, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: (isEmergency ? AppColors.emergency : AppColors.primary).withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isEmergency ? AppColors.emergency : AppColors.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isEmergency ? '🚨 CẤP CỨU SẢN KHOA' : 'ĐANG ĐƯỢC TIẾP ĐÓN',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const Spacer(),
              if (queueNum != null)
                Text(
                  'Số thứ tự: #$queueNum',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: isEmergency ? AppColors.emergency : AppColors.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Phòng chỉ định: $deptName (Phòng khám Sản VIP 1)',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Thời gian chờ ước tính: ~$waitMin phút (AI tự động điều phối)',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildPreExamOrdersSection(List<PreExamOrderModel> orders) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.biotech_outlined, color: AppColors.secondary, size: 20),
              SizedBox(width: 8),
              Text(
                'Chỉ định Cận lâm sàng trước khám (Pre-exam)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Vui lòng thực hiện các dịch vụ cận lâm sàng dưới đây trước khi vào phòng bác sĩ.',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          ...orders.map((o) {
            final isDone = o.status.toLowerCase() == 'completed';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDone ? AppColors.successLight.withValues(alpha: 0.5) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDone ? AppColors.success.withValues(alpha: 0.3) : AppColors.border,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isDone ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
                    color: isDone ? AppColors.success : AppColors.secondary,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      o.serviceTypeName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDone ? AppColors.success : AppColors.textPrimary,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDone ? AppColors.success : Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isDone ? 'Đã thực hiện' : 'Chờ thực hiện',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isDone ? Colors.white : Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildJourneyTimeline(EncounterSummaryModel? summary) {
    final status = summary?.encounterStatus.toLowerCase() ?? '';
    final isCheckedIn = status == 'checkedin' || status == 'routed' || status == 'inqueue' || status == 'inconsultation' || status == 'completed';
    final hasPreExam = summary != null && summary.preExamOrders.isNotEmpty;
    final isPreExamDone = hasPreExam && summary.preExamOrders.every((o) => o.status.toLowerCase() == 'completed');
    final isConsulting = status == 'inconsultation';
    final isCompleted = status == 'completed';

    return Column(
      children: [
        _buildTimelineStep(
          stepNumber: '1',
          title: 'Tiếp đón & Đo sinh hiệu thai sản',
          room: 'Quầy tiếp đón & Phòng đo huyết áp (Tầng 1 - Khu A)',
          status: isCheckedIn ? 'Đã hoàn tất' : 'Chờ check-in',
          isCompleted: isCheckedIn,
          isCurrent: !isCheckedIn,
          icon: Icons.how_to_reg_rounded,
        ),
        _buildTimelineStep(
          stepNumber: '2',
          title: 'Cận lâm sàng (Siêu âm thai 2D/4D / Xét nghiệm)',
          room: 'Phòng Siêu âm 104 / Phòng Xét nghiệm 108 (Khu B)',
          status: !hasPreExam
              ? 'Không có chỉ định'
              : (isPreExamDone ? 'Đã hoàn tất' : (isCheckedIn ? 'Đang thực hiện' : 'Chờ tiếp đón')),
          isCompleted: hasPreExam ? isPreExamDone : isCheckedIn,
          isCurrent: hasPreExam && isCheckedIn && !isPreExamDone,
          icon: Icons.biotech_rounded,
        ),
        _buildTimelineStep(
          stepNumber: '3',
          title: 'Khám chuyên khoa & Tư vấn Sản - Phụ khoa',
          room: summary?.departmentName != null
              ? '${summary!.departmentName} • Phòng khám Sản VIP 1 (P.301)'
              : 'Phòng khám Sản VIP 1 (Tầng 2 - Khu B)',
          status: isCompleted
              ? 'Đã hoàn tất'
              : (isConsulting ? 'Đang trong phòng khám' : (isCheckedIn ? 'Đang chờ gọi số' : 'Bước tiếp theo')),
          isCompleted: isCompleted,
          isCurrent: isConsulting || (isCheckedIn && (!hasPreExam || isPreExamDone) && !isCompleted),
          icon: Icons.medical_services_rounded,
        ),
        _buildTimelineStep(
          stepNumber: '4',
          title: 'Bác sĩ kết luận & Nhận đơn thuốc / Hướng dẫn',
          room: 'Bàn hướng dẫn & Quầy phát thuốc Bệnh viện Phụ Sản',
          status: isCompleted ? 'Hoàn tất lượt khám' : 'Bước cuối',
          isCompleted: isCompleted,
          isCurrent: false,
          isLast: true,
          icon: Icons.task_alt_rounded,
        ),
      ],
    );
  }

  Widget _buildTimelineStep({
    required String stepNumber,
    required String title,
    required String room,
    required String status,
    required bool isCompleted,
    required bool isCurrent,
    required IconData icon,
    bool isLast = false,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step indicator & line
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? AppColors.success
                      : isCurrent
                          ? AppColors.primary
                          : Colors.grey.shade200,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isCompleted
                        ? AppColors.success
                        : isCurrent
                            ? AppColors.primary
                            : AppColors.border,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: isCompleted
                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                      : Icon(
                          icon,
                          size: 16,
                          color: isCurrent ? Colors.white : AppColors.textSecondary,
                        ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isCompleted ? AppColors.success.withValues(alpha: 0.5) : AppColors.border,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16.0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isCurrent ? AppColors.primaryLight.withValues(alpha: 0.4) : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isCurrent ? AppColors.primary : AppColors.border,
                    width: isCurrent ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isCurrent ? AppColors.primary : AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isCompleted
                                ? AppColors.successLight
                                : (isCurrent ? AppColors.primaryLight : AppColors.surfaceVariant),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isCompleted
                                  ? AppColors.success
                                  : (isCurrent ? AppColors.primary : AppColors.textSecondary),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.room_outlined, size: 13, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            room,
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiRoutingGuideCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            color: AppColors.primary,
            size: 22,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Thuật toán FlowCare AI liên tục tính toán độ dài hàng đợi và ưu tiên thai phụ để đề xuất luồng di chuyển nhanh nhất.',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
