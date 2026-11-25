import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/encounter_summary_model.dart';

class ReturnToConsultationBanner extends StatelessWidget {
  final EncounterSummaryModel summary;

  const ReturnToConsultationBanner({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final called = summary.queueStatus?.toLowerCase() == 'called';
    final ticket = summary.queueNumber == null
        ? summary.ticketCode?.trim()
        : 'STT #${summary.queueNumber}';
    final doctor = summary.doctorName?.trim();
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: AppColors.primaryLight,
      child: ListTile(
        leading: const Icon(
          Icons.meeting_room_outlined,
          color: AppColors.primary,
        ),
        title: const Text(
          'Trở lại phòng khám',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          [
            [summary.roomName?.trim(), ticket].whereType<String>().join(' · '),
            if (doctor != null && doctor.isNotEmpty) doctor,
            called
                ? 'Đã gọi số. Mời bạn vào phòng.'
                : 'Vui lòng chờ gọi số tại phòng khám.',
          ].join('\n'),
        ),
      ),
    );
  }
}
