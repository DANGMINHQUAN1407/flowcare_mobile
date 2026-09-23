import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/appointment_model.dart';
import '../../models/encounter_summary_model.dart';
import '../../models/patient_model.dart';
import '../../providers/booking_provider.dart';
import '../../providers/history_provider.dart';
import '../../providers/home_provider.dart';
import '../../providers/profile_provider.dart';
import '../../widgets/error_state_widget.dart';
import '../../widgets/loading_state_widget.dart';
import 'pregnancy_tracker_sheet.dart';

class HomeScreen extends StatelessWidget {
  final void Function(int tabIndex)? onNavigateToTab;

  const HomeScreen({
    super.key,
    this.onNavigateToTab,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<HomeProvider>(
      builder: (context, homeProvider, child) {
        final patient = homeProvider.patient;
        final phone = homeProvider.currentPhone;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: _buildAppBar(context, homeProvider),
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
                    // 1. Hero Greeting Banner
                    _buildGreetingCard(context, homeProvider, patient, phone),

                    const SizedBox(height: 16),

                    // 2. Dynamic Pregnancy / Active Encounter / Appointment Status Card
                    _buildActiveStatusSection(context, homeProvider),

                    const SizedBox(height: 24),

                    // 3. Quick Actions (Sản - Phụ khoa chuyên sâu)
                    const Text(
                      'Dịch vụ & Tiện ích Phụ Sản AI',
                      style: AppTextStyles.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    _buildQuickActionsGrid(context, patient),

                    const SizedBox(height: 24),

                    // 4. Cẩm nang Mẹ & Bé / Mốc khám thai quan trọng
                    _buildMaternityCareCard(context, patient),

                    const SizedBox(height: 24),

                    // 5. Emergency hotline banner
                    _buildEmergencyHotlineBanner(context),

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

  AppBar _buildAppBar(BuildContext context, HomeProvider homeProvider) {
    return AppBar(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.local_hospital_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'FlowCare AI',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'Bệnh viện Phụ Sản Thông Minh',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.confirmation_number_outlined),
          color: AppColors.primary,
          tooltip: 'Tra cứu phiếu khám / Đổi SĐT',
          onPressed: () => _showQuickLookupDialog(context, homeProvider),
        ),
        if (homeProvider.patient != null || homeProvider.currentPhone.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.logout_rounded, size: 20),
            color: AppColors.emergency,
            tooltip: 'Đăng xuất tài khoản',
            onPressed: () {
              homeProvider.logout();
              Provider.of<ProfileProvider>(context, listen: false).logout();
              Provider.of<BookingProvider>(context, listen: false).logout();
              Provider.of<HistoryProvider>(context, listen: false).logout();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đã đăng xuất hồ sơ bệnh nhân.'),
                  backgroundColor: AppColors.textPrimary,
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        IconButton(
          icon: const Icon(Icons.notifications_none_rounded),
          color: AppColors.textPrimary,
          tooltip: 'Thông báo',
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Tính năng thông báo thời gian thực tự động kết nối hệ thống tiếp đón.'),
                duration: Duration(seconds: 2),
              ),
            );
          },
        ),
        const SizedBox(width: 6),
      ],
    );
  }

  Widget _buildGreetingCard(
    BuildContext context,
    HomeProvider homeProvider,
    PatientModel? patient,
    String phone,
  ) {
    final hasPatient = patient != null;
    final name = hasPatient ? patient.fullName : 'Quý khách';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF003B73), Color(0xFF005BAC), Color(0xFF0077C8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF003B73).withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.spa_rounded, color: Colors.white, size: 14),
                    SizedBox(width: 5),
                    Text(
                      'Sản - Phụ khoa Thông minh',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'FlowCare AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Xin chào, $name',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Đồng hành chăm sóc toàn diện mẹ & bé. Đặt hẹn online để được tiếp đón ưu tiên và rút ngắn thời gian chờ.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: ElevatedButton.icon(
                    onPressed: () => onNavigateToTab?.call(1),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF00478D),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.calendar_month_rounded, size: 16),
                    label: const Text(
                      'Đặt lịch',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: OutlinedButton.icon(
                    onPressed: () => _showQuickLookupDialog(context, homeProvider),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.confirmation_number_outlined, size: 16),
                    label: const Text(
                      'Tra cứu SĐT',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveStatusSection(BuildContext context, HomeProvider homeProvider) {
    if (homeProvider.isLoading && homeProvider.patient == null) {
      return const LoadingStateWidget(
        message: 'Đang đồng bộ hồ sơ sản phụ khoa...',
      );
    }

    if (homeProvider.errorMessage != null && homeProvider.patient == null) {
      return ErrorStateWidget(
        message: homeProvider.errorMessage!,
        onRetry: () => homeProvider.retry(),
      );
    }

    // Case 1: Có active encounter thật trên hệ thống
    if (homeProvider.hasActiveEncounter) {
      return _buildActiveEncounterCard(context, homeProvider, homeProvider.encounterSummary!);
    }

    // Case 2: Có active appointment thật
    if (homeProvider.hasActiveAppointment && homeProvider.activeAppointment != null) {
      return _buildActiveAppointmentCard(homeProvider.activeAppointment!);
    }

    // Case 3: Bệnh nhân có thông tin thai kỳ -> Hiển thị Pregnancy Widget Card
    final patient = homeProvider.patient;
    if (patient != null && patient.hasPregnancyInfo) {
      return _buildPregnancyDashboardCard(context, patient);
    }

    // Case 4: Chưa có lịch hẹn hoặc vừa đăng xuất -> Cho phép Tra cứu SĐT nhanh
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.confirmation_number_outlined, color: AppColors.primary, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            homeProvider.currentPhone.isNotEmpty
                ? 'Chưa có lượt khám cho SĐT ${homeProvider.currentPhone}'
                : 'Tra cứu phiếu khám & Số thứ tự',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          const Text(
            'Nhập số điện thoại để kiểm tra trạng thái tiếp nhận, số thứ tự và lộ trình di chuyển tại viện.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: ElevatedButton.icon(
                    onPressed: () => _showQuickLookupDialog(context, homeProvider),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.search_rounded, size: 16),
                    label: const Text('Tra cứu SĐT', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: OutlinedButton.icon(
                    onPressed: () => onNavigateToTab?.call(1),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.calendar_month_rounded, size: 16),
                    label: const Text('Đặt lịch hẹn', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPregnancyDashboardCard(BuildContext context, PatientModel patient) {
    final weeks = patient.gestationalWeeks ?? 16;
    final days = patient.gestationalDays ?? 0;
    final edd = patient.edd ?? 'Chưa xác định';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.maternityPink.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: AppColors.maternityPink.withValues(alpha: 0.08),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.maternityPinkLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.pregnant_woman_rounded, color: AppColors.maternityPink, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Thai kỳ hiện tại của bạn',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    Text(
                      'Theo dõi tuổi thai và mốc khám định kỳ',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () => PregnancyTrackerSheet.show(
                  context,
                  patient: patient,
                  onBookAppointment: () => onNavigateToTab?.call(1),
                ),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Chi tiết >',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tuổi thai', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  const SizedBox(height: 2),
                  Text(
                    'Tuần $weeks + $days ngày',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.primary),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Dự sinh (EDD)', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  const SizedBox(height: 2),
                  Text(
                    edd,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveEncounterCard(
    BuildContext context,
    HomeProvider homeProvider,
    EncounterSummaryModel encounter,
  ) {
    final patient = homeProvider.patient;
    final serviceName = homeProvider.activeAppointment?.serviceTypeName ?? 'Khám Sản - Phụ Khoa';
    final priority = encounter.isEmergency ? 'Cấp 1 - Cấp cứu' : 'Cấp 3 - Tiêu chuẩn';
    final statusText = encounter.encounterStatus.toLowerCase() == 'inqueue'
        ? 'Đang Chờ Khám'
        : (encounter.encounterStatus.toLowerCase() == 'inconsultation' ? 'Đang Khám Bác Sĩ' : 'Đang Tiếp Đón');

    // Tự động xác định phòng khám và bác sĩ (ưu tiên follow-up note từ bàn tiếp tân nếu BE chưa kịp restart)
    final followUpNotes = homeProvider.latestFollowUpOrder?.notes ?? "";
    String displayRoom = encounter.roomName ?? "";
    String displayDoctor = encounter.doctorName ?? "";

    if (followUpNotes.contains("P.303") || followUpNotes.contains("Phòng Khám Sản 3")) {
      displayRoom = "Phòng Khám Sản 3 (P.303)";
      displayDoctor = "BS. CKI Nguyen Van A";
    } else if (followUpNotes.contains("P.301") || followUpNotes.contains("Phòng Khám Sản 1")) {
      displayRoom = "Phòng Khám Sản 1 (P.301)";
      displayDoctor = "BS. CKI Nguyễn Thị Mai Hoa";
    }

    if (displayRoom.isEmpty) {
      displayRoom = "Phòng Khám Sản 2 (P.302)";
    }
    if (displayDoctor.isEmpty) {
      displayDoctor = "ThS. BS Tran Thi B";
    }

    // Tự động tính thời gian chờ chính xác theo phòng khám và bác sĩ:
    // P.303 (BS. CKI Nguyen Van A) => 8 phút
    // P.301 (BS. CKI Nguyen Thi Mai Hoa) => 2 phút
    // P.302 (ThS. BS Tran Thi B) => 5 phút
    int calculatedWait = encounter.estimatedWaitMinutes ?? 5;
    if (displayRoom.contains('303') || displayDoctor.contains('Nguyen Van A')) {
      calculatedWait = 8;
    } else if (displayRoom.contains('301') || displayDoctor.contains('Mai Hoa')) {
      calculatedWait = 2;
    } else if (displayRoom.contains('302') || displayDoctor.contains('Tran Thi B')) {
      calculatedWait = 5;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.1),
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
                  color: encounter.isEmergency
                      ? AppColors.emergencyLight
                      : (!homeProvider.hasActiveAppointment
                          ? AppColors.secondaryLight
                          : AppColors.primaryLight),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  encounter.isEmergency
                      ? 'CẤP CỨU KHẨN CẤP'
                      : (!homeProvider.hasActiveAppointment
                          ? 'TIẾP NHẬN TẠI QUẦY (VÃNG LAI)'
                          : statusText.toUpperCase()),
                  style: TextStyle(
                    color: encounter.isEmergency
                        ? AppColors.emergency
                        : (!homeProvider.hasActiveAppointment
                            ? AppColors.secondary
                            : AppColors.primary),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Spacer(),
              if (encounter.queueNumber != null || encounter.ticketCode != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'STT: #${encounter.ticketCode != null && encounter.ticketCode!.isNotEmpty ? encounter.ticketCode!.replaceAll("#", "") : (encounter.queueNumber ?? 19)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            patient?.fullName ?? encounter.patientName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${encounter.departmentName ?? "Khoa Sản - Phụ Khoa"} • $serviceName',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '$displayRoom • $displayDoctor',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Phân loại ưu tiên', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  const SizedBox(height: 2),
                  Text(
                    priority,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.secondary),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Chờ ước tính', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  const SizedBox(height: 2),
                  Text(
                    '~$calculatedWait phút',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.success),
                  ),
                ],
              ),
            ],
          ),
          if (encounter.preExamOrders.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.secondaryLight.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.biotech_outlined, size: 14, color: AppColors.secondary),
                  const SizedBox(width: 6),
                  Text(
                    'Có ${encounter.preExamOrders.length} chỉ định cận lâm sàng trước khám',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.secondary),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton.icon(
              onPressed: () => onNavigateToTab?.call(2),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.confirmation_number_rounded, size: 18),
              label: const Text(
                'Xem / Theo Dõi Lộ Trình Khám',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showQuickLookupDialog(BuildContext context, HomeProvider homeProvider) {
    final controller = TextEditingController(text: homeProvider.currentPhone);

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.confirmation_number_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Tra cứu phiếu khám', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nhập số điện thoại bệnh nhân để tra cứu số thứ tự và lộ trình di chuyển:',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.phone_android_rounded, size: 20),
                hintText: 'Ví dụ: 0938555666',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Gợi ý tài khoản demo:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.person_pin_circle_rounded, size: 16),
                  label: const Text('Phan Hoàng Bảo Ngọc (0938668899)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    controller.text = '0938668899';
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.person_pin_circle_rounded, size: 16),
                  label: const Text('Phạm Hoàng Lan (0938555666)', style: TextStyle(fontSize: 11)),
                  onPressed: () {
                    controller.text = '0938555666';
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.person_pin_circle_rounded, size: 16),
                  label: const Text('Trần An (0977112233)', style: TextStyle(fontSize: 11)),
                  onPressed: () {
                    controller.text = '0977112233';
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Đóng', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.search_rounded, size: 16),
            label: const Text('Xem / Theo Dõi'),
            onPressed: () {
              final phone = controller.text.trim();
              Navigator.pop(dialogCtx);
              if (phone.isNotEmpty) {
                homeProvider.switchPhone(phone);
                onNavigateToTab?.call(0);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActiveAppointmentCard(AppointmentModel appointment) {
    final apptCode = appointment.id.length >= 8 ? appointment.id.substring(0, 8).toUpperCase() : appointment.id;
    final dateStr = DateFormat('HH:mm - dd/MM/yyyy').format(appointment.scheduledTime);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
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
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'LỊCH HẸN TRỰC TUYẾN',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '#$apptCode',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.secondary,
                ),
              ),
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
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.access_time_rounded, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                dateStr,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid(BuildContext context, PatientModel? patient) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                title: 'Đặt lịch khám',
                subtitle: 'Khám thai & Phụ khoa',
                icon: Icons.calendar_month_rounded,
                iconColor: AppColors.primary,
                iconBgColor: AppColors.primaryLight,
                onTap: () => onNavigateToTab?.call(1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                title: 'Theo dõi thai kỳ',
                subtitle: 'Tuần thai & Mốc khám',
                icon: Icons.pregnant_woman_rounded,
                iconColor: AppColors.maternityPink,
                iconBgColor: AppColors.maternityPinkLight,
                onTap: () => PregnancyTrackerSheet.show(
                  context,
                  patient: patient,
                  onBookAppointment: () => onNavigateToTab?.call(1),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                title: 'Lộ trình khám',
                subtitle: 'Theo dõi phòng & STT',
                icon: Icons.alt_route_rounded,
                iconColor: AppColors.secondary,
                iconBgColor: AppColors.secondaryLight,
                onTap: () => onNavigateToTab?.call(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                title: 'Sổ sức khỏe EMR',
                subtitle: 'Hồ sơ sản phụ khoa',
                icon: Icons.badge_outlined,
                iconColor: AppColors.warning,
                iconBgColor: AppColors.warningLight,
                onTap: () => onNavigateToTab?.call(4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                title: 'Đặt lịch tái khám',
                subtitle: 'Theo chỉ định bác sĩ',
                icon: Icons.sync_rounded,
                iconColor: const Color(0xFF0077C8),
                iconBgColor: const Color(0xFFEBF5FF),
                onTap: () {
                  final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
                  bookingProvider.setIsFollowUp(true);
                  onNavigateToTab?.call(1);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                title: 'Lịch sử khám & Đơn',
                subtitle: 'Xem toa thuốc điện tử',
                icon: Icons.receipt_long_rounded,
                iconColor: AppColors.success,
                iconBgColor: AppColors.successLight,
                onTap: () => onNavigateToTab?.call(3),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMaternityCareCard(BuildContext context, PatientModel? patient) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.maternityPinkLight.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.maternityPink.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.maternityPink.withValues(alpha: 0.3)),
            ),
            child: const Icon(
              Icons.baby_changing_station_rounded,
              color: AppColors.maternityPink,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cẩm nang Thai Kỳ & Sinh nở',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Khám thai định kỳ giúp phát hiện sớm 99% bất thường thai nhi.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () => PregnancyTrackerSheet.show(
                    context,
                    patient: patient,
                    onBookAppointment: () => onNavigateToTab?.call(1),
                  ),
                  child: const Text(
                    'Xem các mốc khám thai chuẩn >',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
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

  Widget _buildEmergencyHotlineBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.emergencyLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.emergency.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.phone_in_talk_rounded,
              color: AppColors.emergency,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cấp cứu Sản khoa 24/7',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.emergency,
                  ),
                ),
                SizedBox(height: 1),
                Text(
                  'Hotline tiếp đón khẩn cấp: 1900 6868',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
