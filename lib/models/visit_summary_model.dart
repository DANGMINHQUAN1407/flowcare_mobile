class VisitSummaryModel {
  final String encounterId;
  final String? diagnosis;
  final String? plan;
  final List<VisitPrescriptionItem> prescriptions;

  const VisitSummaryModel({
    required this.encounterId,
    this.diagnosis,
    this.plan,
    this.prescriptions = const [],
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
      );
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
