import 'package:flutter/foundation.dart';
import '../models/appointment_model.dart';
import '../models/encounter_summary_model.dart';
import '../models/follow_up_order_model.dart';
import '../models/patient_model.dart';
import '../models/queue_ticket_model.dart';
import '../services/appointment_service.dart';
import '../services/encounter_service.dart';
import '../services/follow_up_service.dart';
import '../services/patient_service.dart';
import '../services/patient_session_service.dart';
import '../services/queue_service.dart';

class HomeProvider extends ChangeNotifier {
  final PatientService _patientService;
  final AppointmentService _appointmentService;
  final EncounterService _encounterService;
  final QueueService _queueService;
  final PatientSessionService _sessionService;
  final FollowUpService _followUpService;

  HomeProvider({
    PatientService? patientService,
    AppointmentService? appointmentService,
    EncounterService? encounterService,
    QueueService? queueService,
    PatientSessionService? sessionService,
    FollowUpService? followUpService,
  })  : _patientService = patientService ?? PatientService(),
        _appointmentService = appointmentService ?? AppointmentService(),
        _encounterService = encounterService ?? EncounterService(),
        _queueService = queueService ?? QueueService(),
        _sessionService = sessionService ?? PatientSessionService(),
        _followUpService = followUpService ?? FollowUpService() {
    loadHomeData();
  }

  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;

  PatientModel? _patient;
  AppointmentCheckModel? _appointmentCheck;
  EncounterSummaryModel? _encounterSummary;
  QueueTicketModel? _queueTicket;
  FollowUpOrderModel? _latestFollowUpOrder;

  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  String? get errorMessage => _errorMessage;

  PatientModel? get patient => _patient;
  AppointmentCheckModel? get appointmentCheck => _appointmentCheck;
  EncounterSummaryModel? get encounterSummary => _encounterSummary;
  QueueTicketModel? get queueTicket => _queueTicket;
  FollowUpOrderModel? get latestFollowUpOrder => _latestFollowUpOrder;
  String get currentPhone => _sessionService.currentPhone;

  bool get hasActiveAppointment => _appointmentCheck?.hasAppointment == true;
  AppointmentModel? get activeAppointment => _appointmentCheck?.appointment;
  bool get hasActiveEncounter => _encounterSummary != null;

  Future<void> loadHomeData({bool isRefresh = false}) async {
    if (isRefresh) {
      _isRefreshing = true;
      notifyListeners();
    } else if (!_isLoading) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final phone = _sessionService.currentPhone;

      if (phone.isEmpty) {
        _patient = null;
        _appointmentCheck = null;
        _encounterSummary = null;
        _queueTicket = null;
        _errorMessage = null;
        _isLoading = false;
        _isRefreshing = false;
        notifyListeners();
        return;
      }

      // 1. Fetch Patient Info & Active Appointment Check concurrently
      final isUuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(phone);

      if (isUuid) {
        _encounterSummary = await _encounterService.getEncounterStatusSummary(phone);
        _queueTicket = await _queueService.getQueueTicketByEncounter(phone);
        if (_encounterSummary != null) {
          _sessionService.setActiveEncounterId(phone);
        }
        _errorMessage = null;
        return;
      }

      final results = await Future.wait([
        _patientService.searchPatientByPhone(phone).catchError((_) => null),
        _appointmentService.checkAppointmentByPhone(phone).catchError(
          (_) => const AppointmentCheckModel(hasAppointment: false),
        ),
      ]);

      _patient = results[0] as PatientModel?;
      _appointmentCheck = results[1] as AppointmentCheckModel?;

      if (_patient != null) {
        _sessionService.setPatientId(_patient!.id);
      }

      // 2. Resolve Active Encounter ID:
      // Priority A: Linked from online appointment check
      // Priority B: Stored in session from check-in
      // Priority C: Direct active encounter query by patient ID (GET /encounters/patient/{patientId}/active)
      // Priority D: Check patient follow-up orders (GET /follow-up-orders/patient/{patientId})
      String? activeEncounterId = _appointmentCheck?.activeEncounterId ?? _sessionService.activeEncounterId;

      if ((activeEncounterId == null || activeEncounterId.isEmpty) && _patient != null) {
        try {
          final activeSummary = await _encounterService.getActiveEncounterByPatient(_patient!.id);
          if (activeSummary != null && activeSummary.encounterId.isNotEmpty) {
            activeEncounterId = activeSummary.encounterId;
            _encounterSummary = activeSummary;
          }
        } catch (_) {}
      }

      if ((activeEncounterId == null || activeEncounterId.isEmpty) && _patient != null) {
        try {
          final followUpOrders = await _followUpService.getFollowUpOrdersByPatient(_patient!.id);
          if (followUpOrders.isNotEmpty) {
            for (final order in followUpOrders) {
              if (order.encounterId.isNotEmpty) {
                final testSummary = await _encounterService.getEncounterStatusSummary(order.encounterId);
                if (testSummary != null) {
                  activeEncounterId = order.encounterId;
                  break;
                }
              }
            }
          }
        } catch (_) {}
      }

      if ((activeEncounterId == null || activeEncounterId.isEmpty) && _patient != null) {
        try {
          final patientAppts = await _appointmentService.getAppointmentsByPatient(_patient!.id);
          if (patientAppts.isNotEmpty) {
            final latestAppt = patientAppts.first;
            // Test if appointment id maps to an encounter status
            final testSummary = await _encounterService.getEncounterStatusSummary(latestAppt.id);
            if (testSummary != null) {
              activeEncounterId = latestAppt.id;
            }
          }
        } catch (_) {}
      }

      if (activeEncounterId != null && activeEncounterId.isNotEmpty) {
        _sessionService.setActiveEncounterId(activeEncounterId);
        _encounterSummary = await _encounterService.getEncounterStatusSummary(activeEncounterId);
        _queueTicket = await _queueService.getQueueTicketByEncounter(activeEncounterId);
      } else {
        _encounterSummary = null;
        _queueTicket = null;
      }

      if (_patient != null) {
        try {
          final followUps = await _followUpService.getFollowUpOrdersByPatient(_patient!.id);
          if (followUps.isNotEmpty) {
            _latestFollowUpOrder = followUps.first;
          }
        } catch (_) {}
      }

      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Không thể đồng bộ dữ liệu: ${e.toString()}';
    } finally {
      _isLoading = false;
      _isRefreshing = false;
      notifyListeners();
    }
  }

  void setDemoPhone(String phone, {String? encounterId}) {
    _sessionService.setPhone(phone);
    if (encounterId != null && encounterId.isNotEmpty) {
      _sessionService.setActiveEncounterId(encounterId);
    }
    loadHomeData();
  }

  void switchPhone(String phone, {String? encounterId}) {
    _sessionService.setPhone(phone);
    if (encounterId != null && encounterId.isNotEmpty) {
      _sessionService.setActiveEncounterId(encounterId);
    }
    loadHomeData();
  }

  void logout() {
    _sessionService.clearSession();
    _patient = null;
    _appointmentCheck = null;
    _encounterSummary = null;
    _queueTicket = null;
    _errorMessage = null;
    _isLoading = false;
    _isRefreshing = false;
    notifyListeners();
  }

  void retry() {
    loadHomeData();
  }
}
