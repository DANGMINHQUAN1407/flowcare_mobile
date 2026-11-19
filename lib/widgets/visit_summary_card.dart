import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/network/api_client.dart';
import '../core/network/api_exceptions.dart';
import '../core/utils/hospital_time.dart';
import '../models/visit_summary_model.dart';

class VisitSummaryCard extends StatefulWidget {
  final String encounterId;
  final Object? refreshToken;
  final Future<VisitSummaryModel> Function(String encounterId) load;
  final Future<DownloadedFile> Function(String encounterId, String attachmentId)
  download;

  const VisitSummaryCard({
    super.key,
    required this.encounterId,
    required this.refreshToken,
    required this.load,
    required this.download,
  });

  @override
  State<VisitSummaryCard> createState() => _VisitSummaryCardState();
}

class _VisitSummaryCardState extends State<VisitSummaryCard> {
  static const _fileSaver = MethodChannel('flowcare/result_files');
  late Future<VisitSummaryModel> _summary;
  bool _savingFile = false;

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

  Future<void> _saveResult(VisitServiceResult item) async {
    if (_savingFile) return;
    setState(() => _savingFile = true);
    final encounterId = widget.encounterId;
    final session = ApiClient.sessionVersion;
    try {
      final files = item.attachments;
      final attachment = files.length > 1
          ? await showDialog<VisitResultAttachment>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Chọn tệp kết quả'),
                scrollable: true,
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final file in files)
                      ListTile(
                        title: Text(file.fileName),
                        leading: const Icon(Icons.description_outlined),
                        onTap: () => Navigator.pop(context, file),
                      ),
                  ],
                ),
              ),
            )
          : files.firstOrNull;
      if (files.isNotEmpty && attachment == null) return;
      if (!mounted ||
          encounterId != widget.encounterId ||
          session != ApiClient.sessionVersion) {
        return;
      }

      final DownloadedFile file;
      final String fileName;
      if (attachment != null) {
        file = await widget.download(encounterId, attachment.id);
        fileName = attachment.fileName;
      } else {
        final text = [
          item.serviceName,
          if (item.resultFinalizedAt case final date?)
            'Đã chốt ${hospitalTime(date)}',
          '',
          item.result!.trim(),
          if (item.resultNotes?.trim() case final notes? when notes.isNotEmpty)
            '\nGhi chú: $notes',
        ].join('\n');
        file = (
          bytes: Uint8List.fromList(utf8.encode(text)),
          contentType: 'text/plain',
        );
        fileName = '${item.serviceName}.txt';
      }
      if (!mounted ||
          encounterId != widget.encounterId ||
          session != ApiClient.sessionVersion) {
        return;
      }
      final safeName = fileName
          .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_')
          .trim();
      final saved = await _fileSaver.invokeMethod<bool>('save', {
        'fileName': safeName.isEmpty ? 'ket-qua' : safeName,
        'contentType': file.contentType,
        'bytes': file.bytes,
      });
      if (mounted && saved == true) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Đã lưu tệp kết quả.')));
      }
    } on SessionChangedException {
      // The account or visit changed before saving.
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chưa lưu được tệp kết quả. Vui lòng thử lại.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingFile = false);
    }
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
      if (summary != null) {
        return _VisitSummaryDetails(
          summary,
          onDownload: defaultTargetPlatform == TargetPlatform.android
              ? _saveResult
              : null,
          savingFile: _savingFile,
        );
      }

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
  final ValueChanged<VisitServiceResult>? onDownload;
  final bool savingFile;

  const _VisitSummaryDetails(
    this.summary, {
    required this.onDownload,
    required this.savingFile,
  });

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
              if (item.attachments.isEmpty &&
                  item.result?.trim().isNotEmpty != true)
                Text(
                  item.status.toLowerCase() == 'cancelled'
                      ? 'Dịch vụ đã hủy.'
                      : 'Chưa có kết quả đã chốt.',
                ),
              if (onDownload != null &&
                  (item.attachments.isNotEmpty ||
                      item.result?.trim().isNotEmpty == true))
                OutlinedButton.icon(
                  onPressed: savingFile ? null : () => onDownload!(item),
                  icon: const Icon(Icons.file_download_outlined),
                  label: Text(
                    item.attachments.isNotEmpty
                        ? 'Tải tệp kết quả'
                        : 'Tải kết quả (.txt)',
                  ),
                ),
              if (item.result?.trim().isNotEmpty == true ||
                  item.resultNotes?.trim().isNotEmpty == true)
                ExpansionTile(
                  dense: true,
                  tilePadding: EdgeInsets.zero,
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  title: const Text('Xem nội dung'),
                  children: [
                    if (item.result?.trim() case final result?
                        when result.isNotEmpty)
                      SelectableText(result),
                    if (item.resultNotes?.trim() case final notes?
                        when notes.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('Ghi chú: $notes'),
                      ),
                  ],
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
