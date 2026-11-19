import 'dart:async';

import 'package:flutter/material.dart';

import '../core/network/api_client.dart';
import '../core/network/api_exceptions.dart';
import '../core/theme/app_colors.dart';
import '../models/paraclinical_plan_model.dart';
import '../models/route_optimization_model.dart';

import '../services/patient_session_service.dart';
import '../services/route_optimization_service.dart';
import 'journey_timing_card.dart';

class RouteOptimizationCard extends StatefulWidget {
  final String encounterId, patientId;
  final bool isStale;
  final bool allowOptimization;
  final DateTime? refreshToken;
  final Future<void> Function() onChanged;
  final RouteOptimizationService? service;
  final ParaclinicalPlanModel? currentPlan;
  final String? requestedOfferId;
  final ValueChanged<String>? onRouteReviewed;
  const RouteOptimizationCard({
    super.key,
    required this.encounterId,
    required this.patientId,
    required this.onChanged,
    this.isStale = false,
    this.allowOptimization = true,
    this.refreshToken,
    this.service,
    this.currentPlan,
    this.requestedOfferId,
    this.onRouteReviewed,
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
  String? _checkedWithoutOfferPlanId;
  bool _loading = false, _sending = false;
  bool get _allowed =>
      !PatientSessionService().isDemo && ApiClient.authToken != null;
  bool get _current =>
      mounted &&
      _session == PatientSessionService().version &&
      _apiVersion == ApiClient.sessionVersion &&
      PatientSessionService().patientId == widget.patientId;
  bool get _canLoad =>
      _current && _allowed && !_loading && !_sending && !widget.isStale;
  bool get _routeLocked =>
      widget.currentPlan?.isLocked == true ||
      _eligibility?.reason == 'ROUTE_LOCKED';
  bool get _routeAccepted =>
      _appliedPlan?.acceptedOfferSavedMinutes != null ||
      widget.currentPlan?.acceptedOfferSavedMinutes != null ||
      (_eligibility?.reason == 'ROUTE_ALREADY_ACCEPTED' &&
          (widget.currentPlan == null ||
              _eligibility?.activePlanId == widget.currentPlan?.id));
  bool get _canRespond =>
      _canLoad && widget.allowOptimization && !_routeLocked && !_routeAccepted;

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
    if (current?.isLocked == true && previous?.isLocked != true) {
      _reviewedOfferId = null;
    }
    if (previous != null && current != null && previous.id != current.id) {
      _previousPlan = previous;
      if (_appliedPlan?.id != current.id) {
        _appliedPlan = current;
        _notice = 'Lộ trình đã thay đổi. Hãy xem lại dịch vụ và phòng được phân công.';
      }
    }
    if (oldWidget.refreshToken != widget.refreshToken ||
        previous?.id != current?.id ||
        previous?.isLocked != current?.isLocked ||
        (oldWidget.isStale && !widget.isStale)) {
      unawaited(_load());
    }
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
    if (!_canLoad || (review && !_canRespond)) return;
    setState(() => _loading = true);
    try {
      final fetch = review && widget.requestedOfferId == null
          ? _service.requestOptimization
          : _service.eligibility;
      final data = await fetch(widget.encounterId, widget.patientId);
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
        if (data.reason != 'NO_BETTER_ROUTE') {
          _checkedWithoutOfferPlanId = null;
        } else if (review) {
          _checkedWithoutOfferPlanId = data.activePlanId;
        }
        if ((review || widget.requestedOfferId != null) &&
            _matchesRequest(data) &&
            data.canOptimize &&
            !_expired(data)) {
          _reviewedOfferId = data.proposedPlanId;
        }
      });
      final activePlanId = data.activePlanId;
      if (activePlanId != null &&
          !data.canOptimize &&
          (data.reason == 'ROUTE_LOCKED' ||
              data.reason == 'TOO_FEW_STEPS' ||
              (review && data.reason == 'NO_BETTER_ROUTE'))) {
        widget.onRouteReviewed?.call(activePlanId);
      }
    } catch (error) {
      if (_current) setState(() => _error = patientErrorMessage(error));
    } finally {
      if (_current) setState(() => _loading = false);
    }
  }

  Future<void> _confirmAccept(RouteOptimizationEligibility offer) async {
    if (!_canRespond) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bạn có chấp nhận lộ trình đề xuất không?'),
        content: const Text(
          'Sau khi xác nhận, app sẽ áp dụng thứ tự mới và dừng tối ưu cho lộ trình này. Bác sĩ có thể khóa lộ trình trên màn hình của mình.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận chấp nhận'),
          ),
        ],
      ),
    );
    if (confirmed != true || !_current) return;
    final latest = _eligibility;
    if (_expired(offer) ||
        latest == null ||
        latest.proposedPlanId != offer.proposedPlanId) {
      setState(() {
        _notice = _expired(offer)
            ? 'Đề xuất tối ưu đã hết hạn.'
            : 'Đề xuất đã thay đổi. Hãy xem lại trước khi xác nhận.';
      });
      return;
    }
    await _respond(latest);
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
        !identical(_eligibility, offer)) {
      return;
    }
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
        refresh = false;
        widget.onRouteReviewed?.call(plan.id);
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
        final activePlanId = data.activePlanId;
        if (activePlanId != null) widget.onRouteReviewed?.call(activePlanId);
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
      if (codes.contains('ROUTE_ALREADY_ACCEPTED')) return error.message;
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
        widget.allowOptimization &&
        !_routeLocked &&
        !_routeAccepted &&
        _matchesRequest(data) &&
        (widget.currentPlan == null ||
            data?.activePlanId == widget.currentPlan?.id) &&
        data?.canOptimize == true &&
        data?.proposedPlanId != null &&
        offer?.id == data?.proposedPlanId &&
        offer?.encounterId == widget.encounterId;
    final reviewing = validOffer && _reviewedOfferId == data?.proposedPlanId;
    final enabled = _canRespond && _error == null && reviewing && !expired;
    final reviewedOffer = reviewing && !expired ? data : null;
    final currentPlan = widget.onRouteReviewed == null
        ? null
        : widget.currentPlan;
    final appliedPlan = _appliedPlan ?? widget.currentPlan;
    final canRequest =
        widget.requestedOfferId == null &&
        widget.onRouteReviewed != null &&
        widget.currentPlan?.status.toLowerCase() == 'active' &&
        widget.allowOptimization &&
        !_routeLocked &&
        !_routeAccepted &&
        !(data?.activePlanId == widget.currentPlan?.id &&
            data?.reason == 'TOO_FEW_STEPS');
    final showOptimize =
        (!reviewing || expired) && (canRequest || (validOffer && !expired));
    final checkedWithoutOffer =
        data?.reason == 'NO_BETTER_ROUTE' &&
        _checkedWithoutOfferPlanId != null &&
        _checkedWithoutOfferPlanId == data?.activePlanId &&
        _checkedWithoutOfferPlanId == widget.currentPlan?.id;
    final reason = switch (data?.reason) {
      _
          when widget.requestedOfferId == data?.activePlanId &&
              widget.requestedOfferId != null =>
        'Đề xuất trong thông báo đã được áp dụng.',
      _ when widget.requestedOfferId != null => 'Đề xuất trong thông báo đã hết hiệu lực. Mở tab Lộ trình để xem cập nhật mới nhất.',
      _ when checkedWithoutOffer => 'Đã tính lại theo hàng đợi hiện tại. Chưa có phương án đáp ứng ràng buộc của bác sĩ và mức tiết kiệm yêu cầu. Bạn tiếp tục theo lộ trình hiện tại.',
      _ when canRequest =>
        'Bấm Tối ưu lộ trình để kiểm tra phương án theo hàng đợi hiện tại.',
      'TOO_FEW_STEPS' => 'Cần ít nhất hai y lệnh còn chờ để tính lại lộ trình.',
      'NO_ACTIVE_PLAN' => 'Chưa có lộ trình đang thực hiện.',
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
                  onPressed: _canLoad ? _load : null,
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
            if (_routeLocked)
              const Text('Lộ trình đã được bác sĩ khóa.')
            else if (_routeAccepted)
              const Text(
                'Bạn đã chấp nhận lộ trình. Bác sĩ có thể khóa lộ trình này.',
              )
            else if (expired)
              const Text('Đề xuất tối ưu đã hết hạn.'),
            if (reviewedOffer != null) ...[
              if (reviewedOffer.savedMinutes case final minutes?)
                Text(
                  'Dự kiến tiết kiệm $minutes phút.',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              if (currentPlan == null &&
                  reviewedOffer.currentTotalMinutes != null)
                Text(
                  'Lộ trình hiện tại · ${reviewedOffer.currentTotalMinutes} phút',
                ),
              if (reviewedOffer.expiresAt case final expires?)
                Text(
                  'Có hiệu lực đến ${TimeOfDay.fromDateTime(expires.toLocal()).format(context)}',
                ),
            ],
            if (currentPlan != null) ...[
              const SizedBox(height: 8),
              _RouteStepsSection(
                key: ValueKey('current-route-${currentPlan.id}'),
                title: 'Lộ trình hiện tại',
                plan: currentPlan,
                totalMinutes: reviewedOffer?.currentTotalMinutes?.toDouble(),
              ),
              const SizedBox(height: 8),
            ],
            if (!validOffer &&
                !_routeLocked &&
                !_routeAccepted &&
                !expired &&
                !_loading &&
                _error == null)
              Semantics(liveRegion: true, child: Text(reason)),
            if (showOptimize)
              FilledButton(
                onPressed: _canRespond ? () => _load(review: true) : null,
                child: Text(
                  widget.onRouteReviewed == null
                      ? 'Nhờ tối ưu lộ trình'
                      : 'Tối ưu lộ trình',
                ),
              ),
            if (reviewedOffer != null) ...[
              if (reviewedOffer.offer case final plan?)
                _RouteStepsSection(
                  key: ValueKey('proposed-route-${plan.id}'),
                  title: 'Lộ trình đề xuất',
                  plan: plan,
                  totalMinutes: reviewedOffer.offeredTotalMinutes?.toDouble(),
                ),
              const SizedBox(height: 8),
              FilledButton(
                key: const ValueKey('accept-route-offer'),
                onPressed: enabled ? () => _confirmAccept(reviewedOffer) : null,
                child: const Text('Chấp nhận đề xuất'),
              ),
              OutlinedButton(
                onPressed: enabled ? () => _decline(reviewedOffer) : null,
                child: const Text('Từ chối đề xuất'),
              ),
            ],
            if (appliedPlan?.acceptedOfferSavedMinutes case final minutes?)
              Text('Lộ trình đã áp dụng · Dự kiến tiết kiệm $minutes phút.'),
            if (_appliedPlan case final plan?) ...[
              if (_previousPlan case final previous?
                  when previous.id != plan.id) ...[
                const SizedBox(height: 8),
                _RouteStepsSection(
                  key: ValueKey('previous-route-${previous.id}'),
                  title: 'Lộ trình trước khi thay thế',
                  plan: previous,
                ),
              ],
              if (widget.onRouteReviewed == null ||
                  widget.currentPlan?.id != plan.id) ...[
                const SizedBox(height: 8),
                _RouteStepsSection(
                  key: ValueKey('applied-route-${plan.id}'),
                  title: 'Lộ trình đã áp dụng',
                  plan: plan,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _RouteStepsSection extends StatelessWidget {
  final String title;
  final ParaclinicalPlanModel plan;
  final double? totalMinutes;

  const _RouteStepsSection({
    super.key,
    required this.title,
    required this.plan,
    this.totalMinutes,
  });

  @override
  Widget build(BuildContext context) {
    const padding = EdgeInsets.symmetric(horizontal: 12);
    final heading = Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.bold),
    );
    final duration = Text(
      journeyMinutes(totalMinutes ?? plan.estimatedTotalMinutes),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: plan.steps.isEmpty
          ? ListTile(
              contentPadding: padding,
              title: heading,
              subtitle: duration,
              dense: true,
            )
          : ExpansionTile(
              tilePadding: padding,
              shape: const Border(),
              collapsedShape: const Border(),
              title: heading,
              subtitle: duration,
              children: [
                for (final step in plan.steps)
                  ListTile(
                    contentPadding: padding,
                    dense: true,
                    title: Text('${step.stepOrder}. ${step.serviceTypeName}'),
                    subtitle: step.location.isEmpty
                        ? null
                        : Text(step.location),
                  ),
              ],
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
