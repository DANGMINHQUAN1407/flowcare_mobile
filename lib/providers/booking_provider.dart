import 'package:flutter/foundation.dart';

import '../core/network/api_exceptions.dart';

import 'package:intl/intl.dart';

import '../models/appointment_model.dart';
import '../models/follow_up_order_model.dart';
import '../models/patient_model.dart';
import '../models/service_type_model.dart';
import '../services/appointment_service.dart';
import '../services/encounter_service.dart';
import '../services/follow_up_service.dart';
import '../services/patient_service.dart';
import '../services/patient_session_service.dart';
import '../services/service_type_service.dart';

class BookingProvider extends ChangeNotifier {
  final PatientService _patientService;
  final AppointmentService _appointmentService;
  final ServiceTypeService _serviceTypeService;
  final FollowUpService _followUpService;
  final EncounterService _encounterService;
  final PatientSessionService _sessionService;

  BookingProvider({
    PatientService? patientService,
    AppointmentService? appointmentService,
    ServiceTypeService? serviceTypeService,
    FollowUpService? followUpService,
    EncounterService? encounterService,
    PatientSessionService? sessionService,
  }) : _patientService = patientService ?? PatientService(),
       _appointmentService = appointmentService ?? AppointmentService(),
       _serviceTypeService = serviceTypeService ?? ServiceTypeService(),
       _followUpService = followUpService ?? FollowUpService(),
       _encounterService = encounterService ?? EncounterService(),
       _sessionService = sessionService ?? PatientSessionService() {
    _boundSessionVersion = _sessionService.version;
  }

  late final int _boundSessionVersion;
  bool _disposed = false;
  int _slotsVersion = 0;
  int _followUpVersion = 0;
  String? _followUpError;
  String? get followUpError => _followUpError;
  bool get _isCurrent =>
      !_disposed && _sessionService.version == _boundSessionVersion;
  void _notify() {
    if (_isCurrent) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  // State
  PatientModel? _patient;
  AppointmentModel? _existingAppointment;
  bool _hasExistingAppointment = false;

  // Follow-Up (Tái khám) State
  String? _followUpOrderId;
  String? _originalDoctorId;
  String? _originalDoctorName;
  String? _previousDiagnosis;
  String? _followUpAdvice;
  DateTime? _recommendedFollowUpDate;
  String? _recommendedFollowUpTime;
  bool _lastSubmittedWasFollowUp = false;
  List<FollowUpOrderModel> _pendingFollowUpOrders = [];

  // Patient administrative input state
  String _fullName = '';
  String _phone = '';
  DateTime? _dob;
  String? _nationalId;
  String? _address;

  // Selected OB/GYN Specialty Category: 'prenatal' | 'gynecology'
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
  String _prenatalVisitReason =
      'Khám thai định kỳ & Siêu âm Thai 4D / Doppler Màu';
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
  List<ServiceTypeModel> _serviceCatalog = [];
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

  bool get isFollowUp => _followUpOrderId != null;
  String? get followUpOrderId => _followUpOrderId;
  FollowUpOrderModel? get activeFollowUpOrder => _pendingFollowUpOrders
      .where((order) => order.id == _followUpOrderId)
      .firstOrNull;
  String? get originalDoctorId => _originalDoctorId;
  String? get originalDoctorName => _originalDoctorName;
  String? get previousDiagnosis => _previousDiagnosis;
  String? get followUpAdvice => _followUpAdvice;
  DateTime? get recommendedFollowUpDate => _recommendedFollowUpDate;
  String? get recommendedFollowUpTime =>
      activeFollowUpOrder?.targetTime ?? _recommendedFollowUpTime;
  bool get lastSubmittedWasFollowUp => _lastSubmittedWasFollowUp;
  DateTime? get followUpScheduledTime =>
      _selectedSlot?.startTime ?? activeFollowUpOrder?.scheduledHospitalUtcTime();
  bool get isFollowUpScheduledTimeInPast {
    if (!isFollowUp) return false;
    if (_selectedSlot != null && _selectedSlot!.isAvailable) return false;
    final scheduled = activeFollowUpOrder?.scheduledHospitalUtcTime();
    if (scheduled == null) return false;
    return scheduled.isBefore(
      DateTime.now().toUtc().subtract(const Duration(minutes: 4)),
    );
  }
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
  List<ServiceTypeModel> get serviceCatalog => _serviceCatalog;

  /// Filter services by selected category
  List<ServiceTypeModel> get filteredServices {
    if (_services.isEmpty) return [];
    if (_selectedCategory == 'prenatal') {
      final list = _services.where((s) => s.isPrenatal).toList();
      return list.isNotEmpty ? list : _services;
    }
    final list = _services.where((s) => s.isGynecology).toList();
    return list.isNotEmpty ? list : _services;
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
      _isCurrent &&
      _patient != null &&
      _patient!.id == _sessionService.patientId &&
      ((_patient!.bloodGroup != null && _patient!.bloodGroup!.isNotEmpty) ||
          (_patient!.allergies != null && _patient!.allergies!.isNotEmpty) ||
          (_patient!.medicalHistory != null &&
              _patient!.medicalHistory!.isNotEmpty));

  /// Can submit booking check - bắt buộc phải đã lưu/chọn hồ sơ bệnh nhân
  bool get canSubmit =>
      !_sessionService.isDemo &&
      _isCurrent &&
      _patient != null &&
      _patient!.id == _sessionService.patientId &&
      _patient!.fullName.trim().isNotEmpty &&
      _patient!.phone.trim().isNotEmpty &&
      !_isLoading &&
      _selectedService != null &&
      (isFollowUp
          ? (_pendingFollowUpOrders.any(
                  (order) => order.id == _followUpOrderId,
                ) &&
                (_selectedSlot?.isAvailable == true ||
                    (followUpScheduledTime != null &&
                        !isFollowUpScheduledTimeInPast)))
          : (_selectedSlot != null && _selectedSlot!.isAvailable)) &&
      !_isSubmitting;

  // Setters & Patient Profile Management
  void selectPatient(PatientModel p) {
    if (!_isCurrent || p.id != _sessionService.patientId) {
      throw ForbiddenException();
    }
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

    _notify();
  }

  Future<void> _loadFollowUpOrders(String patientId) async {
    final version = ++_followUpVersion;
    bool isLatest() => _isCurrent && version == _followUpVersion;
    _followUpError = null;
    try {
      final orders = await _followUpService.getFollowUpOrdersByPatient(
        patientId,
      );
      if (!isLatest()) return;
      final visits = orders.isEmpty
          ? null
          : await _encounterService.getPatientHistory(patientId);
      if (!isLatest()) return;
      final completedEncounters =
          visits
              ?.where((visit) => visit.isFinalized)
              .map((visit) => visit.encounterId)
              .toSet() ??
          <String>{};
      _pendingFollowUpOrders = orders
          .where((order) => order.canBookFor(patientId, completedEncounters))
          .toList(growable: false);
    } catch (error) {
      if (!isLatest()) return;
      _followUpError = patientErrorMessage(error);
      _pendingFollowUpOrders = [];
    }
    if (isFollowUp &&
        !_pendingFollowUpOrders.any((order) => order.id == _followUpOrderId)) {
      _clearFollowUpSelection();
    }
    _notify();
  }

  Future<bool> openFollowUp(String orderId) async {
    final patientId = _sessionService.patientId;
    if (!_isCurrent || patientId == null || _sessionService.isDemo) {
      return false;
    }
    if (_patient == null || _patient!.id != patientId) {
      final profile = await _patientService.getMyProfile();
      if (!_isCurrent) return false;
      if (profile != null) {
        selectPatient(profile);
      }
    }
    if (_serviceCatalog.isEmpty || _services.isEmpty) {
      await _loadServicesCatalog();
      if (!_isCurrent) return false;
    }
    await _loadFollowUpOrders(patientId);
    return setupFollowUpFromOrder(orderId);
  }

  void clearSelectedPatient() {
    _patient = null;
    _fullName = '';
    _phone = '';
    _dob = null;
    _nationalId = null;
    _address = null;
    _followUpVersion++;
    _pendingFollowUpOrders = [];
    _clearFollowUpSelection();
    _notify();
  }

  void setFullName(String val) {
    _fullName = val;
    _notify();
  }

  void setPhone(String val) {
    _phone = val.trim();
    _notify();
  }

  void setDob(DateTime? val) {
    _dob = val;
    _notify();
  }

  void setNationalId(String? val) {
    _nationalId = val?.trim();
    _notify();
  }

  void setAddress(String? val) {
    _address = val?.trim();
    _notify();
  }

  void setSelectedCategory(String category) {
    final normalized = category == 'gynecology' ? 'gynecology' : 'prenatal';
    if (_selectedCategory == normalized) return;
    _selectedCategory = normalized;

    // Auto-select first matching service in the newly chosen category
    final matching = filteredServices;
    if (matching.isNotEmpty) {
      selectService(matching.first);
    }
    _notify();
  }

  bool setupFollowUpFromOrder(String orderId) {
    if (!_isCurrent || _sessionService.isDemo) return false;
    final order = _pendingFollowUpOrders
        .where((item) => item.id == orderId)
        .firstOrNull;
    if (order == null) return false;
    if (_followUpOrderId == order.id) return true;

    _followUpOrderId = order.id;
    _originalDoctorId = order.originalDoctorId;
    _originalDoctorName = order.originalDoctorName;
    _previousDiagnosis = order.diagnosis;
    _followUpAdvice = order.notes;
    _recommendedFollowUpDate = order.targetDate;
    _recommendedFollowUpTime = order.targetTime;
    final target = order.targetDate;
    final targetDay = DateTime(target.year, target.month, target.day);
    _selectedDate = targetDay.isBefore(defaultBookingDate)
        ? defaultBookingDate
        : targetDay;
    _clinicalNotes = null;
    _selectedSlot = null;
    _errorMessage = null;
    _bookingSuccessResult = null;
    _lastSubmittedWasFollowUp = false;

    final matching = filteredServices;
    if (!matching.any((s) => s.id == _selectedService?.id)) {
      _selectedService = matching.firstOrNull;
    }
    if (isFollowUpScheduledTimeInPast) {
      _fetchSlots();
    } else {
      _notify();
    }
    return true;
  }

  Future<String?> loadFollowUpVisitAdvice(String orderId) async {
    bool isSelected() =>
        _isCurrent &&
        _sessionService.isAuthenticated &&
        !_sessionService.isDemo &&
        _followUpOrderId == orderId;
    if (!isSelected()) throw SessionChangedException();
    final order = _pendingFollowUpOrders
        .where((order) => order.id == orderId)
        .firstOrNull;
    if (order == null || order.patientId != _sessionService.patientId) {
      throw SessionChangedException();
    }
    final summary = await _encounterService.getVisitSummary(order.encounterId);
    if (!isSelected()) throw SessionChangedException();
    return summary.plan?.trim();
  }

  void _clearFollowUpSelection() {
    _followUpOrderId = null;
    _originalDoctorId = null;
    _originalDoctorName = null;
    _previousDiagnosis = null;
    _followUpAdvice = null;
    _recommendedFollowUpDate = null;
    _recommendedFollowUpTime = null;
    _clinicalNotes = null;
    _selectedDate = defaultBookingDate;
    _selectedSlot = null;
    _availableSlots = [];
    _slotsErrorMessage = null;
    _isSlotsLoading = false;
    _slotsVersion++;
  }

  void clearFollowUp() {
    if (!isFollowUp && !_lastSubmittedWasFollowUp) return;
    _lastSubmittedWasFollowUp = false;
    _clearFollowUpSelection();
    _fetchSlots();
  }

  // Obstetric setters
  void setPregnancyType(String type) {
    _pregnancyType = type;
    _notify();
  }

  void setVatVaccine(String vat) {
    _vatVaccine = vat;
    _notify();
  }

  void setPrenatalVisitReason(String reason) {
    _prenatalVisitReason = reason;
    _notify();
  }

  void toggleObstetricHistory(String item) {
    if (_selectedObstetricHistory.contains(item)) {
      _selectedObstetricHistory.remove(item);
    } else {
      _selectedObstetricHistory.add(item);
    }
    _notify();
  }

  void setGestationalWeeks(int? weeks) {
    _gestationalWeeks = weeks;
    _notify();
  }

  void setGestationalDays(int? days) {
    _gestationalDays = days;
    _notify();
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
    _notify();
  }

  void setEdd(DateTime? date) {
    _edd = date;
    _notify();
  }

  void setPara({int? g, int? p, int? a, int? l}) {
    if (g != null) _gravida = g;
    if (p != null) _para = p;
    if (a != null) _abortion = a;
    if (l != null) _living = l;
    _notify();
  }

  void setObstetricHistoryNotes(String? val) {
    _obstetricHistoryNotes = val;
    _notify();
  }

  void setFetalMovementStatus(String status) {
    _fetalMovementStatus = status;
    _notify();
  }

  void toggleWarningSign(String sign) {
    if (_selectedWarningSigns.contains(sign)) {
      _selectedWarningSigns.remove(sign);
    } else {
      _selectedWarningSigns.add(sign);
    }
    _notify();
  }

  // Gynecological setters
  void setGynVisitReason(String? val) {
    _gynVisitReason = val;
    _notify();
  }

  void setMenstrualCycle(String val) {
    _menstrualCycle = val;
    _notify();
  }

  void setLastPeriodDate(DateTime? date) {
    _lastPeriodDate = date;
    _notify();
  }

  void setContraceptiveMethod(String? val) {
    _contraceptiveMethod = val;
    _notify();
  }

  void toggleGynSymptom(String symptom) {
    if (_selectedGynSymptoms.contains(symptom)) {
      _selectedGynSymptoms.remove(symptom);
    } else {
      _selectedGynSymptoms.add(symptom);
    }
    _notify();
  }

  void setClinicalNotes(String? val) {
    _clinicalNotes = val;
    _notify();
  }

  Future<void> _loadServicesCatalog() async {
    final services = await _serviceTypeService.getServiceTypes();
    if (!_isCurrent) return;
    _serviceCatalog = services;
    _services = services
        .where(
          (service) =>
              service.id.trim().isNotEmpty &&
              service.id != '00000000-0000-0000-0000-000000000000' &&
              (service.serviceType == null ||
                  service.serviceType?.toLowerCase() == 'consultation' ||
                  service.serviceType == '4'),
        )
        .toList();
    _isServiceTypeDependencyMissing = _services.isEmpty;

    final matching = filteredServices;
    if (!matching.any((s) => s.id == _selectedService?.id)) {
      _selectedService = matching.firstOrNull;
    }
  }

  /// Initializes booking screen data
  Future<void> initBooking([String? defaultPhone]) async {
    if (_isLoading) return;
    _isLoading = true;
    _errorMessage = null;
    _bookingSuccessResult = null;
    _lastSubmittedWasFollowUp = false;
    _notify();

    try {
      if (!_isCurrent || !_sessionService.isAuthenticated) {
        throw UnauthorizedException();
      }
      final profile = await _patientService.getMyProfile();
      if (!_isCurrent) return;
      if (profile == null) {
        throw ApiException('Chưa tải được hồ sơ để đặt lịch.');
      }
      selectPatient(profile);
      await _loadFollowUpOrders(profile.id);
      if (!_isCurrent) return;

      // 2. Fetch live services from BE
      await _loadServicesCatalog();
      if (!_isCurrent) return;

      // 3. Ensure valid booking date (from tomorrow onwards)
      if (_selectedDate.isBefore(defaultBookingDate)) {
        _selectedDate = defaultBookingDate;
      }

      // 4. Load available slots
      await _fetchSlots();
    } catch (e) {
      _errorMessage = patientErrorMessage(e);
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  /// Selects a service type
  Future<void> selectService(ServiceTypeModel service) async {
    if (_selectedService?.id == service.id ||
        !_services.any((item) => item.id == service.id)) {
      return;
    }
    _selectedService = service;
    _selectedSlot = null;
    _notify();
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
    _notify();
    await _fetchSlots();
  }

  /// Selects a time slot
  void selectSlot(AppointmentSlotModel slot) {
    if (!slot.isAvailable || !_availableSlots.contains(slot)) return;
    _selectedSlot = slot;
    _notify();
  }

  /// Internal slot fetch
  Future<void> _fetchSlots() async {
    final version = ++_slotsVersion;
    final service = _selectedService;
    _availableSlots = [];
    _selectedSlot = null;
    _slotsErrorMessage = null;
    if (service == null) {
      _isSlotsLoading = false;
      _notify();
      return;
    }

    _isSlotsLoading = true;
    _notify();

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final slots = await _appointmentService.getAvailableSlots(
        serviceTypeId: service.id,
        date: dateStr,
      );
      if (!_isCurrent || version != _slotsVersion) return;
      _availableSlots = slots;
    } catch (e) {
      if (!_isCurrent || version != _slotsVersion) return;
      _slotsErrorMessage = patientErrorMessage(
        e,
        fallback: 'Không thể tải khung giờ khám. Vui lòng thử lại.',
      );
      _availableSlots = [];
    } finally {
      if (_isCurrent && version == _slotsVersion) {
        _isSlotsLoading = false;
        _notify();
      }
    }
  }

  /// Retries loading available slots
  Future<void> retrySlots() async {
    await _fetchSlots();
  }

  /// Submits appointment creation to backend
  Future<bool> submitBooking() async {
    if (!canSubmit) return false;
    final orderId = _followUpOrderId;

    _isSubmitting = true;
    _errorMessage = null;
    _notify();

    try {
      // 1. Kiểm tra bắt buộc phải có hồ sơ đã được người dùng lưu
      if (_patient == null) {
        throw Exception(
          'Vui lòng lưu hồ sơ bệnh nhân trước khi đặt lịch khám.',
        );
      }

      final currentPatient = _patient!;

      _patient = currentPatient.copyWith(
        gestationalWeeks: _gestationalWeeks ?? currentPatient.gestationalWeeks,
        para: 'G$_gravida P$_para A$_abortion L$_living',
        lmp: _lmp != null
            ? DateFormat('yyyy-MM-dd').format(_lmp!)
            : currentPatient.lmp,
        edd: _edd != null
            ? DateFormat('yyyy-MM-dd').format(_edd!)
            : currentPatient.edd,
      );

      _sessionService.setPhone(_phone.trim());
      _sessionService.setPatientId(currentPatient.id);

      // 2. Create Appointment in Backend
      final order = orderId != null
          ? _pendingFollowUpOrders
                .where((item) => item.id == orderId)
                .firstOrNull
          : null;
      final scheduledTime = orderId != null
          ? (_selectedSlot?.startTime ?? followUpScheduledTime!)
          : _selectedSlot!.startTime;
      final result = await _appointmentService.createAppointment(
        patientId: currentPatient.id,
        serviceTypeId: _selectedService!.id,
        scheduledTime: scheduledTime,
        followUpOrderId: orderId,
        doctorId: orderId != null ? _originalDoctorId : null,
        departmentId: order?.departmentId,
      );

      if (!_isCurrent) return false;
      _bookingSuccessResult = result;
      _existingAppointment = result;
      _hasExistingAppointment = true;
      _lastSubmittedWasFollowUp = orderId != null;
      if (orderId != null) {
        _pendingFollowUpOrders = _pendingFollowUpOrders
            .where((order) => order.id != orderId)
            .toList();
        _clearFollowUpSelection();
      }
      _isSubmitting = false;
      _notify();
      return true;
    } catch (e) {
      if (!_isCurrent) return false;
      final codes = e is ApiException ? e.codes : <String>{};
      if (orderId != null && codes.contains('FOLLOW_UP_ALREADY_BOOKED')) {
        _pendingFollowUpOrders = _pendingFollowUpOrders
            .where((order) => order.id != orderId)
            .toList();
        _clearFollowUpSelection();
      }
      if (codes.contains('SCHEDULE_FULL') ||
          codes.contains('SCHEDULE_NOT_ACTIVE') ||
          codes.contains('SCHEDULE_MISMATCH')) {
        _selectedSlot = null;
        await _fetchSlots();
        if (!_isCurrent) return false;
      }
      _errorMessage = codes.contains('SCHEDULE_FULL')
          ? 'Ca trực đã hết chỗ. Danh sách giờ khám đã được cập nhật; vui lòng chọn lại.'
          : codes.contains('SCHEDULE_NOT_ACTIVE') ||
                codes.contains('SCHEDULE_MISMATCH')
          ? 'Ca trực hoặc giờ khám đã thay đổi. Vui lòng chọn lại khung giờ.'
          : patientErrorMessage(
              e,
              fallback: 'Không xác nhận được đặt lịch. Kiểm tra lịch sử trước khi thử lại.',
            );
      _isSubmitting = false;
      _notify();
      return false;
    }
  }

  /// Resets booking state for a fresh booking session
  void resetBooking() {
    _bookingSuccessResult = null;
    _lastSubmittedWasFollowUp = false;
    _selectedDate = defaultBookingDate;
    _selectedSlot = null;
    _hasExistingAppointment = false;
    _existingAppointment = null;
    _clearFollowUpSelection();
    _followUpVersion++;
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
    _notify();
  }

  /// Clears patient session and resets all booking form states on logout
  void logout() {
    clearSelectedPatient();
    resetBooking();
  }
}
