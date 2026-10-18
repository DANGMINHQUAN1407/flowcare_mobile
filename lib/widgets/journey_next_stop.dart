import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/hospital_time.dart';
import '../models/patient_journey_model.dart';
import 'journey_timing_card.dart';

/// Guidance for the assigned route, rather than a claim about GPS position or
/// a live countdown. Pending approval and result dependencies never direct travel.
class JourneyNextStop extends StatelessWidget {
  final PatientJourney journey;
  final bool isStale;

  const JourneyNextStop({
    super.key,
    required this.journey,
    required this.isStale,
  });

  @override
  Widget build(BuildContext context) {
    if (journey.plan?.isProposed == true) {
      return const Text(
        'Lộ trình đang chờ nhân viên y tế duyệt. Hãy chờ hướng dẫn trước khi di chuyển.',
        style: TextStyle(fontSize: 13, height: 1.5),
      );
    }
    final step = journey.currentStep;
    if (step == null) {
      return const Text(
        'Đang chờ nhân viên y tế cập nhật bước tiếp theo.',
        style: TextStyle(fontSize: 13, height: 1.5),
      );
    }
    if (step.isWaitingForResult) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chưa có phòng tiếp theo để di chuyển',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            step.instruction?.isNotEmpty == true
                ? step.instruction!
                : 'Đang chờ kết quả ${step.title.toLowerCase()}. Theo dõi cập nhật từ nhân viên y tế.',
            style: const TextStyle(fontSize: 13, height: 1.5),
          ),
        ],
      );
    }
    if (step.id == 'nursing-intake') {
      return Column(
        key: const ValueKey('journey-nursing-guidance'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            step.title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            step.location.isEmpty
                ? 'Nhân viên sẽ hướng dẫn nơi tiếp nhận điều dưỡng.'
                : 'Nơi tiếp nhận: ${step.location}',
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
          if (step.queueNumber != null) ...[
            const SizedBox(height: 6),
            Text(
              'Số thứ tự: #${step.queueNumber}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            step.instruction ?? '',
            style: const TextStyle(fontSize: 13, height: 1.6),
          ),
          const SizedBox(height: 8),
          Text(
            isStale
                ? 'Dữ liệu có thể đã thay đổi. Hãy cập nhật hoặc hỏi nhân viên.'
                : 'Điều dưỡng ghi nhận thông tin trên hệ thống. Tiến trình sẽ cập nhật tại đây.',
            style: const TextStyle(
              fontSize: 12,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      );
    }
    final summary = journey.summary;
    final consultationWait =
        step.id == 'consultation' &&
            summary.queueStatus?.toLowerCase() == 'waiting' &&
            summary.checkInTime != null &&
            isSameHospitalDay(summary.checkInTime!, DateTime.now()) &&
            summary.estimatedWaitMinutes != null &&
            summary.estimatedWaitMinutes! >= 0
        ? summary.estimatedWaitMinutes!.toDouble()
        : null;
    final travel = step.timing?.travelMinutes;
    final wait = step.timing?.waitBeforeServiceMinutes ?? consultationWait;
    return Column(
      key: const ValueKey('journey-next-stop'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isStale
              ? 'Phòng theo lần cập nhật trước'
              : step.isInProgress
              ? 'Phòng đang thực hiện'
              : 'Phòng cần đến',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 6),
        Text(
          step.location.isEmpty ? 'Đang chờ phân phòng' : step.location,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 6),
        Text(step.title, style: const TextStyle(fontSize: 13, height: 1.4)),
        if (step.queueNumber != null) ...[
          const SizedBox(height: 8),
          Text(
            'Số thứ tự: #${step.queueNumber}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ],
        const SizedBox(height: 14),
        if (step.isInProgress)
          const Text(
            'Bước này đang được thực hiện. Chờ nhân viên y tế hướng dẫn bước tiếp theo.',
            style: TextStyle(fontSize: 13, height: 1.5),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final travelTile = _timeTile(
                key: const ValueKey('next-stop-travel'),
                icon: Icons.directions_walk_rounded,
                label: 'Di chuyển dự kiến',
                minutes: travel,
              );
              final waitTile = _timeTile(
                key: const ValueKey('next-stop-wait'),
                icon: Icons.hourglass_empty_rounded,
                label: 'Chờ trước dịch vụ',
                minutes: wait,
              );
              if (constraints.maxWidth < 280 ||
                  MediaQuery.textScalerOf(context).scale(14) > 19) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [travelTile, const SizedBox(height: 8), waitTile],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: travelTile),
                  const SizedBox(width: 8),
                  Expanded(child: waitTile),
                ],
              );
            },
          ),
        const SizedBox(height: 8),
        Text(
          isStale
              ? 'Dữ liệu có thể đã thay đổi. Hãy cập nhật lại hoặc hỏi nhân viên trước khi di chuyển.'
              : step.isInProgress
              ? 'Tiến trình sẽ cập nhật khi phòng hoàn tất bước này.'
              : 'Thời gian là ước tính theo lộ trình được phân công và có thể thay đổi.',
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _timeTile({
    required Key key,
    required IconData icon,
    required String label,
    required double? minutes,
  }) => Container(
    key: key,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary, size: 24),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          journeyMinutes(minutes),
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w900,
            color: AppColors.primary,
          ),
        ),
      ],
    ),
  );
}
