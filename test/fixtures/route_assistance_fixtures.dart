Map<String, dynamic> eligibilityJson({int count = 2, bool canRequest = true}) =>
    {
      'canRequest': canRequest,
      'pendingPlannableOrdersCount': count,
      'reason': canRequest ? null : 'Cần còn ít nhất 2 y lệnh chưa thực hiện.',
    };
Map<String, dynamic> assistanceJson({
  String status = 'Pending',
  String route = 'None',
  String patientId = 'patient',
}) => {
  'id': 'request',
  'encounterId': 'visit',
  'patientId': patientId,
  'status': status,
  'routeStatus': route,
  if (route == 'Proposed' || route == 'Applied') 'proposedPlanId': 'proposal',
  if (route == 'Applied') ...{
    'appliedPlanId': 'proposal',
    'appliedAt': '2026-10-17T12:00:00Z',
  },
};
Map<String, dynamic> comparisonJson({bool improved = true}) {
  Map<String, dynamic> route(int total) => {
    'totalTravelMinutes': 3,
    'totalQueueWaitMinutes': 0,
    'totalServiceMinutes': 17,
    'totalResultWaitMinutes': 60,
    'makespanMinutes': total,
    'steps': [
      {
        'serviceTypeName': 'Xét nghiệm máu',
        'assignedRoomName': 'Phòng xét nghiệm Sản Phụ khoa chuyên sâu',
        'estimatedTravelMinutes': 3,
        'estimatedQueueWaitMinutes': 0,
        'estimatedDurationMinutes': 2,
        'estimatedResultWaitMinutes': 60,
      },
      {
        'serviceTypeName': 'Siêu âm',
        'assignedRoomName': 'Phòng siêu âm',
        'estimatedTravelMinutes': 0,
        'estimatedQueueWaitMinutes': 0,
        'estimatedDurationMinutes': 15,
        'estimatedResultWaitMinutes': 0,
      },
    ],
  };
  return {
    'encounterId': 'visit',
    'baseline': route(77),
    'optimized': route(improved ? 62 : 77),
    'savedMinutes': improved ? 15 : 0,
    'computedAt': '2026-10-17T12:00:00Z',
    'outcome': improved ? 'Improved' : 'Equivalent',
  };
}
