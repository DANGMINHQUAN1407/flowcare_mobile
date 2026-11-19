import 'paraclinical_plan_model.dart';

class RouteOptimizationEligibility {
  final bool canOptimize;
  final int remainingOrders;
  final String? reason, proposedPlanId, activePlanId, activePlanMode;
  final int? savedMinutes, currentTotalMinutes, offeredTotalMinutes;
  final DateTime? expiresAt;
  final ParaclinicalPlanModel? offer;

  RouteOptimizationEligibility.fromJson(Map<String, dynamic> json)
    : canOptimize = json['canOptimize'] == true,
      remainingOrders =
          json['remainingOrders'] is int && json['remainingOrders'] >= 0
          ? json['remainingOrders'] as int
          : (throw const FormatException('Invalid remaining order count')),
      reason = json['reason'] as String?,
      proposedPlanId = json['proposedPlanId'] as String?,
      activePlanId = json['activePlanId'] as String?,
      activePlanMode = json['activePlanMode'] as String?,
      savedMinutes = json['savedMinutes'] as int?,
      currentTotalMinutes = json['currentTotalMinutes'] as int?,
      offeredTotalMinutes = json['offeredTotalMinutes'] as int?,
      expiresAt = DateTime.tryParse(json['expiresAt'] as String? ?? ''),
      offer = json['offer'] is Map<String, dynamic>
          ? ParaclinicalPlanModel.fromJson(
              json['offer'] as Map<String, dynamic>,
            )
          : null;
}
