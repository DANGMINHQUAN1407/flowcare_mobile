import 'encounter_summary_model.dart';

class PatientVisitModel {
  final String encounterId;
  final String serviceTypeName;
  final String status;
  final DateTime createdAt;
  final DateTime? checkInTime;
  final String? roomName;
  final String? doctorName;

  const PatientVisitModel({
    required this.encounterId,
    required this.serviceTypeName,
    required this.status,
    required this.createdAt,
    this.checkInTime,
    this.roomName,
    this.doctorName,
  });

  bool get isFinalized =>
      const {'finalized', 'completed'}.contains(status.toLowerCase());
  DateTime get visitTime => checkInTime ?? createdAt;

  factory PatientVisitModel.fromJson(Map<String, dynamic> json) =>
      PatientVisitModel(
        encounterId: json['encounterId']?.toString() ?? '',
        serviceTypeName:
            json['serviceTypeName']?.toString() ??
            json['departmentName']?.toString() ??
            'Lượt khám',
        status:
            json['encounterStatus']?.toString() ??
            json['status']?.toString() ??
            '',
        createdAt:
            DateTime.tryParse(
              json['createdAt']?.toString() ??
                  json['checkInTime']?.toString() ??
                  '',
            ) ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        checkInTime: DateTime.tryParse(json['checkInTime']?.toString() ?? ''),
        roomName: json['roomName']?.toString(),
        doctorName: json['doctorName']?.toString(),
      );

  factory PatientVisitModel.fromSummary(EncounterSummaryModel summary) =>
      PatientVisitModel(
        encounterId: summary.encounterId,
        serviceTypeName: summary.departmentName ?? 'Lượt khám',
        status: summary.encounterStatus,
        createdAt:
            summary.checkInTime ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        checkInTime: summary.checkInTime,
        roomName: summary.roomName,
        doctorName: summary.doctorName,
      );
}
