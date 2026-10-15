import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme/app_colors.dart';
import '../models/journey_timing_model.dart';

String journeyMinutes(double? minutes) {
  if (minutes == null) return 'Chưa có ước tính';
  if (minutes > 0 && minutes < 1) return 'Dưới 1 phút';
  final number = NumberFormat('0.#', 'vi_VN').format(minutes);
  return '$number phút';
}

class JourneyTravelHighlight extends StatelessWidget {
  final double? minutes;
  const JourneyTravelHighlight({super.key, required this.minutes});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.primaryLight,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.directions_walk_rounded,
          color: AppColors.primary,
          size: 28,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Di chuyển dự kiến',
                style: TextStyle(fontSize: 12, color: AppColors.primary),
              ),
              const SizedBox(height: 3),
              Text(
                minutes == 0
                    ? 'Không cần di chuyển'
                    : minutes == null
                    ? 'Chưa có ước tính'
                    : 'Khoảng ${journeyMinutes(minutes)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class JourneyStepTimingCard extends StatelessWidget {
  final JourneyStepTiming timing;
  const JourneyStepTimingCard({super.key, required this.timing});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      JourneyTravelHighlight(minutes: timing.travelMinutes),
      const SizedBox(height: 10),
      _row(
        Icons.hourglass_empty_rounded,
        'Chờ trước dịch vụ dự kiến',
        timing.waitBeforeServiceMinutes,
      ),
      _row(
        Icons.medical_services_outlined,
        'Thực hiện dự kiến',
        timing.serviceMinutes,
      ),
      _row(
        Icons.science_outlined,
        'Chờ kết quả dự kiến',
        timing.resultWaitMinutes,
      ),
      if (timing.elapsedBeforeStartMinutes != null ||
          timing.actualServiceMinutes != null ||
          timing.actualResultWaitMinutes != null)
        Material(
          type: MaterialType.transparency,
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            title: const Text(
              'Thời gian thực tế đã ghi nhận',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
            children: [
              if (timing.elapsedBeforeStartMinutes != null)
                _row(
                  Icons.schedule_rounded,
                  'Từ xếp hàng đến bắt đầu',
                  timing.elapsedBeforeStartMinutes,
                ),
              if (timing.actualServiceMinutes != null)
                _row(
                  Icons.medical_services_outlined,
                  'Thực hiện thực tế',
                  timing.actualServiceMinutes,
                ),
              if (timing.actualResultWaitMinutes != null)
                _row(
                  Icons.science_outlined,
                  'Chờ kết quả thực tế',
                  timing.actualResultWaitMinutes,
                ),
              if (timing.elapsedBeforeStartMinutes != null)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Khoảng từ xếp hàng đến bắt đầu gồm cả thời gian di chuyển.',
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.4,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
    ],
  );

  Widget _row(IconData icon, String label, double? minutes) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: AppColors.textSecondary),
        const SizedBox(width: 7),
        Expanded(
          flex: 3,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          flex: 2,
          child: Text(
            journeyMinutes(minutes),
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );
}

class JourneyTimingSummary extends StatelessWidget {
  final JourneyTiming timing;
  const JourneyTimingSummary({super.key, required this.timing});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Thời gian dự kiến theo lộ trình',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.directions_walk_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tổng di chuyển cận lâm sàng',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    journeyMinutes(timing.travelMinutes),
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Chờ trước các dịch vụ: ${journeyMinutes(timing.waitBeforeServiceMinutes)}',
          style: const TextStyle(fontSize: 12, height: 1.5),
        ),
        if (timing.totalMinutes != null)
          Text(
            'Hoàn tất cận lâm sàng dự kiến: ${journeyMinutes(timing.totalMinutes)}',
            style: const TextStyle(fontSize: 12, height: 1.5),
          ),
        const SizedBox(height: 8),
        const Text(
          'Di chuyển là ước tính theo các chặng được phân công. Các khoảng chờ kết quả có thể trùng với lúc thực hiện dịch vụ khác.',
          style: TextStyle(
            fontSize: 10,
            height: 1.5,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    ),
  );
}
