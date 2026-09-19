import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/appointment_model.dart';
import '../models/follow_up_order_model.dart';
import '../models/medical_record_model.dart';
import '../models/patient_model.dart';
import '../models/service_type_model.dart';
import '../services/appointment_service.dart';
import '../services/follow_up_service.dart';
import '../services/patient_service.dart';
import '../services/patient_session_service.dart';
import '../services/service_type_service.dart';

class BookingProvider extends ChangeNotifier {
  final PatientService _patientService;
  final AppointmentService _appointmentService;
  final ServiceTypeService _serviceTypeService;
  final FollowUpService _followUpService;
  final PatientSessionService _sessionService;

  BookingProvider({
    PatientService? patientService,
    AppointmentService? appointmentService,
    ServiceTypeService? serviceTypeService,
    FollowUpService? followUpService,
    PatientSessionService? sessionService,
  })  : _patientService = patientService ?? PatientService(),
        _appointmentService = appointmentService ?? AppointmentService(),
        _serviceTypeService = serviceTypeService ?? ServiceTypeService(),
        _followUpService = followUpService ?? FollowUpService(),
        _sessionService = sessionService ?? PatientSessionService();

  // State
  PatientModel? _patient;
  AppointmentModel? _existingAppointment;
  bool _hasExistingAppointment = false;

  // Follow-Up (Tái khám) State
  bool _isFollowUp = false;
  String? _followUpOrderId;
  String? _originalDoctorId;
  String? _originalDoctorName;
  String? _previousDiagnosis;
  String? _followUpAdvice;
  DateTime? _recommendedFollowUpDate;
  List<FollowUpOrderModel> _pendingFollowUpOrders = [];

  // Patient administrative input state
  String _fullName = '';
  String _phone = '';
  DateTime? _dob;
  String? _nationalId;
  String? _address;

  // Selected OB/GYN Specialty Category: 'prenatal' | 'gynecology' | 'other'
  String _selectedCategory = 'prenatal';

  // Obstetric Self-Declaration (Khám thai)
  String _pregnancyType = 'Đơn thai (1 thai nhi)';
  int? _gestationalWeeks = 28;
  int? _gestationalDays = 3;
  DateTime? _lmp; // Last Menstrual Period
  DateTime? _edd; // Expected Due Date
  int _gravida = 1;
  int _para = 0;
  int _abortion = 0;
  int _living = 0;
  String? _obstetricHistoryNotes;
  String _fetalMovementStatus = 'Thai máy tốt (>= 4 lần/giờ - Bình thường)';
  String _vatVaccine = 'Đã tiêm VAT 1 (Tuần 20-24)';
  String _prenatalVisitReason = 'Khám thai định kỳ & Siêu âm Thai 4D / Doppler Màu';
  final List<String> _selectedObstetricHistory = ['Con so (Lần đầu mang thai)'];
  final List<String> _selectedWarningSigns = [];

  // Gynecological Self-Declaration (Khám phụ khoa)
  String? _gynVisitReason;
  String _menstrualCycle = '28-30 ngày (Đều)';
  DateTime? _lastPeriodDate;
  String? _contraceptiveMethod;
  final List<String> _selectedGynSymptoms = [];
  String? _clinicalNotes;

  // Helper getter for minimum valid booking date (from tomorrow onwards)
  static DateTime get defaultBookingDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return today.add(const Duration(days: 1));
  }

  // Services & Slots
  List<ServiceTypeModel> _services = [];
  ServiceTypeModel? _selectedService;
  DateTime _selectedDate = defaultBookingDate; // Default tomorrow
  List<AppointmentSlotModel> _availableSlots = [];
  AppointmentSlotModel? _selectedSlot;

  bool _isLoading = false;
  bool _isSlotsLoading = false;
  bool _isSubmitting = false;
  bool _isServiceTypeDependencyMissing = false;

  String? _errorMessage;
  String? _slotsErrorMessage;
  AppointmentModel? _bookingSuccessResult;

  // Getters
  PatientModel? get patient => _patient;
  AppointmentModel? get existingAppointment => _existingAppointment;
  bool get hasExistingAppointment => _hasExistingAppointment;

  bool get isFollowUp => _isFollowUp;
  String? get followUpOrderId => _followUpOrderId;
  String? get originalDoctorId => _originalDoctorId;
  String? get originalDoctorName => _originalDoctorName;
  String? get previousDiagnosis => _previousDiagnosis;
  String? get followUpAdvice => _followUpAdvice;
  DateTime? get recommendedFollowUpDate => _recommendedFollowUpDate;
  List<FollowUpOrderModel> get pendingFollowUpOrders => _pendingFollowUpOrders;

  String get fullName => _fullName;
  String get phone => _phone;
  DateTime? get dob => _dob;
  String? get nationalId => _nationalId;
  String? get address => _address;

  String get selectedCategory => _selectedCategory;
  String get pregnancyType => _pregnancyType;
  int? get gestationalWeeks => _gestationalWeeks;
  int? get gestationalDays => _gestationalDays;
  DateTime? get lmp => _lmp;
  DateTime? get edd => _edd;
  int get gravida => _gravida;
  int get para => _para;
  int get abortion => _abortion;
  int get living => _living;
  String? get obstetricHistoryNotes => _obstetricHistoryNotes;
  String get fetalMovementStatus => _fetalMovementStatus;
  String get vatVaccine => _vatVaccine;
  String get prenatalVisitReason => _prenatalVisitReason;
  List<String> get selectedObstetricHistory => _selectedObstetricHistory;
  List<String> get selectedWarningSigns => _selectedWarningSigns;

  String? get gynVisitReason => _gynVisitReason;
  String get menstrualCycle => _menstrualCycle;
  DateTime? get lastPeriodDate => _lastPeriodDate;
  String? get contraceptiveMethod => _contraceptiveMethod;
  List<String> get selectedGynSymptoms => _selectedGynSymptoms;
  String? get clinicalNotes => _clinicalNotes;

  List<ServiceTypeModel> get services => _services;

  /// Filter services by selected category
  List<ServiceTypeModel> get filteredServices {
    if (_services.isEmpty) return [];
    if (_selectedCategory == 'prenatal') {
      final list = _services.where((s) => s.isPrenatal).toList();
      return list.isNotEmpty ? list : _services;
    }
    if (_selectedCategory == 'gynecology') {
      final list = _services.where((s) => s.isGynecology).toList();
      return list.isNotEmpty ? list : _services;
    }
    return _services;
  }

  ServiceTypeModel? get selectedService => _selectedService;
  DateTime get selectedDate => _selectedDate;
  List<AppointmentSlotModel> get availableSlots => _availableSlots;
  AppointmentSlotModel? get selectedSlot => _selectedSlot;

  bool get isLoading => _isLoading;
  bool get isSlotsLoading => _isSlotsLoading;
  bool get isSubmitting => _isSubmitting;
  bool get isServiceTypeDependencyMissing => _isServiceTypeDependencyMissing;

  String? get errorMessage => _errorMessage;
  String? get slotsErrorMessage => _slotsErrorMessage;
  AppointmentModel? get bookingSuccessResult => _bookingSuccessResult;

  /// Check if patient profile already contains verified baseline health data
  bool get hasProfileHealthData =>
      _patient != null &&
      ((_patient!.bloodGroup != null && _patient!.bloodGroup!.isNotEmpty) ||
          (_patient!.allergies != null && _patient!.allergies!.isNotEmpty) ||
          (_patient!.medicalHistory != null && _patient!.medicalHistory!.isNotEmpty));

  /// Can submit booking check
  bool get canSubmit =>
      ((_patient != null && _patient!.fullName.isNotEmpty && _patient!.phone.isNotEmpty) ||
          (_fullName.trim().isNotEmpty && _phone.trim().length >= 10)) &&
      _selectedService != null &&
      _selectedSlot != null &&
      _selectedSlot!.isAvailable &&
      !_isSubmitting;

  // Setters & Patient Profile Management
  void selectPatient(PatientModel p) {
    _patient = p;
    _fullName = p.fullName;
    _phone = p.phone;
    _dob = p.dob != null ? DateTime.tryParse(p.dob!) : null;
    _nationalId = p.nationalId;
    _address = p.address;
    if (p.gestationalWeeks != null) {
      _gestationalWeeks = p.gestationalWeeks;
    }
    _sessionService.setPhone(p.phone);
    _sessionService.setPatientId(p.id);

    // Also reload pending follow up orders for this patient
    _followUpService.getFollowUpOrdersByPatient(p.id).then((orders) {
      _pendingFollowUpOrders = orders;
      notifyListeners();
    }).catchError((_) {
      _pendingFollowUpOrders = [];
      notifyListeners();
    });

    notifyListeners();
  }

  void clearSelectedPatient() {
    _patient = null;
    _fullName = '';
    _phone = '';
    _dob = null;
    _nationalId = null;
    _address = null;
    _pendingFollowUpOrders = [];
    notifyListeners();
  }

  /// Create a new patient profile and immediately select it for booking
  Future<PatientModel> createAndSelectPatient({
    required String fullName,
    required String phone,
    String? dob,
    String? gender,
    String? nationalId,
    String? address,
    String? bloodGroup,
    String? rhFactor,
    num? heightCm,
    num? prePregnancyWeight,
    String? allergies,
    String? medicalHistory,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final newPatient = await _patientService.createPatient(
        fullName: fullName.trim(),
        phone: phone.trim(),
        dob: dob,
        gender: gender ?? 'Female',
        nationalId: nationalId?.trim(),
        address: address?.trim(),
        bloodGroup: bloodGroup ?? 'O',
        rhFactor: rhFactor ?? 'Rh+',
        heightCm: heightCm ?? 162,
        prePregnancyWeight: prePregnancyWeight ?? 52,
        allergies: allergies ?? 'Không ghi nhận dị ứng thuốc',
        medicalHistory: medicalHistory ?? 'Bình thường, không bệnh mạn tính',
      );

      selectPatient(newPatient);
      _isLoading = false;
      notifyListeners();
      return newPatient;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Lỗi tạo hồ sơ bệnh nhân: ${e.toString()}';
      notifyListeners();
      rethrow;
    }
  }

  /// Search patient by phone and select if found
  Future<PatientModel?> searchAndSelectPatient(String phoneToSearch) async {
    final cleanPhone = phoneToSearch.trim();
    if (cleanPhone.isEmpty) return null;

    try {
      final found = await _patientService.searchPatientByPhone(cleanPhone);
      if (found != null) {
        selectPatient(found);
      }
      return found;
    } catch (_) {
      return null;
    }
  }

  void setIsFollowUp(bool val) {
    _isFollowUp = val;
    notifyListeners();
  }

  void setFullName(String val) {
    _fullName = val;
    notifyListeners();
  }

  void setPhone(String val) {
    _phone = val.trim();
    notifyListeners();
  }

  void setDob(DateTime? val) {
    _dob = val;
    notifyListeners();
  }

  void setNationalId(String? val) {
    _nationalId = val?.trim();
    notifyListeners();
  }

  void setAddress(String? val) {
    _address = val?.trim();
    notifyListeners();
  }

  void setSelectedCategory(String category) {
    if (_selectedCategory == category) return;
    _selectedCategory = category;

    // Auto-select first matching service in the newly chosen category
    final matching = filteredServices;
    if (matching.isNotEmpty) {
      selectService(matching.first);
    }
    notifyListeners();
  }

  // Follow-up setup helper from a previous medical record
  void setupFollowUpFromRecord(MedicalRecordModel record) {
    _isFollowUp = true;
    _originalDoctorName = record.doctorName;
    _previousDiagnosis = record.diagnosis;
    _followUpAdvice = record.doctorAdvice;
    _recommendedFollowUpDate = record.followUpDate ?? DateTime.now().add(const Duration(days: 14));

    if (_recommendedFollowUpDate != null && _recommendedFollowUpDate!.isAfter(DateTime.now())) {
      _selectedDate = _recommendedFollowUpDate!;
    } else {
      _selectedDate = DateTime.now().add(const Duration(days: 1));
    }

    final lowerDept = record.departmentName.toLowerCase();
    if (lowerDept.contains('sản') || lowerDept.contains('thai')) {
      _selectedCategory = 'prenatal';
    } else if (lowerDept.contains('phụ khoa')) {
      _selectedCategory = 'gynecology';
    } else {
      _selectedCategory = 'other';
    }

    if (record.vitalSigns?.gestationalWeeks != null) {
      _gestationalWeeks = record.vitalSigns!.gestationalWeeks;
    }

    _clinicalNotes = 'Tái khám theo hẹn của ${record.doctorName} (Chẩn đoán trước: ${record.diagnosis})';

    // Refresh matching service and fetch slots
    final matching = filteredServices;
    if (matching.isNotEmpty) {
      _selectedService = matching.first;
      _fetchSlots();
    }
    notifyListeners();
  }

  // Follow-up setup helper from a follow-up order
  void setupFollowUpFromOrder(FollowUpOrderModel order) {
    _isFollowUp = true;
    _followUpOrderId = order.id;
    _originalDoctorId = order.originalDoctorId;
    _originalDoctorName = order.originalDoctorName;
    _previousDiagnosis = order.diagnosis;
    _followUpAdvice = order.notes;
    _recommendedFollowUpDate = order.targetDate;

    if (!order.targetDate.isBefore(defaultBookingDate)) {
      _selectedDate = order.targetDate;
    } else {
      _selectedDate = defaultBookingDate;
    }

    _clinicalNotes = 'Tái khám theo phiếu chỉ định #${order.id.length >= 8 ? order.id.substring(0, 8).toUpperCase() : order.id} của BS. ${order.originalDoctorName}';

    final matching = filteredServices;
    if (matching.isNotEmpty) {
      _selectedService = matching.first;
      _fetchSlots();
    }
    notifyListeners();
  }

  void clearFollowUp() {
    _isFollowUp = false;
    _followUpOrderId = null;
    _originalDoctorId = null;
    _originalDoctorName = null;
    _previousDiagnosis = null;
    _followUpAdvice = null;
    _recommendedFollowUpDate = null;
    notifyListeners();
  }

  // Obstetric setters
  void setPregnancyType(String type) {
    _pregnancyType = type;
    notifyListeners();
  }

  void setVatVaccine(String vat) {
    _vatVaccine = vat;
    notifyListeners();
  }

  void setPrenatalVisitReason(String reason) {
    _prenatalVisitReason = reason;
    notifyListeners();
  }

  void toggleObstetricHistory(String item) {
    if (_selectedObstetricHistory.contains(item)) {
      _selectedObstetricHistory.remove(item);
    } else {
      _selectedObstetricHistory.add(item);
    }
    notifyListeners();
  }

  void setGestationalWeeks(int? weeks) {
    _gestationalWeeks = weeks;
    notifyListeners();
  }

  void setGestationalDays(int? days) {
    _gestationalDays = days;
    notifyListeners();
  }

  void setLmp(DateTime? date) {
    _lmp = date;
    if (date != null) {
      // Calculate EDD automatically (Naegele's rule: +1 year, -3 months, +7 days = +280 days)
      _edd = date.add(const Duration(days: 280));
      // Calculate gestational weeks
      final diffDays = DateTime.now().difference(date).inDays;
      if (diffDays >= 0) {
        _gestationalWeeks = diffDays ~/ 7;
        _gestationalDays = diffDays % 7;
      }
    }
    notifyListeners();
  }

  void setEdd(DateTime? date) {
    _edd = date;
    notifyListeners();
  }

  void setPara({int? g, int? p, int? a, int? l}) {
    if (g != null) _gravida = g;
    if (p != null) _para = p;
    if (a != null) _abortion = a;
    if (l != null) _living = l;
    notifyListeners();
  }

  void setObstetricHistoryNotes(String? val) {
    _obstetricHistoryNotes = val;
    notifyListeners();
  }

  void setFetalMovementStatus(String status) {
    _fetalMovementStatus = status;
    notifyListeners();
  }

  void toggleWarningSign(String sign) {
    if (_selectedWarningSigns.contains(sign)) {
      _selectedWarningSigns.remove(sign);
    } else {
      _selectedWarningSigns.add(sign);
    }
    notifyListeners();
  }

  // Gynecological setters
  void setGynVisitReason(String? val) {
    _gynVisitReason = val;
    notifyListeners();
  }

  void setMenstrualCycle(String val) {
    _menstrualCycle = val;
    notifyListeners();
  }

  void setLastPeriodDate(DateTime? date) {
    _lastPeriodDate = date;
    notifyListeners();
  }

  void setContraceptiveMethod(String? val) {
    _contraceptiveMethod = val;
    notifyListeners();
  }

  void toggleGynSymptom(String symptom) {
    if (_selectedGynSymptoms.contains(symptom)) {
      _selectedGynSymptoms.remove(symptom);
    } else {
      _selectedGynSymptoms.add(symptom);
    }
    notifyListeners();
  }

  void setClinicalNotes(String? val) {
    _clinicalNotes = val;
    notifyListeners();
  }

  /// Initializes booking screen data
  Future<void> initBooking([String? defaultPhone]) async {
    _isLoading = true;
    _errorMessage = null;
    _bookingSuccessResult = null;
    notifyListeners();

    try {
      // 1. If phone passed, prefetch patient profile to populate administrative and health data
      final targetPhone = defaultPhone ?? _sessionService.currentPhone;
      if (targetPhone.isNotEmpty) {
        _phone = targetPhone;
        try {
          _patient = await _patientService.searchPatientByPhone(targetPhone);
          if (_patient != null) {
            _fullName = _patient!.fullName;
            _dob = _patient!.dob != null ? DateTime.tryParse(_patient!.dob!) : _dob;
            _nationalId = _patient!.nationalId ?? _nationalId;
            _address = _patient!.address ?? _address;
            if (_patient!.gestationalWeeks != null) {
              _gestationalWeeks = _patient!.gestationalWeeks;
            }

            // Fetch pending follow-up orders for this patient
            try {
              _pendingFollowUpOrders = await _followUpService.getFollowUpOrdersByPatient(_patient!.id);
            } catch (_) {
              _pendingFollowUpOrders = [];
            }
          } else {
            clearSelectedPatient();
          }
        } catch (_) {
          // Bỏ qua nếu chưa có quyền truy cập hoặc 401, cho phép khách vãng lai đặt lịch bình thường
          clearSelectedPatient();
        }
      } else {
        clearSelectedPatient();
      }

      // 2. Fetch live services from BE
      _services = await _serviceTypeService.getServiceTypes();
      _isServiceTypeDependencyMissing = _services.isEmpty;

      // Select first matching service by category
      final matching = filteredServices;
      if (matching.isNotEmpty && (_selectedService == null || !matching.any((s) => s.id == _selectedService?.id))) {
        _selectedService = matching.first;
      } else if (_services.isNotEmpty && _selectedService == null) {
        _selectedService = _services.first;
      }

      // 3. Ensure valid booking date (from tomorrow onwards)
      if (_selectedDate.isBefore(defaultBookingDate)) {
        _selectedDate = defaultBookingDate;
      }

      // 4. Load available slots
      if (_selectedService != null) {
        await _fetchSlots();
      }
    } catch (e) {
      _errorMessage = 'Lỗi tải danh mục dịch vụ khám: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Selects a service type
  Future<void> selectService(ServiceTypeModel service) async {
    if (_selectedService?.id == service.id) return;
    _selectedService = service;
    _selectedSlot = null;
    notifyListeners();
    await _fetchSlots();
  }

  /// Selects a booking date (phải từ ngày mai trở đi)
  Future<void> selectDate(DateTime date) async {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    if (normalizedDate.isBefore(defaultBookingDate)) {
      // Không cho phép đặt lịch cho ngày hôm nay hoặc trong quá khứ
      return;
    }

    if (_selectedDate.year == normalizedDate.year &&
        _selectedDate.month == normalizedDate.month &&
        _selectedDate.day == normalizedDate.day) {
      return;
    }

    _selectedDate = normalizedDate;
    _selectedSlot = null;
    notifyListeners();
    await _fetchSlots();
  }

  /// Selects a time slot
  void selectSlot(AppointmentSlotModel slot) {
    if (!slot.isAvailable) return;
    _selectedSlot = slot;
    notifyListeners();
  }

  /// Internal slot fetch
  Future<void> _fetchSlots() async {
    if (_selectedService == null) {
      _availableSlots = [];
      return;
    }

    _isSlotsLoading = true;
    _slotsErrorMessage = null;
    notifyListeners();

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      _availableSlots = await _appointmentService.getAvailableSlots(
        serviceTypeId: _selectedService!.id,
        date: dateStr,
      );
    } catch (e) {
      _slotsErrorMessage = 'Không thể tải khung giờ khám: ${e.toString()}';
      _availableSlots = [];
    } finally {
      _isSlotsLoading = false;
      notifyListeners();
    }
  }

  /// Retries loading available slots
  Future<void> retrySlots() async {
    await _fetchSlots();
  }

  /// Submits appointment creation to backend
  Future<bool> submitBooking() async {
    if (!canSubmit) return false;

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Find or create patient with entered phone & full name
      PatientModel? currentPatient = _patient;
      if (currentPatient == null || currentPatient.phone.trim() != _phone.trim()) {
        try {
          currentPatient = await _patientService.searchPatientByPhone(_phone.trim());
        } catch (_) {
          currentPatient = null;
        }
      }

      if (currentPatient == null) {
        currentPatient = await _patientService.createPatient(
          fullName: _fullName.trim(),
          phone: _phone.trim(),
          gender: 'Female',
          dob: _dob != null ? DateFormat('yyyy-MM-dd').format(_dob!) : null,
          nationalId: _nationalId,
          address: _address,
        );
      } else if (_fullName.trim().isNotEmpty && currentPatient.fullName != _fullName.trim()) {
        try {
          currentPatient = await _patientService.updatePatient(
            id: currentPatient.id,
            fullName: _fullName.trim(),
            phone: _phone.trim(),
            gender: 'Female',
            dob: _dob != null ? DateFormat('yyyy-MM-dd').format(_dob!) : null,
            address: _address ?? currentPatient.address,
          );
        } catch (_) {}
      }

      if (currentPatient == null) {
        throw Exception('Không thể khởi tạo thông tin người bệnh.');
      }

      _patient = currentPatient.copyWith(
        gestationalWeeks: _gestationalWeeks ?? currentPatient.gestationalWeeks,
        para: 'G$_gravida P$_para A$_abortion L$_living',
        lmp: _lmp != null ? DateFormat('yyyy-MM-dd').format(_lmp!) : currentPatient.lmp,
        edd: _edd != null ? DateFormat('yyyy-MM-dd').format(_edd!) : currentPatient.edd,
      );

      _sessionService.setPhone(_phone.trim());
      _sessionService.setPatientId(currentPatient.id);

      // 2. Create Appointment in Backend
      final result = await _appointmentService.createAppointment(
        patientId: currentPatient.id,
        serviceTypeId: _selectedService!.id,
        scheduledTime: _selectedSlot!.startTime,
        status: 1, // Confirmed
        source: 0, // Online
        followUpOrderId: _followUpOrderId,
        doctorId: _originalDoctorId,
      );

      _bookingSuccessResult = result;
      _existingAppointment = result;
      _hasExistingAppointment = true;
      _isSubmitting = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Đặt lịch không thành công: ${e.toString()}';
      _isSubmitting = false;
      notifyListeners();
      return false;
    }
  }

  /// Resets booking state for a fresh booking session
  void resetBooking() {
    _bookingSuccessResult = null;
    _selectedDate = defaultBookingDate;
    _selectedSlot = null;
    _hasExistingAppointment = false;
    _existingAppointment = null;
    _isFollowUp = false;
    _followUpOrderId = null;
    _originalDoctorId = null;
    _originalDoctorName = null;
    _previousDiagnosis = null;
    _followUpAdvice = null;
    _recommendedFollowUpDate = null;
    _patient = null;
    _pendingFollowUpOrders = [];
    _fullName = '';
    _phone = '';
    _dob = null;
    _nationalId = null;
    _address = null;
    _gestationalWeeks = null;
    _gestationalDays = null;
    _lmp = null;
    _edd = null;
    _selectedWarningSigns.clear();
    _selectedGynSymptoms.clear();
    _gynVisitReason = null;
    _clinicalNotes = null;
    notifyListeners();
  }

  /// Clears patient session and resets all booking form states on logout
  void logout() {
    clearSelectedPatient();
    resetBooking();
  }
}

