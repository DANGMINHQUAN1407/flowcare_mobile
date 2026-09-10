import 'package:flutter/foundation.dart';
import '../models/appointment_model.dart';
import '../models/medical_record_model.dart';
import '../services/appointment_service.dart';

class HistoryProvider extends ChangeNotifier {
  final AppointmentService _appointmentService;

  HistoryProvider({AppointmentService? appointmentService})
      : _appointmentService = appointmentService ?? AppointmentService();

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
      (_selectedTabIndex == 0 ? _appointments.isEmpty : _medicalRecords.isEmpty);

  void setTab(int index) {
    if (_selectedTabIndex != index) {
      _selectedTabIndex = index;
      notifyListeners();
    }
  }

  Future<void> loadAppointments(String? patientId, {bool isRefresh = false, String? phone, String? patientName}) async {
    if (patientId == null || patientId.isEmpty) {
      _appointments = [];
      _medicalRecords = [];
      _isLoading = false;
      _isRefreshing = false;
      _errorMessage = null;
      notifyListeners();
      return;
    }

    if (isRefresh) {
      _isRefreshing = true;
      notifyListeners();
    } else {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final list = await _appointmentService.getAppointmentsByPatient(patientId);
      // Sort by scheduledTime descending
      list.sort((a, b) => b.scheduledTime.compareTo(a.scheduledTime));
      _appointments = list;

      // Populate clinical medical records
      _medicalRecords = [
        MedicalRecordModel.createDemoRecord(
          patientName: patientName ?? 'Bệnh nhân',
          phone: phone ?? '0988999888',
        ),
      ];

      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Không thể tải lịch sử lịch hẹn: ${e.toString()}';
    } finally {
      _isLoading = false;
      _isRefreshing = false;
      notifyListeners();
    }
  }

  void retry(String? patientId, {String? phone, String? patientName}) {
    loadAppointments(patientId, phone: phone, patientName: patientName);
  }
}
