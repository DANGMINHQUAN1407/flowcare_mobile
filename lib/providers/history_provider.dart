import 'package:flutter/foundation.dart';

import '../core/network/api_exceptions.dart';
import '../services/patient_session_service.dart';
import '../models/appointment_model.dart';
import '../models/medical_record_model.dart';
import '../services/appointment_service.dart';

class HistoryProvider extends ChangeNotifier {
  final AppointmentService _appointmentService;

  HistoryProvider({AppointmentService? appointmentService})
    : _appointmentService = appointmentService ?? AppointmentService();

  bool _disposed = false;
  int _version = 0;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _version++;
    super.dispose();
  }

  bool _isLoading = false;
  bool _isRefreshing = false;
  String? _errorMessage;
  int _selectedTabIndex = 0; // 0: Lịch hẹn, 1: Bệnh án & Đơn thuốc
  List<AppointmentModel> _appointments = [];
  List<MedicalRecordModel> _medicalRecords = [];

  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  String? get errorMessage => _errorMessage;
  int get selectedTabIndex => _selectedTabIndex;
  List<AppointmentModel> get appointments => _appointments;
  List<MedicalRecordModel> get medicalRecords => _medicalRecords;
  bool get isEmpty =>
      !_isLoading &&
      (_selectedTabIndex == 0
          ? _appointments.isEmpty
          : _medicalRecords.isEmpty);

  void setTab(int index) {
    if (_selectedTabIndex != index) {
      _selectedTabIndex = index;
      _notify();
    }
  }

  Future<void> loadAppointments(
    String? patientId, {
    bool isRefresh = false,
    String? phone,
    String? patientName,
  }) async {
    final version = ++_version,
        sessionVersion = PatientSessionService().version;
    final boundId = PatientSessionService().patientId;
    if (boundId != null && patientId != boundId) patientId = boundId;
    if (patientId == null || patientId.isEmpty) {
      _appointments = [];
      _medicalRecords = [];
      _isLoading = false;
      _isRefreshing = false;
      _errorMessage = null;
      _notify();
      return;
    }

    if (isRefresh) {
      _isRefreshing = true;
      _notify();
    } else {
      _isLoading = true;
      _errorMessage = null;
      _notify();
    }

    try {
      final list = await _appointmentService.getAppointmentsByPatient(
        patientId,
      );
      if (_disposed ||
          version != _version ||
          sessionVersion != PatientSessionService().version) {
        return;
      }
      // Sort by scheduledTime descending
      list.sort((a, b) => b.scheduledTime.compareTo(a.scheduledTime));
      _appointments = list;

      // Clinical records must come from an authorized clinical endpoint.
      // Do not present generated diagnoses or prescriptions as this patient's data.
      _medicalRecords = [];

      _errorMessage = null;
    } catch (e) {
      if (_disposed ||
          version != _version ||
          sessionVersion != PatientSessionService().version) {
        return;
      }
      _errorMessage = patientErrorMessage(e);
    } finally {
      if (!_disposed &&
          version == _version &&
          sessionVersion == PatientSessionService().version) {
        _isLoading = false;
        _isRefreshing = false;
        _notify();
      }
    }
  }

  void retry(String? patientId, {String? phone, String? patientName}) {
    loadAppointments(patientId, phone: phone, patientName: patientName);
  }

  void logout() {
    _version++;
    _appointments = [];
    _medicalRecords = [];
    _isLoading = false;
    _isRefreshing = false;
    _errorMessage = null;
    _notify();
  }
}
