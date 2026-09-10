import 'package:flutter/foundation.dart';
import '../models/appointment_model.dart';
import '../models/encounter_summary_model.dart';
import '../models/patient_model.dart';
import '../models/queue_ticket_model.dart';
import '../services/appointment_service.dart';
import '../services/encounter_service.dart';
import '../services/patient_service.dart';
import '../services/patient_session_service.dart';
import '../services/queue_service.dart';

class HomeProvider extends ChangeNotifier {
  final PatientService _patientService;
  final AppointmentService _appointmentService;
  final EncounterService _encounterService;
  final QueueService _queueService;
  final PatientSessionService _sessionService;

  HomeProvider({
    PatientService? patientService,
    AppointmentService? appointmentService,
    EncounterService? encounterService,
    QueueService? queueService,
    PatientSessionService? sessionService,
  })  : _patientService = patientService ?? PatientService(),
        _appointmentService = appointmentService ?? AppointmentService(),
        _encounterService = encounterService ?? EncounterService(),
        _queueService = queueService ?? QueueService(),
        _sessionService = sessionService ?? PatientSessionService() {
    loadHomeData();
  }

  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;

  PatientModel? _patient;
  AppointmentCheckModel? _appointmentCheck;
  EncounterSummaryModel? _encounterSummary;
  QueueTicketModel? _queueTicket;

  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  String? get errorMessage => _errorMessage;

  PatientModel? get patient => _patient;
  AppointmentCheckModel? get appointmentCheck => _appointmentCheck;
  EncounterSummaryModel? get encounterSummary => _encounterSummary;
  QueueTicketModel? get queueTicket => _queueTicket;
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

      // 2. If encounterId exists in session or linked from appointment check, fetch live encounter summary
      final activeEncounterId = _appointmentCheck?.activeEncounterId ?? _sessionService.activeEncounterId;
      if (activeEncounterId != null && activeEncounterId.isNotEmpty) {
        _sessionService.setActiveEncounterId(activeEncounterId);
        _encounterSummary = await _encounterService.getEncounterStatusSummary(activeEncounterId);
        _queueTicket = await _queueService.getQueueTicketByEncounter(activeEncounterId);
      } else {
        _encounterSummary = null;
        _queueTicket = null;
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

  void setDemoPhone(String phone) {
    _sessionService.setPhone(phone);
    loadHomeData();
  }

  void switchPhone(String phone) {
    _sessionService.setPhone(phone);
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
