import '../core/utils/hospital_time.dart';

class FollowUpOrderModel {
  static final RegExp _timePrefixPattern = RegExp(
    r'^\s*\[Giờ hẹn:\s*([01]?\d|2[0-3]):([0-5]\d)\](?:\r?\n|\s)*',
    caseSensitive: false,
  );

  final String id;
  final String encounterId;
  final String patientId;
  final String patientName;
  final String originalDoctorId;
  final String originalDoctorName;
  final String departmentId;
  final String departmentName;
  final DateTime targetDate;
  final String? targetTime;
  final DateTime? targetAt;
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
    this.targetTime,
    this.targetAt,
    required this.diagnosis,
    this.preExamServiceIds = const [],
    this.notes,
    this.isBooked = false,
    this.appointmentId,
    required this.createdAt,
  });

  bool canBookFor(String patientId, Set<String> completedEncounterIds) =>
      this.patientId == patientId &&
      id.trim().isNotEmpty &&
      !isBooked &&
      completedEncounterIds.contains(encounterId);

  /// Doctor-scheduled follow-up timestamp converted from Vietnam time (UTC+7) to UTC.
  DateTime scheduledHospitalUtcTime({String fallbackTime = '08:30'}) {
    if (targetAt != null) return targetAt!.toUtc();
    final parts = (targetTime ?? fallbackTime).split(':');
    final hour = parts.length == 2 ? (int.tryParse(parts[0]) ?? 8) : 8;
    final minute = parts.length == 2 ? (int.tryParse(parts[1]) ?? 30) : 30;
    return DateTime.utc(
      targetDate.year,
      targetDate.month,
      targetDate.day,
      hour,
      minute,
    ).subtract(const Duration(hours: 7));
  }

  static String? _normalizeTime(String? raw) {
    if (raw == null) return null;
    final match = RegExp(
      r'^([01]?\d|2[0-3]):([0-5]\d)(?::[0-5]\d)?$',
    ).firstMatch(raw.trim());
    if (match == null) return null;
    return '${match.group(1)!.padLeft(2, '0')}:${match.group(2)!}';
  }

  factory FollowUpOrderModel.fromJson(Map<String, dynamic> json) {
    List<String> parsePreExamIds(dynamic val) {
      if (val is List) {
        return val.map((e) => e.toString()).toList();
      }
      return [];
    }

    final rawNotes = json['notes']?.toString() ?? '';
    final prefixMatch = _timePrefixPattern.firstMatch(rawNotes);
    final extractedTime = prefixMatch != null
        ? '${prefixMatch.group(1)!.padLeft(2, '0')}:${prefixMatch.group(2)!}'
        : null;
    final cleanedNotes = prefixMatch != null
        ? rawNotes.substring(prefixMatch.end).trim()
        : rawNotes.trim();
    final structuredTime = _normalizeTime(json['targetTime']?.toString());
    final rawTargetAt = json['targetAt']?.toString();
    final parsedTargetAt = rawTargetAt != null
        ? DateTime.tryParse(rawTargetAt)
        : null;
    final targetAtTime = parsedTargetAt != null
        ? hospitalTime(parsedTargetAt, pattern: 'HH:mm')
        : null;

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
      targetTime: structuredTime ?? targetAtTime ?? extractedTime,
      targetAt: parsedTargetAt,
      diagnosis: json['diagnosis']?.toString() ?? '',
      preExamServiceIds: parsePreExamIds(json['preExamServiceIds']),
      notes: cleanedNotes.isEmpty ? null : cleanedNotes,
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
      if (targetTime != null) 'targetTime': targetTime,
      'diagnosis': diagnosis,
      'preExamServiceIds': preExamServiceIds,
      'notes': notes,
      'isBooked': isBooked,
      'appointmentId': appointmentId,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
