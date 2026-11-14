import 'package:flutter/material.dart';

import '../core/network/api_exceptions.dart';
import '../models/visit_summary_model.dart';

class VisitSummaryCard extends StatefulWidget {
  final String encounterId;
  final DateTime? refreshToken;
  final Future<VisitSummaryModel> Function(String encounterId) load;

  const VisitSummaryCard({
    super.key,
    required this.encounterId,
    required this.refreshToken,
    required this.load,
  });

  @override
  State<VisitSummaryCard> createState() => _VisitSummaryCardState();
}

class _VisitSummaryCardState extends State<VisitSummaryCard> {
  late Future<VisitSummaryModel> _summary;

  @override
  void initState() {
    super.initState();
    _summary = widget.load(widget.encounterId);
  }

  @override
  void didUpdateWidget(covariant VisitSummaryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.encounterId != widget.encounterId ||
        oldWidget.refreshToken != widget.refreshToken) {
      _summary = widget.load(widget.encounterId);
    }
  }

  void _retry() {
    setState(() {
      _summary = widget.load(widget.encounterId);
    });
  }

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tóm tắt lượt khám',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          FutureBuilder<VisitSummaryModel>(
            future: _summary,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const LinearProgressIndicator(
                  semanticsLabel: 'Đang tải tóm tắt lượt khám',
                );
              }
              final summary = snapshot.data;
              if (summary != null) return _VisitSummaryDetails(summary);

              final error = snapshot.error;
              final waitingForDoctor =
                  error is ApiException &&
                  error.codes.contains('VISIT_NOT_FINALIZED');
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    waitingForDoctor
                        ? 'Tóm tắt sẽ có sau khi bác sĩ hoàn tất lượt khám.'
                        : 'Chưa tải được tóm tắt lượt khám.',
                  ),
                  TextButton.icon(
                    onPressed: _retry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Thử tải lại tóm tắt'),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    ),
  );
}

class _VisitSummaryDetails extends StatelessWidget {
  final VisitSummaryModel summary;

  const _VisitSummaryDetails(this.summary);

  @override
  Widget build(BuildContext context) {
    final heading = Theme.of(context).textTheme.titleSmall;
    final diagnosis = summary.diagnosis?.trim() ?? '';
    final plan = summary.plan?.trim() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Chẩn đoán', style: heading),
        Text(diagnosis.isEmpty ? 'Chưa ghi nhận chẩn đoán.' : diagnosis),
        const SizedBox(height: 12),
        Text('Lời dặn và hướng xử trí', style: heading),
        Text(plan.isEmpty ? 'Chưa có lời dặn.' : plan),
        const SizedBox(height: 12),
        Text('Đơn thuốc đã kê', style: heading),
        if (summary.prescriptions.isEmpty)
          const Text('Lượt khám này không có thuốc được kê.'),
        for (final item in summary.prescriptions)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.medicationName, style: heading),
                if (item.quantity != null) Text('Số lượng: ${item.quantity}'),
                if (item.dosage?.trim().isNotEmpty == true)
                  Text('Liều dùng: ${item.dosage}'),
                if (item.instructions?.trim().isNotEmpty == true)
                  Text('Hướng dẫn sử dụng: ${item.instructions}'),
              ],
            ),
          ),
      ],
    );
  }
}
