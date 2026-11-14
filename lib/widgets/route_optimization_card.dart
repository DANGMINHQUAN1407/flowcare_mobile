import 'dart:async';

import 'package:flutter/material.dart';

import '../core/network/api_client.dart';
import '../core/network/api_exceptions.dart';
import '../core/theme/app_colors.dart';
import '../models/paraclinical_plan_model.dart';
import '../models/route_optimization_model.dart';

import '../services/patient_session_service.dart';
import '../services/route_optimization_service.dart';

class RouteOptimizationCard extends StatefulWidget {
  final String encounterId, patientId;
  final bool isStale;
  final DateTime? refreshToken;
  final Future<void> Function() onChanged;
  final RouteOptimizationService? service;
  final ParaclinicalPlanModel? currentPlan;
  final Widget? assistance;
  final String? requestedOfferId;
  const RouteOptimizationCard({
    super.key,
    required this.encounterId,
    required this.patientId,
    required this.onChanged,
    this.isStale = false,
    this.refreshToken,
    this.service,
    this.currentPlan,
    this.assistance,
    this.requestedOfferId,
  });
  @override
  State<RouteOptimizationCard> createState() => _RouteOptimizationCardState();
}

class _RouteOptimizationCardState extends State<RouteOptimizationCard> {
  late final RouteOptimizationService _service;
  late final int _session, _apiVersion;
  RouteOptimizationEligibility? _eligibility;
  ParaclinicalPlanModel? _appliedPlan;
  ParaclinicalPlanModel? _previousPlan;
  Timer? _expiryTimer;
  String? _error, _notice;
  String? _reviewedOfferId;
  bool _loading = false, _sending = false;
  bool get _allowed =>
      !PatientSessionService().isDemo && ApiClient.authToken != null;
  bool get _current =>
      mounted &&
      _session == PatientSessionService().version &&
      _apiVersion == ApiClient.sessionVersion &&
      PatientSessionService().patientId == widget.patientId;
  bool get _canRespond =>
      _current && _allowed && !_loading && !_sending && !widget.isStale;

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
    final previous = oldWidget.currentPlan;
    final current = widget.currentPlan;
    if (previous != null && current != null && previous.id != current.id) {
      _previousPlan = previous;
      if (_appliedPlan?.id != current.id) {
        _appliedPlan = current;
        _notice = 'Lộ trình đã thay đổi. Hãy xem lại dịch vụ và phòng được phân công.';
      }
    }
    if (oldWidget.refreshToken != widget.refreshToken ||
        (oldWidget.isStale && !widget.isStale))
      unawaited(_load());
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    if (widget.service == null) _service.close();
    super.dispose();
  }

  bool _expired(RouteOptimizationEligibility data) =>
      data.expiresAt?.isAfter(DateTime.now()) == false;

  bool _matchesRequest(RouteOptimizationEligibility? data) =>
      widget.requestedOfferId == null ||
      widget.requestedOfferId == data?.proposedPlanId;

  void _showEligibility(RouteOptimizationEligibility data) {
    _expiryTimer?.cancel();
    if (_reviewedOfferId != data.proposedPlanId) _reviewedOfferId = null;
    _eligibility = data;
    _error = null;
    final expires = data.expiresAt;
    if (data.offer != null && expires != null && !_expired(data)) {
      _expiryTimer = Timer(expires.difference(DateTime.now()), () {
        if (_current) setState(() {});
      });
    }
  }

  Future<void> _load({bool review = false}) async {
    if (!_canRespond) return;
    setState(() => _loading = true);
    try {
      final data = await _service.eligibility(
        widget.encounterId,
        widget.patientId,
      );
      if (!_current) return;
      setState(() {
        final previous = _eligibility;
        if (previous?.proposedPlanId != null &&
            previous!.proposedPlanId != data.proposedPlanId) {
          if (previous.proposedPlanId == data.activePlanId) {
            _notice = 'Lộ trình tối ưu đã được áp dụng.';
          } else if (_expired(previous)) {
            _notice = 'Đề xuất tối ưu đã hết hạn.';
          } else {
            _notice =
                'Đề xuất đã thay đổi. Hãy xem lại lộ trình trước khi xác nhận.';
          }
        }
        if (_appliedPlan?.id != data.activePlanId) _appliedPlan = null;
        _showEligibility(data);
        if ((review || widget.requestedOfferId != null) &&
            _matchesRequest(data) &&
            data.canOptimize &&
            !_expired(data)) {
          _reviewedOfferId = data.proposedPlanId;
        }
      });
    } catch (error) {
      if (_current) setState(() => _error = patientErrorMessage(error));
    } finally {
      if (_current) setState(() => _loading = false);
    }
  }

  Future<void> _decline(RouteOptimizationEligibility offer) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _DeclineRouteDialog(),
    );
    if (reason == null || !_current) return;
    if (!identical(_eligibility, offer) || _expired(offer)) {
      setState(() {
        _notice = _expired(offer)
            ? 'Đề xuất tối ưu đã hết hạn.'
            : 'Đề xuất đã thay đổi. Hãy xem lại trước khi từ chối.';
      });
      return;
    }
    await _respond(offer, reason: reason);
  }

  Future<void> _respond(
    RouteOptimizationEligibility offer, {
    String? reason,
  }) async {
    final id = offer.proposedPlanId;
    if (!_canRespond ||
        id == null ||
        id != _reviewedOfferId ||
        _expired(offer) ||
        !identical(_eligibility, offer))
      return;
    setState(() {
      _sending = true;
      _notice = null;
      _error = null;
    });
    var refresh = true;
    try {
      if (reason == null) {
        final previousPlan = widget.currentPlan;
        final plan = await _service.accept(
          widget.encounterId,
          widget.patientId,
          id,
        );
        if (!_current) return;
        setState(() {
          _eligibility = null;
          _appliedPlan = plan;
          _previousPlan = previousPlan;
          _notice = 'Đã áp dụng lộ trình tối ưu.';
        });
        unawaited(widget.onChanged());
      } else {
        final data = await _service.decline(
          widget.encounterId,
          widget.patientId,
          id,
          reason,
        );
        if (!_current) return;
        setState(() {
          _showEligibility(data);
          _notice = 'Đã từ chối đề xuất.';
        });
        refresh = false;
      }
    } catch (error) {
      if (!_current) return;
      setState(() {
        _eligibility = null;
        _notice = _responseError(error);
      });
      unawaited(widget.onChanged());
    } finally {
      if (_current) {
        setState(() {
          _sending = false;
          _reviewedOfferId = null;
        });
        if (refresh) await _load();
      }
    }
  }

  String _responseError(Object error) {
    if (error is ApiException) {
      final codes = error.codes;
      if (codes.contains('OFFER_EXPIRED')) return 'Đề xuất tối ưu đã hết hạn.';
      if (codes.contains('ROUTE_LOCKED') ||
          codes.contains('OFFER_NOT_FEASIBLE') ||
          codes.contains('OFFER_NOT_WORTH') ||
          codes.contains('NO_OPEN_OFFER')) {
        return '${error.message} Bạn tiếp tục theo lộ trình hiện tại.';
      }
      if (codes.contains('OFFER_STALE') || error.statusCode == 409) {
        return '${error.message} Bạn tiếp tục theo lộ trình hiện tại. Hãy xem và xác nhận lại nếu có đề xuất mới.';
      }
    }
    return 'Chưa xác minh được phản hồi. ${patientErrorMessage(error)}';
  }

  @override
  Widget build(BuildContext context) {
    if (!_allowed) return const SizedBox.shrink();
    final data = _eligibility;
    final offer = data?.offer;
    final expired = data != null && _expired(data);
    final validOffer =
        _matchesRequest(data) &&
        data?.canOptimize == true &&
        data?.proposedPlanId != null &&
        offer?.id == data?.proposedPlanId &&
        offer?.encounterId == widget.encounterId;
    final reviewing = validOffer && _reviewedOfferId == data?.proposedPlanId;
    final enabled = _canRespond && _error == null && reviewing && !expired;
    if ((!validOffer || expired) &&
        !_loading &&
        !_sending &&
        _appliedPlan == null &&
        _error == null &&
        widget.assistance != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_notice != null) Text(_notice!),
          if (expired) const Text('Đề xuất tối ưu đã hết hạn.'),
          widget.assistance!,
        ],
      );
    }
    final reason = switch (data?.reason) {
      'ROUTE_LOCKED' => 'Thứ tự dịch vụ đã được bác sĩ khóa.',
      'TOO_FEW_STEPS' => 'Cần ít nhất hai dịch vụ đủ điều kiện.',
      'NO_ACTIVE_PLAN' => 'Chưa có lộ trình đang thực hiện.',
      _
          when widget.requestedOfferId == data?.activePlanId &&
              widget.requestedOfferId != null =>
        'Đề xuất trong thông báo đã được áp dụng.',
      _ when widget.requestedOfferId != null => 'Đề xuất trong thông báo đã hết hiệu lực. Mở tab Lộ trình để xem cập nhật mới nhất.',
      _ => 'Hiện chưa có đề xuất tối ưu.',
    };
    return Card(
      key: const ValueKey('route-optimization-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Đề xuất tối ưu lộ trình',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
                IconButton(
                  tooltip: 'Cập nhật tối ưu',
                  onPressed: _canRespond ? _load : null,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            if (_loading || _sending) const LinearProgressIndicator(),
            if (_notice != null) Text(_notice!),
            if (widget.isStale)
              const Text('Cập nhật lượt khám để xem đề xuất mới nhất.'),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: AppColors.warning)),
            if (expired) const Text('Đề xuất tối ưu đã hết hạn.'),
            if (!validOffer &&
                !_loading &&
                _error == null &&
                _appliedPlan == null)
              Text(reason),
            if (validOffer && !expired && !reviewing)
              FilledButton(
                onPressed: _canRespond ? () => _load(review: true) : null,
                child: const Text('Nhờ tối ưu lộ trình'),
              ),
            if (reviewing && !expired && offer != null && data != null) ...[
              if (data.savedMinutes != null)
                Text(
                  'Dự kiến tiết kiệm ${data.savedMinutes} phút.',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              if (data.currentTotalMinutes != null &&
                  data.offeredTotalMinutes != null)
                Text(
                  'Hiện tại ${data.currentTotalMinutes} phút · Đề xuất ${data.offeredTotalMinutes} phút',
                ),
              if (data.expiresAt case final expires?)
                Text(
                  'Có hiệu lực đến ${TimeOfDay.fromDateTime(expires.toLocal()).format(context)}',
                ),
              for (final step in offer.steps)
                Text(
                  '${step.stepOrder}. ${step.serviceTypeName} · ${step.location}',
                ),
              const SizedBox(height: 8),
              FilledButton(
                key: const ValueKey('accept-route-offer'),
                onPressed: enabled ? () => _respond(data) : null,
                child: const Text('Chấp nhận đề xuất'),
              ),
              OutlinedButton(
                onPressed: enabled ? () => _decline(data) : null,
                child: const Text('Từ chối đề xuất'),
              ),
            ],
            if (_appliedPlan case final plan?) ...[
              if (_previousPlan case final previous?
                  when previous.id != plan.id)
                ExpansionTile(
                  title: const Text('Lộ trình trước khi thay thế'),
                  children: [
                    for (final step in previous.steps)
                      ListTile(
                        title: Text(
                          '${step.stepOrder}. ${step.serviceTypeName} · ${step.location}',
                        ),
                      ),
                  ],
                ),
              const Text(
                'Lộ trình đã áp dụng',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              for (final step in plan.steps)
                Text(
                  '${step.stepOrder}. ${step.serviceTypeName} · ${step.location}',
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DeclineRouteDialog extends StatefulWidget {
  const _DeclineRouteDialog();

  @override
  State<_DeclineRouteDialog> createState() => _DeclineRouteDialogState();
}

class _DeclineRouteDialogState extends State<_DeclineRouteDialog> {
  String _reason = '';

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Từ chối đề xuất tối ưu?'),
    content: TextField(
      maxLength: 300,
      decoration: const InputDecoration(labelText: 'Lý do (không bắt buộc)'),
      onChanged: (value) => _reason = value,
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Quay lại'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _reason.trim()),
        child: const Text('Xác nhận từ chối'),
      ),
    ],
  );
}
