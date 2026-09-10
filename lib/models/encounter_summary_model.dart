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
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
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
  });

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
    };
  }
}
