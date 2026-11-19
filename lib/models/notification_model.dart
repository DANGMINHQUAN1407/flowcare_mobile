import 'dart:convert';

class NotificationModel {
  final String id;
  final String? encounterId;
  final String? patientId;
  final String channel;
  final String status;
  final String? title;
  final String? message;
  final String? type;
  final bool isRead;
  final DateTime? readAt;
  final String? payloadJson;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    this.encounterId,
    this.patientId,
    this.channel = 'Push',
    this.status = 'Sent',
    this.title,
    this.message,
    this.type,
    this.isRead = false,
    this.readAt,
    this.payloadJson,
    required this.createdAt,
  });

  bool get isFollowUpReminder =>
      type == 'FollowUpReminder' ||
      (type != null && type!.contains('FollowUp')) ||
      (title != null && title!.contains('tái khám')) ||
      (message != null && message!.contains('tái khám'));

  bool get isAppointmentReminder =>
      type == 'AppointmentReminder' ||
      (title != null && title!.contains('lịch hẹn')) ||
      (message != null && message!.contains('lịch hẹn'));

  Map<String, dynamic>? get parsedPayload {
    if (payloadJson == null || payloadJson!.trim().isEmpty) return null;
    try {
      return jsonDecode(payloadJson!) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  String? get targetTime {
    final payload = parsedPayload;
    if (payload != null && payload.containsKey('targetTime')) {
      return payload['targetTime']?.toString();
    }
    return null;
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id']?.toString() ?? '',
      encounterId: json['encounterId']?.toString(),
      patientId: json['patientId']?.toString(),
      channel: json['channel']?.toString() ?? 'Push',
      status: json['status']?.toString() ?? 'Sent',
      title: json['title']?.toString(),
      message: json['message']?.toString(),
      type: json['type']?.toString(),
      isRead: json['isRead'] == true,
      readAt: json['readAt'] != null
          ? DateTime.tryParse(json['readAt'].toString())
          : null,
      payloadJson: json['payloadJson']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (encounterId != null) 'encounterId': encounterId,
      if (patientId != null) 'patientId': patientId,
      'channel': channel,
      'status': status,
      if (title != null) 'title': title,
      if (message != null) 'message': message,
      if (type != null) 'type': type,
      'isRead': isRead,
      if (readAt != null) 'readAt': readAt!.toIso8601String(),
      if (payloadJson != null) 'payloadJson': payloadJson,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  NotificationModel copyWith({bool? isRead, DateTime? readAt}) {
    return NotificationModel(
      id: id,
      encounterId: encounterId,
      patientId: patientId,
      channel: channel,
      status: status,
      title: title,
      message: message,
      type: type,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      payloadJson: payloadJson,
      createdAt: createdAt,
    );
  }
}
