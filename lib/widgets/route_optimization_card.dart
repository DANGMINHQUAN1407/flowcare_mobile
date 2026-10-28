import 'dart:async';

import 'package:flutter/material.dart';

import '../core/network/api_client.dart';
import '../core/network/api_exceptions.dart';
import '../core/theme/app_colors.dart';
import '../models/paraclinical_plan_model.dart';
import '../models/route_optimization_model.dart';
import '../models/route_assistance_model.dart' show RouteComparison;
import '../services/patient_session_service.dart';
import '../services/route_optimization_service.dart';

class RouteOptimizationCard extends StatefulWidget {
  final String encounterId, patientId;
  final bool isStale;
  final DateTime? refreshToken;
  final Future<void> Function() onChanged;
  final RouteOptimizationService? service;
  const RouteOptimizationCard({
    super.key,
    required this.encounterId,
    required this.patientId,
    required this.onChanged,
    this.isStale = false,
    this.refreshToken,
    this.service,
  });
  @override
  State<RouteOptimizationCard> createState() => _RouteOptimizationCardState();
}

class _RouteOptimizationCardState extends State<RouteOptimizationCard> {
  late final RouteOptimizationService _service;
  late final int _session, _apiVersion;
  RouteOptimizationEligibility? _eligibility;
  ParaclinicalPlanModel? _appliedPlan;
  RouteComparison? _comparison;
  String? _error, _notice, _seenActive;
  bool _loading = false, _sending = false, _comparing = false;
  bool get _current =>
      mounted &&
      _session == PatientSessionService().version &&
      _apiVersion == ApiClient.sessionVersion &&
      PatientSessionService().patientId == widget.patientId;
  bool get _allowed =>
      !PatientSessionService().isDemo && ApiClient.authToken != null;
  @override
  void initState() {
    super.initState();
    _service = widget.service ?? RouteOptimizationService();
    _session = PatientSessionService().version;
    _apiVersion = ApiClient.sessionVersion;
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant RouteOptimizationCard oldWidget) {
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
    setState(() => _loading = true);
    try {
      final data = await _service.eligibility(
        widget.encounterId,
        widget.patientId,
      );
      if (!_current) return;
      final applied =
          _eligibility?.proposedPlanId != null &&
          data.activePlanId == _eligibility!.proposedPlanId &&
          data.activePlanId != _seenActive;
      setState(() {
        _eligibility = data;
        _error = null;
        if (applied) {
          _seenActive = data.activePlanId;
          _notice = 'Lộ trình tối ưu đã được áp dụng.';
        }
      });
      if (applied) unawaited(widget.onChanged());
    } catch (error) {
      if (_current) setState(() => _error = patientErrorMessage(error));
    } finally {
      if (_current) setState(() => _loading = false);
    }
  }

  Future<void> _optimize() async {
    if (!_current ||
        !_allowed ||
        _loading ||
        _sending ||
        widget.isStale ||
        _error != null ||
        _eligibility?.canOptimize != true) {
      return;
    }
    setState(() {
      _sending = true;
      _notice = null;
    });
    try {
      final proposal = await _service.optimize(
        widget.encounterId,
        widget.patientId,
      );
      if (!_current) return;
      setState(() {
        _appliedPlan = proposal;
        _seenActive = proposal.id;
        _notice =
            'Đã tối ưu và áp dụng lộ trình mới. Trang bác sĩ đã được cập nhật.';
      });
      unawaited(widget.onChanged());
    } catch (error) {
      if (_current) setState(() => _error = patientErrorMessage(error));
    } finally {
      if (_current) {
        setState(() => _sending = false);
        await _load();
      }
    }
  }

  Future<void> _compare() async {
    if (!_current || !_allowed || _comparing || widget.isStale) return;
    setState(() => _comparing = true);
    try {
      final comparison = await _service.compare(
        widget.encounterId,
        widget.patientId,
      );
      if (_current) setState(() => _comparison = comparison);
    } catch (error) {
      if (_current) setState(() => _error = patientErrorMessage(error));
    } finally {
      if (_current) setState(() => _comparing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_allowed) return const SizedBox.shrink();
    final pending = _eligibility?.proposedPlanId != null;
    final canOptimize =
        _eligibility?.canOptimize == true &&
        (_eligibility?.remainingOrders ?? 0) >= 2 &&
        !_loading &&
        !_sending &&
        _error == null &&
        !widget.isStale;
    return Container(
      key: const ValueKey('route-optimization-card'),
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
            children: [
              const Icon(Icons.auto_awesome, color: AppColors.primary),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Tối ưu lộ trình',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
              IconButton(
                tooltip: 'Cập nhật tối ưu',
                onPressed: _loading || _sending ? null : _load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const Text(
            'Bấm Tối ưu để hệ thống tính và áp dụng ngay lộ trình mới. Trang bác sĩ được cập nhật tự động.',
            style: TextStyle(fontSize: 12, height: 1.5),
          ),
          if (_notice != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _notice!,
                style: const TextStyle(color: AppColors.success, fontSize: 12),
              ),
            ),
          if (pending)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Đã có phương án tối ưu. Bấm Tối ưu ngay để tính lại và áp dụng theo hàng đợi hiện tại.',
                style: TextStyle(fontSize: 12, height: 1.5),
              ),
            ),
          if (_loading) const LinearProgressIndicator(),
          if (_eligibility?.reason != null && !pending)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _eligibility!.reason!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          if (_error != null || widget.isStale)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                widget.isStale
                    ? 'Cập nhật lượt khám trước khi tối ưu.'
                    : _error!,
                style: const TextStyle(fontSize: 12, color: AppColors.warning),
              ),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const ValueKey('optimize-route'),
            onPressed: canOptimize ? _optimize : null,
            icon: _sending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(_sending ? 'Đang tối ưu và áp dụng…' : 'Tối ưu ngay'),
          ),
          OutlinedButton.icon(
            onPressed:
                _comparing ||
                    widget.isStale ||
                    (_eligibility?.remainingOrders ?? 0) < 2
                ? null
                : _compare,
            icon: const Icon(Icons.compare_arrows),
            label: Text(
              _comparing ? 'Đang so sánh…' : 'So sánh trước / sau tối ưu',
            ),
          ),
          if (_appliedPlan != null) ...[
            const SizedBox(height: 8),
            Text(
              'Lộ trình đã áp dụng: ${_appliedPlan!.estimatedTotalMinutes?.round() ?? '—'} phút',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            ..._appliedPlan!.steps.map(
              (s) => Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  '${s.stepOrder}. ${s.serviceTypeName} — ${s.roomName}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
          if (_comparison != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Ban đầu: ${_comparison!.baseline.total} phút · Tối ưu: ${_comparison!.optimized.total} phút\n${_comparison!.savedMinutes > 0 ? 'Dự kiến tiết kiệm ${_comparison!.savedMinutes} phút.' : 'Hai phương án có thời gian tương đương.'}',
                style: const TextStyle(fontSize: 12, height: 1.5),
              ),
            ),
        ],
      ),
    );
  }
}
