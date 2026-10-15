import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/appointment_model.dart';
import '../models/encounter_summary_model.dart';
import '../models/follow_up_order_model.dart';
import '../models/paraclinical_plan_model.dart';
import '../models/patient_journey_model.dart';
import '../models/patient_model.dart';
import '../models/patient_visit_model.dart';
import '../models/queue_ticket_model.dart';
import '../services/appointment_service.dart';
import '../services/encounter_service.dart';
import '../services/follow_up_service.dart';
import '../services/patient_realtime_service.dart';
import '../services/patient_service.dart';
import '../services/patient_session_service.dart';
import '../services/queue_service.dart';

class JourneyNotice {
  final String key;
  final String message;
  final DateTime createdAt = DateTime.now();
  bool isRead = false;
  JourneyNotice(this.key, this.message);
}

class HomeProvider extends ChangeNotifier {
  final PatientService _patientService;
  final AppointmentService _appointmentService;
  final EncounterService _encounterService;
  final QueueService _queueService;
  final PatientSessionService _sessionService;
  final FollowUpService _followUpService;
  final PatientRealtimeService _realtimeService;

  HomeProvider({
    PatientService? patientService,
    AppointmentService? appointmentService,
    EncounterService? encounterService,
    QueueService? queueService,
    PatientSessionService? sessionService,
    FollowUpService? followUpService,
    PatientRealtimeService? realtimeService,
    bool loadOnCreate = true,
  }) : _patientService = patientService ?? PatientService(),
       _appointmentService = appointmentService ?? AppointmentService(),
       _encounterService = encounterService ?? EncounterService(),
       _queueService = queueService ?? QueueService(),
       _sessionService = sessionService ?? PatientSessionService(),
       _followUpService = followUpService ?? FollowUpService(),
       _realtimeService = realtimeService ?? PatientRealtimeService() {
    if (loadOnCreate) unawaited(loadHomeData());
  }

  bool _isLoading = false, _isRefreshing = false, _refreshingJourney = false;
  bool _disposed = false, _updatesEnabled = false, _liveConnecting = false;
  bool _isRealtimeConnected = false, _selectionPinned = false;
  int _loadVersion = 0;
  String? _errorMessage, _journeyError;
  DateTime? _lastUpdatedAt;
  PatientModel? _patient;
  AppointmentCheckModel? _appointmentCheck;
  EncounterSummaryModel? _encounterSummary;
  ParaclinicalPlanModel? _paraclinicalPlan;
  QueueTicketModel? _queueTicket;
  FollowUpOrderModel? _latestFollowUpOrder;
  List<PatientVisitModel> _visits = [];
  final List<JourneyNotice> _notices = [];
  Timer? _pollTimer, _eventDebounce;

  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing || _refreshingJourney;
  String? get errorMessage => _errorMessage;
  String? get journeyError => _journeyError;
  DateTime? get lastUpdatedAt => _lastUpdatedAt;
  bool get isRealtimeConnected => _isRealtimeConnected;
  PatientModel? get patient => _patient;
  AppointmentCheckModel? get appointmentCheck => _appointmentCheck;
  EncounterSummaryModel? get encounterSummary => _encounterSummary;
  ParaclinicalPlanModel? get paraclinicalPlan => _paraclinicalPlan;
  QueueTicketModel? get queueTicket => _queueTicket;
  FollowUpOrderModel? get latestFollowUpOrder => _latestFollowUpOrder;
  List<PatientVisitModel> get visits => List.unmodifiable(_visits);
  List<JourneyNotice> get notices => List.unmodifiable(_notices);
  int get unreadNoticeCount => _notices.where((n) => !n.isRead).length;
  String get currentPhone => _sessionService.currentPhone;
  bool get hasActiveAppointment => _appointmentCheck?.hasAppointment == true;
  AppointmentModel? get activeAppointment => _appointmentCheck?.appointment;
  bool get hasActiveEncounter =>
      _encounterSummary != null && !_encounterSummary!.isFinalized;
  PatientJourney? get journey => _encounterSummary == null
      ? null
      : PatientJourney.build(_encounterSummary!, _paraclinicalPlan);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  bool _isCurrent(int version) => !_disposed && version == _loadVersion;

  Future<void> loadHomeData({bool isRefresh = false}) async {
    final version = ++_loadVersion;
    _isRefreshing = isRefresh;
    _isLoading = !isRefresh;
    _errorMessage = null;
    _notify();
    final phone = currentPhone;
    try {
      if (phone.isEmpty) {
        _clearData();
        return;
      }
      final isUuid = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(phone);
      if (isUuid) {
        final summary = await _encounterService.getEncounterStatusSummary(
          phone,
        );
        if (!_isCurrent(version)) return;
        _patient = null;
        _appointmentCheck = null;
        _visits = summary == null
            ? []
            : [PatientVisitModel.fromSummary(summary)];
        await _readJourney(phone, version, initialSummary: summary);
        return;
      }
      final results = await Future.wait<Object?>([
        _patientService.searchPatientByPhone(phone),
        _appointmentService.checkAppointmentByPhone(phone),
      ]);
      if (!_isCurrent(version)) return;
      _patient = results[0] as PatientModel?;
      _appointmentCheck = results[1] as AppointmentCheckModel?;
      if (_patient == null) {
        _clearJourney();
        _visits = [];
        return;
      }
      final patientId = _patient!.id;
      _sessionService.setPatientId(patientId);
      final lookup = await Future.wait<Object?>([
        _encounterService.getPatientHistory(patientId),
        _encounterService.getActiveEncounterByPatient(patientId),
        _followUpService
            .getFollowUpOrdersByPatient(patientId)
            .catchError((_) => <FollowUpOrderModel>[]),
      ]);
      if (!_isCurrent(version)) return;
      final history = lookup[0] as List<PatientVisitModel>?;
      final active = lookup[1] as EncounterSummaryModel?;
      final followUps = lookup[2] as List<FollowUpOrderModel>;
      _latestFollowUpOrder = followUps.isEmpty ? null : followUps.first;
      _visits = history ?? [];
      final previousId = _sessionService.activeEncounterId;
      final pinnedExists =
          _selectionPinned && _visits.any((v) => v.encounterId == previousId);
      String? selectedId = pinnedExists ? previousId : active?.encounterId;
      selectedId ??= _visits.isNotEmpty ? _visits.first.encounterId : null;
      EncounterSummaryModel? selectedSummary;
      if (selectedId == active?.encounterId) selectedSummary = active;
      if (selectedId == null && history == null) {
        final candidates = <String>{
          if (previousId?.isNotEmpty == true) previousId!,
          if (_appointmentCheck?.activeEncounterId?.isNotEmpty == true)
            _appointmentCheck!.activeEncounterId!,
          ...followUps.map((o) => o.encounterId).where((id) => id.isNotEmpty),
        };
        for (final id in candidates) {
          final summary = await _encounterService.getEncounterStatusSummary(id);
          if (!_isCurrent(version)) return;
          if (summary != null && summary.patientPhone == phone) {
            selectedId = id;
            selectedSummary = summary;
            _visits = [PatientVisitModel.fromSummary(summary)];
            break;
          }
        }
      }
      if (selectedId == null) {
        _clearJourney();
        return;
      }
      await _readJourney(selectedId, version, initialSummary: selectedSummary);
    } catch (_) {
      if (_isCurrent(version)) {
        _errorMessage = 'Không thể đồng bộ lượt khám. Vui lòng kiểm tra kết nối và thử lại.';
      }
    } finally {
      if (_isCurrent(version)) {
        _isLoading = false;
        _isRefreshing = false;
        _notify();
        _ensureRealtime();
      }
    }
  }

  Future<void> _readJourney(
    String encounterId,
    int version, {
    EncounterSummaryModel? initialSummary,
    bool announce = false,
  }) async {
    final summary =
        initialSummary ??
        await _encounterService.getEncounterStatusSummary(encounterId);
    if (!_isCurrent(version)) return;
    if (summary == null) {
      _clearJourney();
      return;
    }
    final previous = journey;
    final sameVisit = _encounterSummary?.encounterId == summary.encounterId;
    _encounterSummary = summary;
    _sessionService.setActiveEncounterId(summary.encounterId);
    if (!sameVisit) {
      _paraclinicalPlan = null;
      _queueTicket = null;
    }
    _journeyError = null;
    try {
      final result = await Future.wait<Object?>([
        _encounterService.getParaclinicalPlan(encounterId),
        _queueService.getQueueTicketByEncounter(encounterId),
      ]);
      if (!_isCurrent(version)) return;
      _paraclinicalPlan = result[0] as ParaclinicalPlanModel?;
      _queueTicket = result[1] as QueueTicketModel?;
    } catch (_) {
      if (!_isCurrent(version)) return;
      _journeyError =
          'Chưa tải được đầy đủ các bước cận lâm sàng. Hãy thử cập nhật lại.';
    }
    if (!_isCurrent(version)) return;
    _lastUpdatedAt = DateTime.now();
    if (announce && sameVisit && previous != null) {
      _announceChanges(previous, journey!);
    }
  }

  Future<void> refreshJourney() async {
    if (_disposed || _isLoading || _isRefreshing || _refreshingJourney) return;
    if (_encounterSummary == null) {
      if (currentPhone.isNotEmpty) await loadHomeData(isRefresh: true);
      return;
    }
    if (_encounterSummary!.isFinalized) return;
    final version = _loadVersion;
    _refreshingJourney = true;
    try {
      await _readJourney(
        _encounterSummary!.encounterId,
        version,
        announce: true,
      );
      if (_isCurrent(version)) _errorMessage = null;
    } catch (_) {
      if (_isCurrent(version)) _journeyError = 'Mất kết nối cập nhật. Dữ liệu đang hiển thị là lần đồng bộ gần nhất.';
    } finally {
      _refreshingJourney = false;
      if (_isCurrent(version)) {
        _notify();
        _ensureRealtime();
      }
    }
  }

  Future<void> selectVisit(String encounterId) async {
    if (!_visits.any((v) => v.encounterId == encounterId)) return;
    final version = ++_loadVersion;
    _selectionPinned = true;
    _isLoading = true;
    _errorMessage = null;
    _clearJourney();
    _notify();
    try {
      await _readJourney(encounterId, version);
    } catch (_) {
      if (_isCurrent(version)) {
        _errorMessage = 'Không tải được lượt khám đã chọn.';
      }
    } finally {
      if (_isCurrent(version)) {
        _isLoading = false;
        _notify();
        _ensureRealtime();
      }
    }
  }

  void startUpdates() {
    if (_disposed || _updatesEnabled) return;
    _updatesEnabled = true;
    _pollTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => unawaited(refreshJourney()),
    );
    _ensureRealtime();
  }

  void stopUpdates() {
    _updatesEnabled = false;
    _pollTimer?.cancel();
    _eventDebounce?.cancel();
    _isRealtimeConnected = false;
    unawaited(_realtimeService.disconnect());
  }

  void _ensureRealtime() {
    if (_disposed || !_updatesEnabled || _liveConnecting) return;
    final summary = _encounterSummary;
    if (summary == null || summary.isFinalized) {
      _isRealtimeConnected = false;
      unawaited(_realtimeService.disconnect());
      return;
    }
    _liveConnecting = true;
    final phone = currentPhone;
    bool watchingThisVisit() =>
        !_disposed &&
        _updatesEnabled &&
        currentPhone == phone &&
        _encounterSummary?.encounterId == summary.encounterId;
    unawaited(
      _realtimeService
          .connect(
            encounterId: summary.encounterId,
            onEvent: (event) {
              if (!watchingThisVisit()) return;
              if (event == 'NotificationReceived') {
                _addNotice(
                  'notification:${DateTime.now().millisecondsSinceEpoch}',
                  'Có thông báo mới từ bệnh viện.',
                );
              }
              _eventDebounce?.cancel();
              _eventDebounce = Timer(
                const Duration(milliseconds: 200),
                () => unawaited(refreshJourney()),
              );
            },
            onConnectionChanged: (connected) {
              if (watchingThisVisit()) {
                _isRealtimeConnected = connected;
                _notify();
              }
            },
          )
          .whenComplete(() {
            _liveConnecting = false;
            if (!_disposed &&
                _encounterSummary?.encounterId != summary.encounterId) {
              _ensureRealtime();
            }
          }),
    );
  }

  void _announceChanges(PatientJourney before, PatientJourney after) {
    if (!before.isFinalized && after.isFinalized) {
      _addNotice(
        '${after.summary.encounterId}:finalized',
        'Bác sĩ đã hoàn tất lượt khám của bạn.',
      );
    }
    for (final step in after.steps) {
      final old = before.steps.where((s) => s.id == step.id).firstOrNull;
      if (old != null &&
          (old.state != step.state ||
              old.statusLabel != step.statusLabel ||
              old.location != step.location)) {
        _addNotice(
          [
            after.summary.encounterId,
            step.id,
            step.state.name,
            step.statusLabel,
            step.location,
          ].join(':'),
          '${step.title}: ${step.statusLabel}.${step.location.isEmpty ? '' : ' ${step.location}'}',
        );
      }
    }
  }

  void _addNotice(String key, String message) {
    if (_notices.any((n) => n.key == key)) return;
    _notices.insert(0, JourneyNotice(key, message));
    if (_notices.length > 30) _notices.removeLast();
    _notify();
  }

  void markNoticesRead() {
    for (final notice in _notices) {
      notice.isRead = true;
    }
    _notify();
  }

  void _clearJourney() {
    _encounterSummary = null;
    _paraclinicalPlan = null;
    _queueTicket = null;
    _journeyError = null;
    _lastUpdatedAt = null;
    _isRealtimeConnected = false;
    unawaited(_realtimeService.disconnect());
  }

  void _clearData() {
    _patient = null;
    _appointmentCheck = null;
    _latestFollowUpOrder = null;
    _visits = [];
    _notices.clear();
    _clearJourney();
  }

  void setDemoPhone(String phone, {String? encounterId}) =>
      switchPhone(phone, encounterId: encounterId);

  void switchPhone(String phone, {String? encounterId}) {
    if (phone.trim() != currentPhone) {
      _loadVersion++;
      _clearData();
      _sessionService.clearSession();
      _selectionPinned = false;
    }
    _sessionService.setPhone(phone);
    if (encounterId?.isNotEmpty == true) {
      _sessionService.setActiveEncounterId(encounterId);
    }
    unawaited(loadHomeData());
  }

  void logout() {
    _loadVersion++;
    _sessionService.clearSession();
    _selectionPinned = false;
    _clearData();
    _isLoading = false;
    _isRefreshing = false;
    _errorMessage = null;
    _notify();
  }

  void retry() => unawaited(loadHomeData());

  @override
  void dispose() {
    _disposed = true;
    _loadVersion++;
    stopUpdates();
    super.dispose();
  }
}
