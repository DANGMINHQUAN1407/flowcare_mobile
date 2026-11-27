class JourneyQueueStatus {
  final String encounterId;
  final String? planId, currentStepId, currentRoomId;
  final int? queuePosition, estimatedWaitMinutesToCall;

  const JourneyQueueStatus({
    required this.encounterId,
    this.planId,
    this.currentStepId,
    this.currentRoomId,
    this.queuePosition,
    this.estimatedWaitMinutesToCall,
  });

  factory JourneyQueueStatus.fromJson(Map<String, dynamic> json) =>
      JourneyQueueStatus(
        encounterId: json['encounterId']?.toString() ?? '',
        planId: json['planId']?.toString(),
        currentStepId: json['currentStepId']?.toString(),
        currentRoomId: json['currentRoomId']?.toString(),
        queuePosition: _nonNegativeInt(json['queuePosition']),
        estimatedWaitMinutesToCall: _nonNegativeInt(
          json['estimatedWaitMinutesToCall'],
        ),
      );

  static int? _nonNegativeInt(Object? value) =>
      value is int && value >= 0 ? value : null;
}
