class PatientSessionService {
  static const String defaultDemoPhone = '0938668899';

  String _currentPhone = defaultDemoPhone;
  String? _patientId;
  String? _activeEncounterId;

  // Singleton instance
  static final PatientSessionService _instance = PatientSessionService._internal();
  factory PatientSessionService() => _instance;
  PatientSessionService._internal();

  String get currentPhone => _currentPhone;
  String? get patientId => _patientId;
  String? get activeEncounterId => _activeEncounterId;

  void setPhone(String phone) {
    _currentPhone = phone.trim();
  }

  void setPatientId(String? id) {
    _patientId = id;
  }

  void setActiveEncounterId(String? encounterId) {
    _activeEncounterId = encounterId;
  }

  void clearSession() {
    _currentPhone = '';
    _patientId = null;
    _activeEncounterId = null;
  }
}
