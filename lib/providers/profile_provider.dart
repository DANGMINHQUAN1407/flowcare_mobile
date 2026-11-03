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
  bool _isSaving = false, _identityLocked = false;
  bool get isSaving => _isSaving;
  bool get identityLocked => _identityLocked;
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

  Future<bool> saveProfile({
    String? fullName,
    String? dob,
    String? gender,
    String? address,
  }) async {
    if (_isSaving) return false;
    final sessionVersion = _sessionService.version;
    _isSaving = true;
    _errorMessage = null;
    _notify();
    try {
      final saved = await _patientService.updatePatient(
        fullName: fullName,
        dob: dob,
        gender: gender,
        address: address,
      );
      if (_disposed || sessionVersion != _sessionService.version) return false;
      _version++;
      _isLoading = false;
      _isRefreshing = false;
      _patient = saved;
      return true;
    } catch (error) {
      if (!_disposed && sessionVersion == _sessionService.version) {
        if (error is ApiException &&
            error.codes.contains('PATIENT_IDENTITY_LOCKED')) {
          _identityLocked = true;
          _errorMessage = 'Họ tên, ngày sinh, giới tính đã được xác nhận tại quầy tiếp đón. Liên hệ quầy để thay đổi. Bạn vẫn có thể sửa địa chỉ.';
        } else {
          _errorMessage = patientErrorMessage(
            error,
            fallback: 'Không xác nhận được lưu hồ sơ. Vui lòng tải lại trước khi thử lại.',
          );
        }
      }
      return false;
    } finally {
      if (!_disposed && sessionVersion == _sessionService.version) {
        _isSaving = false;
        _notify();
      }
    }
  }

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
