int _minutes(dynamic value) {
  if (value is! int || value < 0) {
    throw const FormatException('Invalid duration');
  }
  return value;
}

class AssistanceEligibility {
  final bool canRequest;
  final int remainingOrders;
  final String? reason, reasonCode;
  AssistanceEligibility.fromJson(Map<String, dynamic> json)
    : canRequest = json['canRequest'] == true,
      remainingOrders = _minutes(json['pendingPlannableOrdersCount']),
      reason = json['reason'] as String?,
      reasonCode = json['reasonCode'] as String?;
}

class RouteAssistanceRequest {
  final String id, encounterId, patientId, status, routeStatus;
  final String? resolutionNotes, proposedPlanId, appliedPlanId, processingError;
  final DateTime? appliedAt;
  RouteAssistanceRequest.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      encounterId = json['encounterId'] as String,
      patientId = json['patientId'] as String,
      status = json['status'] is int
          ? const ['Pending', 'InReview', 'Resolved', 'Rejected'][json['status']
                as int]
          : json['status'] as String,
      routeStatus = json['routeStatus'] as String? ?? 'None',
      resolutionNotes = json['resolutionNotes'] as String?,
      proposedPlanId = json['proposedPlanId'] as String?,
      appliedPlanId = json['appliedPlanId'] as String?,
      processingError = json['processingError'] as String?,
      appliedAt = DateTime.tryParse(json['appliedAt'] as String? ?? '');
  bool get isApplied =>
      routeStatus == 'Applied' && appliedPlanId != null && appliedAt != null;
  bool get isOpen => status == 'Pending' || status == 'InReview';
  String get label {
    if (isApplied) return 'Lộ trình mới đã được áp dụng';
    if (routeStatus == 'Proposed' && proposedPlanId != null) {
      return 'Có đề xuất · Chờ bác sĩ duyệt';
    }
    if (routeStatus == 'ProposalSuperseded') return 'Đề xuất đã được thay thế';
    if (routeStatus == 'Failed') return 'Chưa tạo được đề xuất';
    return switch (status) {
      'Pending' => 'Đã gửi · Chờ tiếp nhận',
      'InReview' => 'Nhân viên đã tiếp nhận',
      'Resolved' => 'Nhân viên đã phản hồi',
      'Rejected' => 'Yêu cầu chưa được chấp nhận',
      _ => 'Chưa xác định trạng thái hỗ trợ',
    };
  }
}

class RouteComparisonStep {
  final String serviceName, roomName;
  final int travel, queue, service, result;
  RouteComparisonStep.fromJson(Map<String, dynamic> json)
    : serviceName = json['serviceTypeName'] as String,
      roomName = json['assignedRoomName'] as String,
      travel = _minutes(json['estimatedTravelMinutes']),
      queue = _minutes(json['estimatedQueueWaitMinutes']),
      service = _minutes(json['estimatedDurationMinutes']),
      result = _minutes(json['estimatedResultWaitMinutes']);
}

class ComparisonRoute {
  final int travel, queue, service, total;
  final List<RouteComparisonStep> steps;
  ComparisonRoute.fromJson(Map<String, dynamic> json)
    : travel = _minutes(json['totalTravelMinutes']),
      queue = _minutes(json['totalQueueWaitMinutes']),
      service = _minutes(json['totalServiceMinutes']),
      total = _minutes(json['makespanMinutes']),
      steps = (json['steps'] as List)
          .map((s) => RouteComparisonStep.fromJson(s as Map<String, dynamic>))
          .toList();
}

class RouteComparison {
  final String encounterId, outcome;
  final ComparisonRoute baseline, optimized;
  final int savedMinutes;
  final DateTime computedAt;
  RouteComparison.fromJson(Map<String, dynamic> json)
    : encounterId = json['encounterId'] as String,
      outcome = json['outcome'] as String,
      baseline = ComparisonRoute.fromJson(
        json['baseline'] as Map<String, dynamic>,
      ),
      optimized = ComparisonRoute.fromJson(
        json['optimized'] as Map<String, dynamic>,
      ),
      savedMinutes = _minutes(json['savedMinutes']),
      computedAt = DateTime.parse(json['computedAt'] as String) {
    final delta = baseline.total - optimized.total;
    if (savedMinutes != (delta > 0 ? delta : 0) ||
        (outcome == 'Improved' && delta <= 0)) {
      throw const FormatException('Inconsistent comparison');
    }
  }
}
