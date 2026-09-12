import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../models/appointment_model.dart';
import '../../models/medical_record_model.dart';
import '../../providers/history_provider.dart';
import '../../providers/home_provider.dart';
import '../../providers/booking_provider.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/error_state_widget.dart';
import '../../widgets/loading_state_widget.dart';

class HistoryScreen extends StatelessWidget {
  final void Function(int tabIndex)? onNavigateToTab;

  const HistoryScreen({
    super.key,
    this.onNavigateToTab,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer2<HomeProvider, HistoryProvider>(
      builder: (context, homeProvider, historyProvider, child) {
        final patient = homeProvider.patient;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Lịch sử lịch hẹn & Khám'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Làm mới',
                onPressed: () => historyProvider.loadAppointments(
                  patient?.id,
                  isRefresh: true,
                  phone: homeProvider.currentPhone,
                  patientName: patient?.fullName,
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: () => historyProvider.loadAppointments(
                patient?.id,
                isRefresh: true,
                phone: homeProvider.currentPhone,
                patientName: patient?.fullName,
              ),
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header summary banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withValues(alpha: 0.08),
                            AppColors.secondary.withValues(alpha: 0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.folder_shared_rounded,
                              color: AppColors.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Sổ bệnh án & Lịch hẹn điện tử',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  patient != null
                                      ? 'Hồ sơ y tế của: ${patient.fullName}'
                                      : 'Đồng bộ hồ sơ khám bệnh FlowCare AI',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Segmented Tab Selector
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildTabButton(
                              context: context,
                              title: 'Lịch hẹn trực tuyến',
                              icon: Icons.calendar_month_rounded,
                              isSelected: historyProvider.selectedTabIndex == 0,
                              count: historyProvider.appointments.length,
                              onTap: () => historyProvider.setTab(0),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: _buildTabButton(
                              context: context,
                              title: 'Sổ khám & Đơn thuốc',
                              icon: Icons.medical_services_rounded,
                              isSelected: historyProvider.selectedTabIndex == 1,
                              count: historyProvider.medicalRecords.length,
                              onTap: () => historyProvider.setTab(1),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Content Body based on state
                    _buildHistoryContent(context, homeProvider, historyProvider),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabButton({
    required BuildContext context,
    required String title,
    required IconData icon,
    required bool isSelected,
    required int count,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withValues(alpha: 0.25) : AppColors.border,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryContent(
    BuildContext context,
    HomeProvider homeProvider,
    HistoryProvider historyProvider,
  ) {
    if (historyProvider.isLoading) {
      return const LoadingStateWidget(
        message: 'Đang tải dữ liệu hồ sơ từ hệ thống bệnh viện...',
      );
    }

    if (historyProvider.errorMessage != null) {
      return ErrorStateWidget(
        message: historyProvider.errorMessage!,
        onRetry: () => historyProvider.retry(
          homeProvider.patient?.id,
          phone: homeProvider.currentPhone,
          patientName: homeProvider.patient?.fullName,
        ),
      );
    }

    if (homeProvider.patient == null) {
      return EmptyStateWidget(
        icon: Icons.person_search_rounded,
        title: 'Chưa có thông tin bệnh nhân',
        message: 'Vui lòng kiểm tra lại số điện thoại để tra cứu hồ sơ.',
        ctaText: 'Đồng bộ hồ sơ',
        onCtaPressed: () => homeProvider.loadHomeData(),
      );
    }

    // TAB 0: LỊCH HẸN TRỰC TUYẾN
    if (historyProvider.selectedTabIndex == 0) {
      if (historyProvider.appointments.isEmpty) {
        return const EmptyStateWidget(
          icon: Icons.event_busy_rounded,
          title: 'Chưa có lịch hẹn nào',
          message: 'Bệnh nhân chưa phát sinh lượt đăng ký khám trực tuyến nào.',
        );
      }

      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: historyProvider.appointments.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final appointment = historyProvider.appointments[index];
          return _buildAppointmentCard(context, appointment);
        },
      );
    }

    // TAB 1: SỔ KHÁM BỆNH & ĐƠN THUỐC ĐIỆN TỬ
    if (historyProvider.medicalRecords.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.medical_information_outlined,
        title: 'Chưa có lượt khám hoàn tất',
        message: 'Hồ sơ khám và đơn thuốc sẽ xuất hiện tại đây sau khi Bác sĩ hoàn tất khám.',
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: historyProvider.medicalRecords.length,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final record = historyProvider.medicalRecords[index];
        return _buildMedicalRecordCard(context, record);
      },
    );
  }

  // --- APPOINTMENT CARD ---
  Widget _buildAppointmentCard(BuildContext context, AppointmentModel appointment) {
    final lowerName = appointment.serviceTypeName.toLowerCase();
    final isPrenatal = lowerName.contains('thai') || lowerName.contains('sản');
    final isGyn = lowerName.contains('phụ khoa') || lowerName.contains('gyn');

    Color categoryColor = AppColors.secondary;
    Color categoryBg = AppColors.secondaryLight;
    String categoryLabel = 'Sản - Phụ khoa khác';
    IconData categoryIcon = Icons.medical_services_outlined;

    if (isPrenatal) {
      categoryColor = AppColors.maternityPink;
      categoryBg = AppColors.maternityPinkLight;
      categoryLabel = 'Khám thai & Mẹ bé';
      categoryIcon = Icons.pregnant_woman_rounded;
    } else if (isGyn) {
      categoryColor = AppColors.primary;
      categoryBg = AppColors.primaryLight;
      categoryLabel = 'Khám phụ khoa';
      categoryIcon = Icons.spa_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: categoryBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(categoryIcon, size: 14, color: categoryColor),
                    const SizedBox(width: 4),
                    Text(
                      categoryLabel,
                      style: TextStyle(
                        color: categoryColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(appointment.status),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            appointment.serviceTypeName,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.access_time_rounded, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                DateFormat('HH:mm - dd/MM/yyyy').format(appointment.scheduledTime),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.tag_rounded, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                'Mã lịch hẹn: ${appointment.id.substring(0, appointment.id.length > 8 ? 8 : appointment.id.length).toUpperCase()}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- MEDICAL RECORD CARD (ENCOUNTER & PRESCRIPTIONS) ---
  Widget _buildMedicalRecordCard(BuildContext context, MedicalRecordModel record) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.success.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.successLight.withValues(alpha: 0.4),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              border: Border(
                bottom: BorderSide(color: AppColors.success.withValues(alpha: 0.2)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          record.departmentName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Đã hoàn tất',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        'STT: ${record.ticketNumber}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      record.roomName,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Doctor & Vital signs
                Row(
                  children: [
                    const Icon(Icons.person_rounded, size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Bác sĩ: ${record.doctorName}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      DateFormat('dd/MM/yyyy').format(record.visitDate),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),

                if (record.vitalSigns != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildVitalBadge('Tuần thai', '${record.vitalSigns!.gestationalWeeks}w', Icons.child_care_rounded),
                        _buildVitalBadge('Huyết áp', record.vitalSigns!.bloodPressure, Icons.favorite_border_rounded),
                        _buildVitalBadge('Tim thai', '${record.vitalSigns!.fetalHeartRate} bpm', Icons.monitor_heart_rounded),
                        _buildVitalBadge('Cân nặng', '${record.vitalSigns!.weight} kg', Icons.monitor_weight_outlined),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Diagnosis
                const Text(
                  'KẾT LUẬN CHẨN ĐOÁN',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  record.diagnosis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 12),

                // Doctor Advice
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.secondary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.tips_and_updates_rounded, color: AppColors.secondary, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Lời dặn của Bác sĩ:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.secondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              record.doctorAdvice,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textPrimary,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Prescription Section
                Row(
                  children: [
                    const Icon(Icons.medication_rounded, size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    const Text(
                      'ĐƠN THUỐC ĐIỆN TỬ',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: AppColors.primary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${record.prescriptions.length} loại thuốc',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...record.prescriptions.map((item) => _buildPrescriptionTile(item)),

                const SizedBox(height: 16),

                // Lab Orders Section
                Row(
                  children: [
                    const Icon(Icons.biotech_rounded, size: 16, color: AppColors.warning),
                    const SizedBox(width: 6),
                    const Text(
                      'KẾT QUẢ CẬN LÂM SÀNG',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: AppColors.warning,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...record.labOrders.map((order) => _buildLabOrderTile(order)),

                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 14),

                // Button: Đặt lịch tái khám theo hẹn
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
                      bookingProvider.setupFollowUpFromRecord(record);
                      onNavigateToTab?.call(1);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Đã chuyển sang màn hình Đặt lịch tái khám với ${record.doctorName}.'),
                          backgroundColor: const Color(0xFF0077C8),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0077C8),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.sync_rounded, size: 18),
                    label: const Text(
                      'Đặt Lịch Tái Khám Ngay',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalBadge(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildPrescriptionTile(PrescriptionItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  item.medicineName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '${item.quantity} ${item.unit}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '• Cách dùng: ${item.usage}',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabOrderTile(ClinicalLabOrder order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline_rounded, size: 16, color: AppColors.success),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.orderName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${order.departmentRoom} • Kết quả: ${order.result}',
                  style: const TextStyle(
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

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status.toLowerCase()) {
      case 'confirmed':
        bg = AppColors.successLight;
        fg = AppColors.success;
        label = 'Đã xác nhận';
        break;
      case 'completed':
        bg = AppColors.successLight;
        fg = AppColors.success;
        label = 'Đã hoàn tất';
        break;
      case 'cancelled':
        bg = AppColors.emergencyLight;
        fg = AppColors.emergency;
        label = 'Đã hủy';
        break;
      case 'checkedin':
        bg = AppColors.infoLight;
        fg = AppColors.info;
        label = 'Đã tiếp nhận';
        break;
      default:
        bg = AppColors.warningLight;
        fg = AppColors.warning;
        label = 'Chờ tiếp đón';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
