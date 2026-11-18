import 'package:flutter/material.dart';

import '../core/network/api_exceptions.dart';
import '../core/utils/hospital_time.dart';
import '../models/visit_summary_model.dart';

class VisitSummaryCard extends StatefulWidget {
  final String encounterId;
  final Object? refreshToken;
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
  Widget build(BuildContext context) => FutureBuilder<VisitSummaryModel>(
    future: _summary,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const LinearProgressIndicator(
          semanticsLabel: 'Đang tải hồ sơ lượt khám',
        );
      }
      final summary = snapshot.data;
      if (summary != null) return _VisitSummaryDetails(summary);

      final error = snapshot.error;
      final waitingForDoctor =
          error is ApiException && error.codes.contains('VISIT_NOT_FINALIZED');
      return _VisitSection(
        title: 'Hồ sơ lượt khám',
        children: [
          Text(
            waitingForDoctor
                ? 'Hồ sơ sẽ có sau khi bác sĩ hoàn tất lượt khám.'
                : 'Chưa tải được hồ sơ lượt khám.',
          ),
          TextButton.icon(
            onPressed: _retry,
            icon: const Icon(Icons.refresh),
            label: const Text('Thử tải lại hồ sơ'),
          ),
        ],
      );
    },
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _VisitSection(
          title: 'Tình trạng sức khỏe',
          children: [
            Text(diagnosis.isEmpty ? 'Chưa ghi nhận chẩn đoán.' : diagnosis),
          ],
        ),
        _VisitSection(
          title: 'Đơn thuốc đã kê',
          children: [
            if (summary.prescriptions.isEmpty)
              const Text('Lượt khám này không có thuốc được kê.'),
            for (final item in summary.prescriptions)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.medicationName, style: heading),
                    if (item.quantity != null)
                      Text('Số lượng: ${item.quantity}'),
                    if (item.dosage?.trim().isNotEmpty == true)
                      Text('Liều dùng: ${item.dosage}'),
                    if (item.instructions?.trim().isNotEmpty == true)
                      Text('Hướng dẫn sử dụng: ${item.instructions}'),
                  ],
                ),
              ),
          ],
        ),
        if (plan.isNotEmpty)
          _VisitSection(
            title: 'Lời dặn và hướng xử trí',
            children: [Text(plan)],
          ),
        _VisitSection(
          title: 'Kết quả cận lâm sàng',
          children: [
            if (summary.services.isEmpty)
              const Text('Lượt khám này chưa có dịch vụ cận lâm sàng.'),
            for (final (index, item) in summary.services.indexed) ...[
              if (index > 0) const Divider(height: 24),
              Text(item.serviceName, style: heading),
              if (item.resultFinalizedAt case final finalizedAt?)
                Text('Đã chốt ${hospitalTime(finalizedAt)}'),
              const SizedBox(height: 4),
              if (item.result?.trim() case final result? when result.isNotEmpty)
                SelectableText(result)
              else
                Text(
                  item.status.toLowerCase() == 'cancelled'
                      ? 'Dịch vụ đã hủy.'
                      : 'Chưa có kết quả đã chốt.',
                ),
              if (item.resultNotes?.trim() case final notes?
                  when notes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Ghi chú: $notes'),
                ),
            ],
          ],
        ),
      ],
    );
  }
}

class _VisitSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _VisitSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    ),
  );
}
