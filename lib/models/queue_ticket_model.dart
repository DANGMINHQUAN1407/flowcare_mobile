class QueueTicketModel {
  final String id;
  final String encounterId;
  final String departmentId;
  final String departmentName;
  final int queueNumber;
  final String status;
  final DateTime createdAt;

  const QueueTicketModel({
    required this.id,
    required this.encounterId,
    required this.departmentId,
    required this.departmentName,
    required this.queueNumber,
    required this.status,
    required this.createdAt,
  });

  factory QueueTicketModel.fromJson(Map<String, dynamic> json) {
    return QueueTicketModel(
      id: json['id']?.toString() ?? '',
      encounterId: json['encounterId']?.toString() ?? '',
      departmentId: json['departmentId']?.toString() ?? '',
      departmentName: json['departmentName']?.toString() ?? '',
      queueNumber: json['queueNumber'] is num ? (json['queueNumber'] as num).toInt() : 0,
      status: json['status']?.toString() ?? 'Waiting',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'encounterId': encounterId,
      'departmentId': departmentId,
      'departmentName': departmentName,
      'queueNumber': queueNumber,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
