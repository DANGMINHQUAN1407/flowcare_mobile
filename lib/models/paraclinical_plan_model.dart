class ParaclinicalPlanModel {
  final String id;
  final String encounterId;
  final String status;
  final String source;
  final String? mode;
  final String nextAfterPlan;
  final List<ParaclinicalStepModel> steps;
  final double? estimatedTotalMinutes;
  final DateTime? createdAt;

  const ParaclinicalPlanModel({
    required this.id,
    required this.encounterId,
    required this.status,
    required this.source,
    this.mode,
    required this.nextAfterPlan,
    required this.steps,
    this.estimatedTotalMinutes,
    this.createdAt,
  });

  bool get isProposed => status.toLowerCase() == 'proposed';
  bool get isCompleted => status.toLowerCase() == 'completed';
  bool get isDoctorOrdered => source.toLowerCase() == 'medicalorders';
  bool get followsOriginalOrder => mode == 'OriginalOrder';

  factory ParaclinicalPlanModel.fromJson(Map<String, dynamic> json) {
    final steps =
        (json['steps'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(ParaclinicalStepModel.fromJson)
            .toList()
          ..sort((a, b) => a.stepOrder.compareTo(b.stepOrder));
    return ParaclinicalPlanModel(
      id: json['id']?.toString() ?? '',
      encounterId: json['encounterId']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      source: json['source']?.toString() ?? '',
      mode: json['mode']?.toString(),
      nextAfterPlan: json['nextAfterPlan']?.toString() ?? '',
      estimatedTotalMinutes: readMinutes(json['estimatedTotalMinutes']),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      steps: List.unmodifiable(steps),
    );
  }
}

class ParaclinicalStepModel {
  final String id;
  final String serviceTypeName;
  final String roomName;
  final String? floor;
  final String? building;
  final int stepOrder;
  final String status;
  final int? queueNumber;
  final String? instruction;
  final bool isHeldForResult;
  final List<String> waitsForResultOf;
  final String? skipReason;
  final DateTime? estimatedStartTime;
  final DateTime? actualStartTime;
  final DateTime? actualEndTime;
  final DateTime? resultReadyTime;
  final bool? isResultFinalized;
  final bool? requiresFinalizedResult;
  final DateTime? resultFinalizedAt;
  final DateTime? enqueuedAt;
  final double? estimatedTravelMinutes;
  final double? estimatedDurationMinutes;
  final double? estimatedResultWaitMinutes;

  const ParaclinicalStepModel({
    required this.id,
    required this.serviceTypeName,
    required this.roomName,
    required this.stepOrder,
    required this.status,
    this.floor,
    this.building,
    this.queueNumber,
    this.instruction,
    this.isHeldForResult = false,
    this.waitsForResultOf = const [],
    this.skipReason,
    this.estimatedStartTime,
    this.actualStartTime,
    this.actualEndTime,
    this.resultReadyTime,
    this.isResultFinalized,
    this.requiresFinalizedResult,
    this.resultFinalizedAt,
    this.enqueuedAt,
    this.estimatedTravelMinutes,
    this.estimatedDurationMinutes,
    this.estimatedResultWaitMinutes,
  });

  bool get isCompleted => status.toLowerCase() == 'completed';
  bool get hasPublishedResult =>
      isCompleted &&
      (isResultFinalized == true ||
          (requiresFinalizedResult == false && resultReadyTime != null));
  bool get isSkipped => status.toLowerCase() == 'skipped';
  bool get isResolved => hasPublishedResult || isSkipped;
  DateTime? get publishedResultAt =>
      hasPublishedResult ? resultFinalizedAt ?? resultReadyTime : null;

  String get location => [
    if (roomName.isNotEmpty) roomName,
    if (building?.trim().isNotEmpty == true) building!,
    if (floor?.trim().isNotEmpty == true) 'Tầng $floor',
  ].join(' · ');

  factory ParaclinicalStepModel.fromJson(
    Map<String, dynamic> json,
  ) => ParaclinicalStepModel(
    id: json['id']?.toString() ?? '',
    serviceTypeName:
        json['serviceTypeName']?.toString() ?? 'Dịch vụ cận lâm sàng',
    roomName: json['assignedRoomName']?.toString() ?? '',
    floor: json['assignedRoomFloor']?.toString(),
    building: json['assignedRoomBuilding']?.toString(),
    stepOrder: (json['stepOrder'] as num?)?.toInt() ?? 0,
    status: json['status']?.toString() ?? 'Pending',
    queueNumber: (json['queueNumber'] as num?)?.toInt(),
    instruction: json['instruction']?.toString(),
    isHeldForResult: json['isHeldForResult'] == true,
    waitsForResultOf: (json['waitsForResultOf'] as List? ?? [])
        .map((e) => e.toString())
        .toList(),
    skipReason: json['skipReason']?.toString(),
    estimatedStartTime: DateTime.tryParse(
      json['estimatedStartTime']?.toString() ?? '',
    ),
    actualStartTime: DateTime.tryParse(
      json['actualStartTime']?.toString() ?? '',
    ),
    actualEndTime: DateTime.tryParse(json['actualEndTime']?.toString() ?? ''),
    resultReadyTime: DateTime.tryParse(
      json['resultReadyTime']?.toString() ?? '',
    ),
    isResultFinalized: json['isResultFinalized'] is bool
        ? json['isResultFinalized'] as bool
        : null,
    requiresFinalizedResult: json['requiresFinalizedResult'] is bool
        ? json['requiresFinalizedResult'] as bool
        : null,
    resultFinalizedAt: DateTime.tryParse(
      json['resultFinalizedAt']?.toString() ?? '',
    ),
    enqueuedAt: DateTime.tryParse(json['enqueuedAt']?.toString() ?? ''),
    estimatedTravelMinutes: readMinutes(json['estimatedTravelMinutes']),
    estimatedDurationMinutes: readMinutes(json['estimatedDurationMinutes']),
    estimatedResultWaitMinutes: readMinutes(json['estimatedResultWaitMinutes']),
  );
}

double? readMinutes(dynamic value) =>
    value is num && value.isFinite && value >= 0 ? value.toDouble() : null;
