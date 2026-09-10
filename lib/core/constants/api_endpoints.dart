class ApiEndpoints {
  // Base URLs
  // Android Emulator: 10.0.2.2
  // Real Device (Same WiFi): replace with computer IP, e.g. 192.168.1.x
  static const String defaultBaseUrl = 'http://10.0.2.2:5062/api/v1';

  // Appointments
  static const String appointmentSlots = '/appointments/slots';
  static const String appointmentCheck = '/appointments/check';
  static const String appointments = '/appointments';
  static String appointmentByPatient(String patientId) => '/appointments/patient/$patientId';

  // Service Types (Backend Dependency: pending GET /api/v1/service-types)
  static const String serviceTypes = '/service-types';

  // Patients
  static const String patientSearch = '/patients/search';
  static const String patients = '/patients';

  // Encounters & Live Status
  static const String encounters = '/encounters';
  static String encounterStatus(String id) => '/encounters/$id/status';
  static String encounterCheckIn(String id) => '/encounters/$id/checkin';

  // Queue Tickets
  static const String queueTickets = '/queue-tickets';
  static String queueTicketByEncounter(String encounterId) => '/queue-tickets/by-encounter/$encounterId';

  // Departments
  static const String departments = '/departments';
  static String departmentStatus(String id) => '/departments/$id/status';

  // Pre-exam Orders
  static String preExamOrdersByEncounter(String encounterId) => '/encounters/$encounterId/pre-exam-orders';

  // Routing Recommendations
  static const String routingRecommendations = '/routing-recommendations';
  static String routingByEncounter(String encounterId) => '/routing-recommendations/by-encounter/$encounterId';

  // Notifications
  static const String notifications = '/notifications';
}
