import 'dart:async';

import 'package:flutter/material.dart';

import '../core/network/api_client.dart';
import '../core/network/api_exceptions.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/hospital_time.dart';
import '../models/route_assistance_model.dart';
import '../services/patient_session_service.dart';
import '../services/route_assistance_service.dart';

class RouteAssistanceCard extends StatefulWidget {
  final String encounterId, patientId;
  final bool isStale;
  final DateTime? refreshToken;
  final Future<void> Function() onApplied;
  final RouteAssistanceService? service;
  const RouteAssistanceCard({
    super.key,
    required this.encounterId,
    required this.patientId,
    required this.onApplied,
    this.isStale = false,
    this.refreshToken,
    this.service,
  });
  @override
  State<RouteAssistanceCard> createState() => _RouteAssistanceCardState();
}

class _RouteAssistanceCardState extends State<RouteAssistanceCard> {
  late final RouteAssistanceService _service;
  late final int _sessionVersion, _apiVersion;
  AssistanceEligibility? _eligibility;
  RouteAssistanceRequest? _request;
  RouteComparison? _comparison;
  String? _error, _sendError, _comparisonError, _seenApplied;
  bool _loading = false,
      _sending = false,
      _comparing = false,
      _uncertain = false;
  bool get _current =>
      mounted &&
      _sessionVersion == PatientSessionService().version &&
      _apiVersion == ApiClient.sessionVersion &&
      PatientSessionService().patientId == widget.patientId;
  bool get _allowed =>
      !PatientSessionService().isDemo && ApiClient.authToken != null;
  @override
  void initState() {
    super.initState();
    _service = widget.service ?? RouteAssistanceService();
    _sessionVersion = PatientSessionService().version;
    _apiVersion = ApiClient.sessionVersion;
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant RouteAssistanceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken ||
        (oldWidget.isStale && !widget.isStale)) {
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    if (widget.service == null) _service.close();
    super.dispose();
  }

  Future<void> _load() async {
    if (!_current || !_allowed || _loading || _sending || widget.isStale) {
      return;
    }
    setState(() {
      _loading = true;
    });
    try {
      final data = await Future.wait<Object?>([
        _service.eligibility(widget.encounterId, widget.patientId),
        _service.status(widget.encounterId, widget.patientId),
      ]);
      if (!_current) return;
      final row = data[1] as RouteAssistanceRequest?;
      final justApplied =
          row?.isApplied == true &&
          _request != null &&
          _seenApplied != row!.appliedPlanId;
      setState(() {
        _eligibility = data[0] as AssistanceEligibility;
        _request = row;
        _error = null;
        _uncertain = false;
        if (row?.isApplied == true) _seenApplied = row!.appliedPlanId;
      });
      if (justApplied) unawaited(widget.onApplied());
    } catch (error) {
      if (_current) {
        setState(() {
          _error = patientErrorMessage(error);
        });
      }
    } finally {
      if (_current) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _send() async {
    if (!_current ||
        !_allowed ||
        _sending ||
        _loading ||
        widget.isStale ||
        _uncertain ||
        _error != null ||
        _eligibility?.canRequest != true) {
      return;
    }
    setState(() {
      _sending = true;
      _sendError = null;
    });
    try {
      final row = await _service.request(widget.encounterId, widget.patientId);
      if (_current) {
        setState(() {
          _request = row;
          _eligibility = null;
          _error = null;
        });
      }
    } catch (error) {
      if (_current) {
        setState(() {
          _sendError = patientErrorMessage(error);
          _uncertain = true;
        });
      }
    } finally {
      if (_current) {
        setState(() {
          _sending = false;
        });
      }
    }
    if (_current) await _load();
  }

  Future<void> _compare() async {
    if (!_current || !_allowed || _comparing || widget.isStale) return;
    setState(() {
      _comparing = true;
      _comparisonError = null;
    });
    try {
      final data = await _service.compare(widget.encounterId, widget.patientId);
      if (_current) {
        setState(() {
          _comparison = data;
        });
      }
    } catch (error) {
      if (_current) {
        setState(() {
          _comparisonError = patientErrorMessage(error);
        });
      }
    } finally {
      if (_current) {
        setState(() {
          _comparing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_allowed) return const SizedBox.shrink();
    final canSend =
        _eligibility?.canRequest == true &&
        (_eligibility?.remainingOrders ?? 0) >= 2 &&
        !_loading &&
        !_sending &&
        !_uncertain &&
        _error == null &&
        !widget.isStale;
    final row = _request;
    return Container(
      key: const ValueKey('route-assistance-card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.support_agent_rounded, color: AppColors.primary),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Hỗ trợ tối ưu lộ trình',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
              IconButton(
                tooltip: 'Cập nhật hỗ trợ',
                onPressed: _loading || _sending ? null : _load,
                icon: const Icon(Icons.refresh_rounded, size: 21),
              ),
            ],
          ),
          if (row != null) ...[
            const SizedBox(height: 8),
            Text(
              row.label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: row.isApplied ? AppColors.success : AppColors.primary,
              ),
            ),
            if (row.routeStatus == 'Proposed')
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Tiếp tục theo tuyến đã xác nhận trong lúc chờ bác sĩ duyệt.',
                  style: TextStyle(fontSize: 12, height: 1.5),
                ),
              ),
            if (row.appliedAt != null && row.isApplied)
              Text(
                'Áp dụng lúc ${hospitalTime(row.appliedAt!)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            if (row.resolutionNotes?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  row.resolutionNotes!,
                  style: const TextStyle(fontSize: 13, height: 1.5),
                ),
              ),
            if (row.processingError?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  row.processingError!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.warning,
                  ),
                ),
              ),
          ],
          if (_loading && _eligibility == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(),
            ),
          if (widget.isStale || _error != null || _uncertain)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                widget.isStale
                    ? 'Chưa đồng bộ được lượt khám. Cập nhật lộ trình để tiếp tục.'
                    : _uncertain
                    ? 'Chưa xác nhận yêu cầu đã gửi. Cập nhật trạng thái trước khi gửi lại.'
                    : _error!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.warning,
                  height: 1.5,
                ),
              ),
            ),
          if (_eligibility != null &&
              !_eligibility!.canRequest &&
              !rowIsOpenOrProposed(row))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _eligibility!.reason ?? 'Chưa đủ điều kiện gửi yêu cầu.',
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const ValueKey('request-route-assistance'),
            onPressed: canSend ? _send : null,
            icon: _sending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.support_agent_rounded, size: 20),
            label: Text(
              _sending
                  ? 'Đang gửi…'
                  : row?.isOpen == true
                  ? 'Đã gửi yêu cầu'
                  : row?.isApplied == true
                  ? 'Gửi yêu cầu tối ưu mới'
                  : 'Nhờ tối ưu',
            ),
          ),
          OutlinedButton.icon(
            key: const ValueKey('compare-route-assistance'),
            onPressed:
                _comparing ||
                    widget.isStale ||
                    _error != null ||
                    (_eligibility?.remainingOrders ?? 0) < 2
                ? null
                : _compare,
            icon: _comparing
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.compare_arrows_rounded),
            label: Text(
              _comparison == null
                  ? 'So sánh có / không hỗ trợ'
                  : 'Cập nhật so sánh',
            ),
          ),
          if (_sendError != null)
            Text(
              _sendError!,
              style: const TextStyle(fontSize: 12, color: AppColors.warning),
            ),
          if (_comparisonError != null)
            Text(
              _comparisonError!,
              style: const TextStyle(fontSize: 12, color: AppColors.warning),
            ),
          if (_comparison != null) ...[
            const SizedBox(height: 12),
            RouteComparisonView(comparison: _comparison!),
          ],
        ],
      ),
    );
  }

  bool rowIsOpenOrProposed(RouteAssistanceRequest? row) =>
      row?.isOpen == true || row?.routeStatus == 'Proposed';
}

class RouteComparisonView extends StatelessWidget {
  final RouteComparison comparison;
  const RouteComparisonView({super.key, required this.comparison});
  @override
  Widget build(BuildContext context) {
    final a = comparison.baseline, b = comparison.optimized;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          comparison.savedMinutes > 0
              ? 'Dự kiến giảm ${comparison.savedMinutes} phút so với thứ tự chỉ định'
              : 'Chưa giảm thời gian so với thứ tự chỉ định',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 10),
        Table(
          key: const ValueKey('route-comparison-table'),
          columnWidths: const {
            0: FlexColumnWidth(1.5),
            1: FlexColumnWidth(),
            2: FlexColumnWidth(),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          border: TableBorder.all(color: AppColors.border),
          children: [
            _row(
              'Ước tính',
              'Theo thứ tự chỉ định',
              'Phương án tối ưu',
              header: true,
            ),
            _row('Di chuyển', '${a.travel} phút', '${b.travel} phút'),
            _row('Chờ trước dịch vụ', '${a.queue} phút', '${b.queue} phút'),
            _row('Thực hiện dịch vụ', '${a.service} phút', '${b.service} phút'),
            _row('Chờ thêm sau dịch vụ cuối', _resultWait(a), _resultWait(b)),
            _row(
              'Hoàn tất, đủ kết quả',
              '${a.total} phút',
              '${b.total} phút',
              header: true,
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'So sánh hai cách sắp xếp trên cùng dữ liệu tại thời điểm tính. Đây không phải thời gian giảm thêm của mỗi lần gửi yêu cầu. Chờ kết quả có thể trùng với lúc làm dịch vụ khác; phương án mới cần bác sĩ duyệt.',
            style: TextStyle(
              fontSize: 11,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          'Tính lúc ${hospitalTime(comparison.computedAt, pattern: 'dd/MM HH:mm:ss')}',
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        _sequence('Thứ tự chỉ định ban đầu', a.steps),
        _sequence('Thứ tự tối ưu được đề xuất', b.steps),
      ],
    );
  }

  String _resultWait(ComparisonRoute route) {
    final minutes = route.resultWaitAfterLastService;
    return minutes == null ? 'Cần cập nhật' : '$minutes phút';
  }

  TableRow _row(
    String label,
    String before,
    String after, {
    bool header = false,
  }) => TableRow(
    decoration: header
        ? const BoxDecoration(color: AppColors.primaryLight)
        : null,
    children: [label, before, after]
        .map(
          (text) => Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                fontWeight: header ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        )
        .toList(),
  );
  Widget _sequence(String title, List<RouteComparisonStep> steps) => Material(
    color: Colors.transparent,
    child: ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(
        title,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      children: [
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${i + 1}. ${steps[i].serviceName}\n${steps[i].roomName} · di chuyển ${steps[i].travel} phút · chờ ${steps[i].queue} phút${steps[i].result > 0 ? ' · chờ kết quả ${steps[i].result} phút' : ''}',
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
