class RouteOptimizationEligibility {
  final bool canOptimize;
  final int remainingOrders;
  final String? reason, proposedPlanId, activePlanId, activePlanMode;

  RouteOptimizationEligibility.fromJson(Map<String, dynamic> json)
    : canOptimize = json['canOptimize'] == true,
      remainingOrders =
          json['remainingOrders'] is int && json['remainingOrders'] >= 0
          ? json['remainingOrders'] as int
          : (throw const FormatException('Invalid remaining order count')),
      reason = json['reason'] as String?,
      proposedPlanId = json['proposedPlanId'] as String?,
      activePlanId = json['activePlanId'] as String?,
      activePlanMode = json['activePlanMode'] as String?;
}
