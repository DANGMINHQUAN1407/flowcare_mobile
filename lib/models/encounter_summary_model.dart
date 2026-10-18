class PreExamOrderModel {
  final String id;
  final String encounterId;
  final String serviceTypeId;
  final String serviceTypeName;
  final String status;
  final String? notes;
  final DateTime? completedAt;
  final String? completedBy;
  final DateTime createdAt;

  const PreExamOrderModel({
    required this.id,
    required this.encounterId,
    required this.serviceTypeId,
    required this.serviceTypeName,
    required this.status,
    this.notes,
    this.completedAt,
    this.completedBy,
    required this.createdAt,
  });

  factory PreExamOrderModel.fromJson(Map<String, dynamic> json) {
    return PreExamOrderModel(
      id: json['id']?.toString() ?? '',
      encounterId: json['encounterId']?.toString() ?? '',
      serviceTypeId: json['serviceTypeId']?.toString() ?? '',
      serviceTypeName: json['serviceTypeName']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Pending',
      notes: json['notes']?.toString(),
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'].toString())
          : null,
      completedBy: json['completedBy']?.toString(),
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'encounterId': encounterId,
      'serviceTypeId': serviceTypeId,
      'serviceTypeName': serviceTypeName,
      'status': status,
      'notes': notes,
      'completedAt': completedAt?.toIso8601String(),
      'completedBy': completedBy,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

/// Only workflow timestamps are exposed to the patient journey, not measurements.
class NursingIntakeProgressModel {
  final DateTime? intakeSavedAt;
  final DateTime? vitalSignsRecordedAt;

  const NursingIntakeProgressModel({
    this.intakeSavedAt,
    this.vitalSignsRecordedAt,
  });

  bool get hasIntake => intakeSavedAt != null;
  bool get hasVitalSigns => vitalSignsRecordedAt != null;
  bool get isComplete => hasIntake && hasVitalSigns;
  bool get hasStarted => hasIntake || hasVitalSigns;
  DateTime? get completedAt => !isComplete
      ? null
      : intakeSavedAt!.isAfter(vitalSignsRecordedAt!)
      ? intakeSavedAt
      : vitalSignsRecordedAt;

  factory NursingIntakeProgressModel.fromJson(Map<String, dynamic> json) =>
      NursingIntakeProgressModel(
        intakeSavedAt: DateTime.tryParse(
          json['intakeSavedAt']?.toString() ?? '',
        ),
        vitalSignsRecordedAt: DateTime.tryParse(
          json['vitalSignsRecordedAt']?.toString() ?? '',
        ),
      );

  Map<String, dynamic> toJson() => {
    'intakeSavedAt': intakeSavedAt?.toIso8601String(),
    'vitalSignsRecordedAt': vitalSignsRecordedAt?.toIso8601String(),
  };
}

class EncounterSummaryModel {
  final String encounterId;
  final String patientName;
  final String encounterStatus;
  final bool isEmergency;
  final String? recommendedDepartmentId;
  final String? departmentName;
  final int? estimatedWaitMinutes;
  final DateTime? estimatedCompletionTime;
  final int? queueNumber;
  final String? queueStatus;
  final DateTime? checkInTime;
  final List<PreExamOrderModel> preExamOrders;
  final String? roomName;
  final String? doctorName;
  final String? ticketCode;
  final String? patientPhone;
  final NursingIntakeProgressModel? nursingIntake;

  const EncounterSummaryModel({
    required this.encounterId,
    required this.patientName,
    required this.encounterStatus,
    required this.isEmergency,
    this.recommendedDepartmentId,
    this.departmentName,
    this.estimatedWaitMinutes,
    this.estimatedCompletionTime,
    this.queueNumber,
    this.queueStatus,
    this.checkInTime,
    this.preExamOrders = const [],
    this.roomName,
    this.doctorName,
    this.ticketCode,
    this.patientPhone,
    this.nursingIntake,
  });

  bool get isFinalized =>
      const {'finalized', 'completed'}.contains(encounterStatus.toLowerCase());

  bool get isConsulting => queueStatus?.toLowerCase() == 'inprogress';

  factory EncounterSummaryModel.fromJson(Map<String, dynamic> json) {
    var rawOrders = json['preExamOrders'];
    List<PreExamOrderModel> orders = [];
    if (rawOrders is List) {
      orders = rawOrders
          .whereType<Map<String, dynamic>>()
          .map((item) => PreExamOrderModel.fromJson(item))
          .toList();
    }

    return EncounterSummaryModel(
      encounterId: json['encounterId']?.toString() ?? '',
      patientName: json['patientName']?.toString() ?? '',
      encounterStatus: json['encounterStatus']?.toString() ?? '',
      isEmergency: json['isEmergency'] == true,
      recommendedDepartmentId: json['recommendedDepartmentId']?.toString(),
      departmentName: json['departmentName']?.toString(),
      estimatedWaitMinutes: json['estimatedWaitMinutes'] is num
          ? (json['estimatedWaitMinutes'] as num).toInt()
          : null,
      estimatedCompletionTime: json['estimatedCompletionTime'] != null
          ? DateTime.tryParse(json['estimatedCompletionTime'].toString())
          : null,
      queueNumber: json['queueNumber'] is num
          ? (json['queueNumber'] as num).toInt()
          : null,
      queueStatus: json['queueStatus']?.toString(),
      checkInTime: json['checkInTime'] != null
          ? DateTime.tryParse(json['checkInTime'].toString())
          : null,
      preExamOrders: orders,
      roomName: json['roomName']?.toString(),
      doctorName: json['doctorName']?.toString(),
      ticketCode: json['ticketCode']?.toString(),
      patientPhone: json['patientPhone']?.toString(),
      nursingIntake: json['nursingIntake'] is Map<String, dynamic>
          ? NursingIntakeProgressModel.fromJson(
              json['nursingIntake'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'encounterId': encounterId,
      'patientName': patientName,
      'encounterStatus': encounterStatus,
      'isEmergency': isEmergency,
      'recommendedDepartmentId': recommendedDepartmentId,
      'departmentName': departmentName,
      'estimatedWaitMinutes': estimatedWaitMinutes,
      'estimatedCompletionTime': estimatedCompletionTime?.toIso8601String(),
      'queueNumber': queueNumber,
      'queueStatus': queueStatus,
      'checkInTime': checkInTime?.toIso8601String(),
      'preExamOrders': preExamOrders.map((o) => o.toJson()).toList(),
      'roomName': roomName,
      'doctorName': doctorName,
      'ticketCode': ticketCode,
      'patientPhone': patientPhone,
      'nursingIntake': nursingIntake?.toJson(),
    };
  }
}
