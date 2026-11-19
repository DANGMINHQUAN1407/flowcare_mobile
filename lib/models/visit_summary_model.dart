class VisitSummaryModel {
  final String encounterId;
  final String? diagnosis;
  final String? plan;
  final List<VisitPrescriptionItem> prescriptions;
  final List<VisitServiceResult> services;

  const VisitSummaryModel({
    required this.encounterId,
    this.diagnosis,
    this.plan,
    this.prescriptions = const [],
    this.services = const [],
  });

  factory VisitSummaryModel.fromJson(Map<String, dynamic> json) =>
      VisitSummaryModel(
        encounterId: json['encounterId'] as String,
        diagnosis: json['diagnosis'] as String?,
        plan: json['plan'] as String?,
        prescriptions: (json['prescriptions'] as List? ?? const [])
            .map(
              (item) =>
                  VisitPrescriptionItem.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
        services: (json['services'] as List? ?? const [])
            .map(
              (item) =>
                  VisitServiceResult.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
      );
}

class VisitServiceResult {
  final String serviceName;
  final String status;
  final String? result;
  final String? resultNotes;
  final DateTime? resultFinalizedAt;
  final List<VisitResultAttachment> attachments;

  const VisitServiceResult({
    required this.serviceName,
    required this.status,
    this.result,
    this.resultNotes,
    this.resultFinalizedAt,
    this.attachments = const [],
  });

  factory VisitServiceResult.fromJson(Map<String, dynamic> json) =>
      VisitServiceResult(
        serviceName: json['serviceName'] as String,
        status: json['status'] as String,
        result: json['result'] as String?,
        resultNotes: json['resultNotes'] as String?,
        resultFinalizedAt: DateTime.tryParse(
          json['resultFinalizedAt']?.toString() ?? '',
        ),
        attachments: (json['attachments'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .where((file) => file['id'] is String && file['fileName'] is String)
            .map(
              (file) => VisitResultAttachment(
                id: file['id'] as String,
                fileName: file['fileName'] as String,
              ),
            )
            .toList(),
      );
}

class VisitResultAttachment {
  final String id;
  final String fileName;

  const VisitResultAttachment({required this.id, required this.fileName});
}

class VisitPrescriptionItem {
  final String medicationName;
  final int? quantity;
  final String? dosage;
  final String? instructions;

  const VisitPrescriptionItem({
    required this.medicationName,
    this.quantity,
    this.dosage,
    this.instructions,
  });

  factory VisitPrescriptionItem.fromJson(Map<String, dynamic> json) =>
      VisitPrescriptionItem(
        medicationName: json['medicationName'] as String,
        quantity: json['quantity'] as int?,
        dosage: json['dosage'] as String?,
        instructions: json['instructions'] as String?,
      );
}
