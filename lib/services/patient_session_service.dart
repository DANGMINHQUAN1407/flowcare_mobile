/// Patient identity is bound only after /auth/me has been validated.
class PatientSessionService {
  static final PatientSessionService _instance =
      PatientSessionService._internal();
  factory PatientSessionService() => _instance;
  PatientSessionService._internal();
  String _currentPhone = '', _userName = '';
  String? _patientId, _activeEncounterId;
  int _version = 0;
  bool _isDemo = false;
  bool get isDemo => _isDemo;
  String get currentPhone => _currentPhone;
  String get userName => _userName;
  String? get patientId => _patientId;
  String? get activeEncounterId => _activeEncounterId;
  int get version => _version;
  bool get isAuthenticated => _patientId?.isNotEmpty == true;

  void bindPatient({
    required String patientId,
    required String userName,
    bool isDemo = false,
  }) {
    clearSession();
    _patientId = patientId;
    _userName = userName;
    _isDemo = isDemo;
  }

  void setPhone(String phone) => _currentPhone = phone.trim();
  void setPatientId(String? id) {
    if (id != _patientId) {
      throw StateError('Không thể đổi hồ sơ trong phiên Patient.');
    }
  }

  void setActiveEncounterId(String? id) => _activeEncounterId = id;
  void clearSession() {
    _version++;
    _currentPhone = '';
    _userName = '';
    _patientId = null;
    _activeEncounterId = null;
    _isDemo = false;
  }
}
