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
    final weeks = patient?.gestationalWeeks ?? 16;
    final days = patient?.gestationalDays ?? 3;
    final edd = patient?.edd ?? '25/12/2026';
    final lmp = patient?.lmp ?? '15/03/2026';
    final para = patient?.para ?? 'G1 P0 A0 L0';
    final milestones = PregnancyMilestoneModel.standardMilestones;

    // Determine current trimester
    String trimester;
    if (weeks <= 13) {
      trimester = 'Tam cá nguyệt 1 (3 tháng đầu)';
    } else if (weeks <= 27) {
      trimester = 'Tam cá nguyệt 2 (3 tháng giữa)';
    } else {
      trimester = 'Tam cá nguyệt 3 (3 tháng cuối)';
    }

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
                  // Hero Gestational Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE879F9), Color(0xFFF43F5E)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF43F5E).withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
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
                                color: Colors.white.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                trimester,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const Spacer(),
                            const Icon(Icons.favorite_rounded, color: Colors.white, size: 18),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Tuần $weeks + $days ngày',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            Text(
                              'Dự sinh (EDD): $edd',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.95),
                              ),
                            ),
                            Text(
                              '• Kinh cuối (LMP): $lmp',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.95),
                              ),
                            ),
                            Text(
                              '• PARA: $para',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.95),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Progress bar (40 weeks total)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: (weeks / 40.0).clamp(0.0, 1.0),
                                minHeight: 8,
                                backgroundColor: Colors.white.withValues(alpha: 0.3),
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Tuần 0', style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.8))),
                                Text('Hành trình: ${((weeks / 40.0) * 100).toInt()}%', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                                Text('Tuần 40 (Sinh)', style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.8))),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

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
                    final isPassed = weeks > m.week;
                    final isCurrent = (weeks >= m.week - 2) && (weeks <= m.week + 2);

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
