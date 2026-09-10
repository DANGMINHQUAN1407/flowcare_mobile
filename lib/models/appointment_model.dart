class AppointmentModel {
  final String id;
  final String? patientId;
  final String patientName;
  final DateTime scheduledTime;
  final String serviceTypeId;
  final String serviceTypeName;
  final String status;
  final String source;
  final DateTime createdAt;

  const AppointmentModel({
    required this.id,
    this.patientId,
    required this.patientName,
    required this.scheduledTime,
    required this.serviceTypeId,
    required this.serviceTypeName,
    required this.status,
    required this.source,
    required this.createdAt,
  });

  factory AppointmentModel.fromJson(Map<String, dynamic> json) {
    return AppointmentModel(
      id: json['id']?.toString() ?? '',
      patientId: json['patientId']?.toString(),
      patientName: json['patientName']?.toString() ?? '',
      scheduledTime: DateTime.tryParse(json['scheduledTime']?.toString() ?? '') ?? DateTime.now(),
      serviceTypeId: json['serviceTypeId']?.toString() ?? '',
      serviceTypeName: json['serviceTypeName']?.toString() ?? 'Chuyên khoa Sản - Phụ',
      status: json['status']?.toString() ?? 'Pending',
      source: json['source']?.toString() ?? 'Online',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patientId': patientId,
      'patientName': patientName,
      'scheduledTime': scheduledTime.toIso8601String(),
      'serviceTypeId': serviceTypeId,
      'serviceTypeName': serviceTypeName,
      'status': status,
      'source': source,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class AppointmentCheckModel {
  final bool hasAppointment;
  final AppointmentModel? appointment;
  final String? activeEncounterId;

  const AppointmentCheckModel({
    required this.hasAppointment,
    this.appointment,
    this.activeEncounterId,
  });

  factory AppointmentCheckModel.fromJson(Map<String, dynamic> json) {
    return AppointmentCheckModel(
      hasAppointment: json['hasAppointment'] == true,
      appointment: json['appointment'] != null
          ? AppointmentModel.fromJson(json['appointment'] as Map<String, dynamic>)
          : null,
      activeEncounterId: json['activeEncounterId']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hasAppointment': hasAppointment,
      'appointment': appointment?.toJson(),
      'activeEncounterId': activeEncounterId,
    };
  }
}

class AppointmentSlotModel {
  final String timeRange;
  final DateTime startTime;
  final DateTime endTime;
  final bool isAvailable;

  const AppointmentSlotModel({
    required this.timeRange,
    required this.startTime,
    required this.endTime,
    this.isAvailable = true,
  });

  factory AppointmentSlotModel.fromJson(Map<String, dynamic> json) {
    final start = DateTime.tryParse(json['startTime']?.toString() ?? '') ?? DateTime.now();
    final end = DateTime.tryParse(json['endTime']?.toString() ?? '') ?? DateTime.now();
    final rawAvailable = json['isAvailable'] == true;
    final isPast = start.isBefore(DateTime.now());

    return AppointmentSlotModel(
      timeRange: json['timeRange']?.toString() ?? '',
      startTime: start,
      endTime: end,
      isAvailable: rawAvailable && !isPast,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timeRange': timeRange,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'isAvailable': isAvailable,
    };
  }
}
