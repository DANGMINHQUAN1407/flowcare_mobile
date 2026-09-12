class FollowUpOrderModel {
  final String id;
  final String encounterId;
  final String patientId;
  final String patientName;
  final String originalDoctorId;
  final String originalDoctorName;
  final String departmentId;
  final String departmentName;
  final DateTime targetDate;
  final String diagnosis;
  final List<String> preExamServiceIds;
  final String? notes;
  final bool isBooked;
  final String? appointmentId;
  final DateTime createdAt;

  const FollowUpOrderModel({
    required this.id,
    required this.encounterId,
    required this.patientId,
    required this.patientName,
    required this.originalDoctorId,
    required this.originalDoctorName,
    required this.departmentId,
    required this.departmentName,
    required this.targetDate,
    required this.diagnosis,
    this.preExamServiceIds = const [],
    this.notes,
    this.isBooked = false,
    this.appointmentId,
    required this.createdAt,
  });

  factory FollowUpOrderModel.fromJson(Map<String, dynamic> json) {
    List<String> parsePreExamIds(dynamic val) {
      if (val is List) {
        return val.map((e) => e.toString()).toList();
      }
      return [];
    }

    return FollowUpOrderModel(
      id: json['id']?.toString() ?? '',
      encounterId: json['encounterId']?.toString() ?? '',
      patientId: json['patientId']?.toString() ?? '',
      patientName: json['patientName']?.toString() ?? '',
      originalDoctorId: json['originalDoctorId']?.toString() ?? '',
      originalDoctorName: json['originalDoctorName']?.toString() ?? 'Bác sĩ chuyên khoa',
      departmentId: json['departmentId']?.toString() ?? '',
      departmentName: json['departmentName']?.toString() ?? 'Khoa Sản - Phụ Khoa',
      targetDate: DateTime.tryParse(json['targetDate']?.toString() ?? '') ?? DateTime.now().add(const Duration(days: 14)),
      diagnosis: json['diagnosis']?.toString() ?? '',
      preExamServiceIds: parsePreExamIds(json['preExamServiceIds']),
      notes: json['notes']?.toString(),
      isBooked: json['isBooked'] == true,
      appointmentId: json['appointmentId']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'encounterId': encounterId,
      'patientId': patientId,
      'patientName': patientName,
      'originalDoctorId': originalDoctorId,
      'originalDoctorName': originalDoctorName,
      'departmentId': departmentId,
      'departmentName': departmentName,
      'targetDate': targetDate.toIso8601String(),
      'diagnosis': diagnosis,
      'preExamServiceIds': preExamServiceIds,
      'notes': notes,
      'isBooked': isBooked,
      'appointmentId': appointmentId,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
