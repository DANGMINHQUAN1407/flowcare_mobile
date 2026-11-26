import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/patient_model.dart';
import '../../models/pregnancy_milestone_model.dart';

class PregnancyTrackerSheet extends StatelessWidget {
  final PatientModel? patient;
  final VoidCallback onBookAppointment;

  const PregnancyTrackerSheet({
    super.key,
    required this.patient,
    required this.onBookAppointment,
  });

  static void show(BuildContext context, {PatientModel? patient, required VoidCallback onBookAppointment}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PregnancyTrackerSheet(
        patient: patient,
        onBookAppointment: onBookAppointment,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final weeks = patient?.gestationalWeeks;
    final milestones = PregnancyMilestoneModel.standardMilestones;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.pregnant_woman_rounded, color: AppColors.maternityPink, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Sổ theo dõi thai kỳ điện tử',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Action: Book appointment for current milestone
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        onBookAppointment();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.calendar_month_rounded, size: 18),
                      label: const Text(
                        'Đặt lịch khám thai mốc tiếp theo',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Milestones Timeline
                  const Text(
                    'Các mốc khám thai quan trọng (Chuẩn Bộ Y Tế)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Mẹ bầu nên tuân thủ lịch khám để tầm soát dị tật và đánh giá sức khỏe thai nhi.',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),

                  ...milestones.map((m) {
                    final isPassed = weeks != null && weeks > m.week;
                    final isCurrent = weeks != null && (weeks >= m.week - 2) && (weeks <= m.week + 2);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isCurrent ? AppColors.primaryLight.withValues(alpha: 0.4) : AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isCurrent
                              ? AppColors.primary
                              : (m.isCrucial ? AppColors.maternityPink.withValues(alpha: 0.4) : AppColors.border),
                          width: isCurrent ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? AppColors.primary
                                  : (isPassed ? AppColors.successLight : Colors.grey.shade100),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'T.${m.week}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: isCurrent
                                    ? Colors.white
                                    : (isPassed ? AppColors.success : AppColors.textSecondary),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        m.title,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: isCurrent ? AppColors.primary : AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    if (m.isCrucial)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.maternityPinkLight,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'Mốc vàng',
                                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.maternityPink),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  m.description,
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.biotech_outlined, size: 14, color: AppColors.secondary),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          m.keyExams,
                                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 16),

                  // Warning signs banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.emergencyLight,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.emergency.withValues(alpha: 0.3)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: AppColors.emergency, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Dấu hiệu cấp cứu thai kỳ cần đến viện ngay:',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.emergency),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          '• Ra máu âm đạo tươi hoặc rỉ ối.\n• Đau quặn bụng dưới từng cơn liên tục.\n• Thai máy yếu (< 4 cử động / 2 giờ) hoặc không cử động.\n• Nhức đầu dữ dội, hoa mắt, phù nhanh chi dưới (dấu hiệu tiền sản giật).',
                          style: TextStyle(fontSize: 11, color: AppColors.textPrimary, height: 1.4),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
