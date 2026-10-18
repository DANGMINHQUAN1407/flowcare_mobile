import 'package:flutter/foundation.dart';

import '../core/network/api_exceptions.dart';
import '../models/patient_model.dart';
import '../services/patient_service.dart';
import '../services/patient_session_service.dart';

class ProfileProvider extends ChangeNotifier {
  final PatientService _patientService;
  final PatientSessionService _sessionService;
  ProfileProvider({
    PatientService? patientService,
    PatientSessionService? sessionService,
  }) : _patientService = patientService ?? PatientService(),
       _sessionService = sessionService ?? PatientSessionService();
  bool _isLoading = false, _isRefreshing = false, _disposed = false;
  int _version = 0;
  String? _errorMessage;
  PatientModel? _patient;
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  String? get errorMessage => _errorMessage;
  PatientModel? get patient => _patient;
  String get currentPhone => _sessionService.currentPhone;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> loadProfile(String? phone, {bool isRefresh = false}) async {
    final version = ++_version, sessionVersion = _sessionService.version;
    _isLoading = !isRefresh;
    _isRefreshing = isRefresh;
    _errorMessage = null;
    _notify();
    try {
      final patient = await _patientService.getMyProfile();
      if (_disposed ||
          version != _version ||
          sessionVersion != _sessionService.version) {
        return;
      }
      _patient = patient;
      if (patient != null) _sessionService.setPhone(patient.phone);
    } catch (error) {
      if (_disposed ||
          version != _version ||
          sessionVersion != _sessionService.version) {
        return;
      }
      _errorMessage = patientErrorMessage(error);
    } finally {
      if (!_disposed &&
          version == _version &&
          sessionVersion == _sessionService.version) {
        _isLoading = false;
        _isRefreshing = false;
        _notify();
      }
    }
  }

  void retry() => loadProfile(null);
  void logout() {
    _version++;
    _patient = null;
    _errorMessage = null;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _version++;
    super.dispose();
  }
}
