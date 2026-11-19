import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/hospital_time.dart';
import '../models/follow_up_order_model.dart';
import '../providers/booking_provider.dart';
import '../providers/home_provider.dart';
import '../services/local_reminder_service.dart';
import '../services/patient_session_service.dart';
import '../services/route_optimization_service.dart';
import 'route_optimization_card.dart';

Future<void> showPatientNotifications(
  BuildContext context, {
  RouteOptimizationService? optimizationService,
}) async {
  final home = context.read<HomeProvider>();
  BookingProvider? booking;
  try {
    booking = context.read<BookingProvider>();
  } catch (_) {}
  final session = PatientSessionService();
  final version = session.version;
  home.markNoticesRead();

  final selected = await showModalBottomSheet<JourneyNotice>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => ChangeNotifierProvider<HomeProvider>.value(
      value: home,
      child: DefaultTabController(
        length: 2,
        child: SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * 0.72,
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                automaticallyImplyLeading: false,
                title: const Text(
                  'Thông Báo & Nhắc Lịch Khám',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                centerTitle: true,
                bottom: const TabBar(
                  labelColor: AppColors.primary,
                  unselectedLabelColor: Colors.black54,
                  indicatorColor: AppColors.primary,
                  tabs: [
                    Tab(
                      icon: Icon(Icons.notifications_active_outlined, size: 20),
                      text: 'Thông báo lượt khám',
                    ),
                    Tab(
                      icon: Icon(Icons.alarm_on_rounded, size: 20),
                      text: 'Nhắc tái khám & Lịch hẹn',
                    ),
                  ],
                ),
              ),
              body: TabBarView(
                children: [
                  // TAB 1: Thông báo lượt khám (Live/Server Notifications)
                  Consumer<HomeProvider>(
                    builder: (context, home, _) => Column(
                      children: [
                        Expanded(
                          child: home.notices.isEmpty
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(24),
                                    child: Text(
                                      'Chưa có thông báo mới trong phiên này.\nCác cập nhật về gọi số và tiến trình khám sẽ xuất hiện tại đây.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.black54,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  itemCount: home.notices.length,
                                  separatorBuilder: (_, _) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final notice = home.notices[index];
                                    return ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor:
                                            AppColors.primary.withValues(alpha: 0.1),
                                        child: const Icon(
                                          Icons.notifications_outlined,
                                          color: AppColors.primary,
                                          size: 20,
                                        ),
                                      ),
                                      title: Text(
                                        notice.message,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      subtitle: Text(
                                        hospitalTime(
                                          notice.createdAt,
                                          pattern: 'HH:mm:ss dd/MM/yyyy',
                                        ),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.black45,
                                        ),
                                      ),
                                      trailing: notice.proposedPlanId != null
                                          ? const Icon(
                                              Icons.chevron_right,
                                              color: AppColors.primary,
                                            )
                                          : null,
                                      onTap: notice.proposedPlanId != null
                                          ? () => Navigator.pop(context, notice)
                                          : null,
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),

                  // TAB 2: Nhắc tái khám & Lịch hẹn (Follow-up & Appointment Reminders)
                  Consumer<HomeProvider>(
                    builder: (context, home, _) {
                      final followUp = home.latestFollowUpOrder;
                      final appointment = home.activeAppointment;

                      return ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          // 1. Follow-Up Reminder Section
                          _buildFollowUpSection(
                            sheetContext,
                            context,
                            home,
                            booking,
                            followUp,
                          ),
                          const SizedBox(height: 16),

                          // 2. Appointment Section
                          _buildAppointmentSection(appointment),
                          const SizedBox(height: 20),

                          // 3. Reminders & Device Alarm Action Buttons
                          _buildReminderActions(sheetContext, home, followUp),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  if (!context.mounted || session.version != version) return;
  final encounterId = selected?.encounterId;
  final offerId = selected?.proposedPlanId;
  final patientId = session.patientId;
  if (encounterId == null || offerId == null || patientId == null) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            ListenableBuilder(
              listenable: home,
              builder: (context, _) {
                final isCurrentVisit =
                    home.encounterSummary?.encounterId == encounterId;
                return RouteOptimizationCard(
                  encounterId: encounterId,
                  patientId: patientId,
                  requestedOfferId: offerId,
                  currentPlan: isCurrentVisit ? home.journey?.plan : null,
                  refreshToken: isCurrentVisit ? home.lastUpdatedAt : null,
                  isStale: isCurrentVisit && home.isJourneyStale,
                  service: optimizationService,
                  onChanged: () async {
                    if (session.version == version &&
                        home.encounterSummary?.encounterId == encounterId) {
                      await home.refreshJourney(includeFinalized: true);
                    }
                  },
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _buildFollowUpSection(
  BuildContext sheetContext,
  BuildContext context,
  HomeProvider home,
  BookingProvider? booking,
  FollowUpOrderModel? followUp,
) {
  if (followUp == null) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: const Row(
        children: [
          Icon(Icons.event_available_rounded, color: Colors.grey, size: 28),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Hiện không có chỉ định tái khám mới từ Bác sĩ.',
              style: TextStyle(color: Colors.black54, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  final formattedTimeStr = followUp.targetTime != null
      ? '${followUp.targetTime} · '
      : '';
  final dateStr = hospitalTime(followUp.targetDate, pattern: 'dd/MM/yyyy');

  return Container(
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF6B46C1), Color(0xFF805AD5)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF6B46C1).withValues(alpha: 0.25),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.alarm_on_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'LỊCH HẸN TÁI KHÁM ĐƯỢC CHỈ ĐỊNH',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber.shade400,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Cần đặt lịch',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          '$formattedTimeStr$dateStr',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Khoa: ${followUp.departmentName} — BS. ${followUp.originalDoctorName}',
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
        if (followUp.diagnosis.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Chẩn đoán: ${followUp.diagnosis}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        if (followUp.notes != null && followUp.notes!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Lời dặn: ${followUp.notes}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF6B46C1),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            icon: const Icon(Icons.calendar_month_rounded, size: 18),
            label: const Text(
              'Xác nhận & Đặt lịch tái khám ngay',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            onPressed: () async {
              Navigator.pop(sheetContext);
              if (booking != null) {
                final success = await booking.openFollowUp(followUp.id);
                if (success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Đã chuyển tới form Đặt lịch tái khám cho BS ${followUp.originalDoctorName}',
                      ),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                }
              }
            },
          ),
        ),
      ],
    ),
  );
}

Widget _buildAppointmentSection(dynamic appointment) {
  if (appointment == null) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: const Row(
        children: [
          Icon(Icons.calendar_today_rounded, color: Colors.grey, size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Chưa có lịch hẹn khám trực tuyến sắp tới.',
              style: TextStyle(color: Colors.black54, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  final dateStr = hospitalTime(
    appointment.scheduledTime,
    pattern: 'HH:mm - dd/MM/yyyy',
  );

  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.event_available_rounded,
            color: AppColors.primary,
            size: 26,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                appointment.serviceTypeName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Thời gian: $dateStr',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'Đã xác nhận',
            style: TextStyle(
              color: Colors.green,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildReminderActions(
  BuildContext sheetContext,
  HomeProvider home,
  FollowUpOrderModel? followUp,
) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Cấu hình Báo thức & Nhắc nhở',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: const BorderSide(color: AppColors.primary),
        ),
        icon: const Icon(
          Icons.notifications_active_rounded,
          color: AppColors.primary,
          size: 20,
        ),
        label: const Text(
          'Bật nhắc nhở báo thức trên điện thoại',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        onPressed: () async {
          final localService = LocalReminderService();
          final granted = await localService.requestPermissions();
          if (followUp != null) {
            await localService.scheduleFollowUpReminders(followUp);
          }
          if (home.activeAppointment != null) {
            await localService.scheduleAppointmentReminders(
              home.activeAppointment!,
            );
          }
          if (sheetContext.mounted) {
            ScaffoldMessenger.of(sheetContext).showSnackBar(
              SnackBar(
                content: Text(
                  granted
                      ? '✓ Đã kích hoạt báo thức nhắc nhở tự động trên điện thoại!'
                      : 'Cần cấp quyền thông báo trong Cài đặt thiết bị.',
                ),
                backgroundColor: granted ? Colors.green : Colors.orange,
              ),
            );
          }
        },
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: const BorderSide(color: Colors.grey),
        ),
        icon: const Icon(
          Icons.sync_rounded,
          color: Colors.black87,
          size: 20,
        ),
        label: const Text(
          'Kiểm tra & Gửi lại nhắc nhở từ Server (API)',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        onPressed: () async {
          final ok = await home.runBackendRemindersCheck();
          if (sheetContext.mounted) {
            ScaffoldMessenger.of(sheetContext).showSnackBar(
              SnackBar(
                content: Text(
                  ok
                      ? '✓ Đã yêu cầu Backend kiểm tra và cập nhật nhắc nhở!'
                      : 'Không thể kết nối đến server nhắc nhở.',
                ),
                backgroundColor: ok ? AppColors.primary : Colors.red,
              ),
            );
          }
        },
      ),
    ],
  );
}
