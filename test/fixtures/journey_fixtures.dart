import 'package:flowcare_mobile/models/encounter_summary_model.dart';
import 'package:flowcare_mobile/models/paraclinical_plan_model.dart';

Map<String, dynamic> timedPlanJson() => {
  'id': 'plan-1',
  'encounterId': 'visit-1',
  'status': 'Completed',
  'source': 'MedicalOrders',
  'createdAt': '2026-10-12T12:35:30+07:00',
  'estimatedTotalMinutes': 76,
  'steps': [
    <String, dynamic>{
      'id': 'xray',
      'serviceTypeName': 'Chụp X-Quang',
      'assignedRoomName': 'Phòng X-Quang thực tế',
      'stepOrder': 1,
      'status': 'Completed',
      'estimatedTravelMinutes': 3,
      'estimatedDurationMinutes': 5,
      'estimatedResultWaitMinutes': 15,
      'estimatedStartTime': '2026-10-12T12:49:58.360+07:00',
      'enqueuedAt': '2026-10-12T12:46:58.342+07:00',
      'actualStartTime': '2026-10-12T12:48:00.515+07:00',
      'actualEndTime': '2026-10-12T12:58:26.535+07:00',
      'resultReadyTime': '2026-10-12T12:58:30.689+07:00',
    },
    <String, dynamic>{
      'id': 'lab',
      'serviceTypeName': 'Xét nghiệm máu',
      'assignedRoomName': 'Phòng xét nghiệm thực tế',
      'stepOrder': 2,
      'status': 'Completed',
      'estimatedTravelMinutes': 3,
      'estimatedDurationMinutes': 5,
      'estimatedResultWaitMinutes': 60,
      'estimatedStartTime': '2026-10-12T12:57:58.360+07:00',
      'enqueuedAt': '2026-10-12T12:58:26.873+07:00',
      'actualStartTime': '2026-10-12T13:09:35.241+07:00',
      'actualEndTime': '2026-10-12T13:10:48.037+07:00',
      'resultReadyTime': '2026-10-12T13:11:10.889+07:00',
    },
  ],
};

EncounterSummaryModel summaryFixture({
  String status = 'Finalized',
  String queueStatus = 'Done',
  String encounterId = 'visit-1',
  String phone = '0900000001',
}) => EncounterSummaryModel(
  encounterId: encounterId,
  patientName: 'Bệnh nhân kiểm thử',
  patientPhone: phone,
  encounterStatus: status,
  queueStatus: queueStatus,
  isEmergency: false,
  roomName: 'Phòng khám thực tế',
  doctorName: 'Bác sĩ kiểm thử',
  queueNumber: 7,
  estimatedWaitMinutes: 5,
  checkInTime: DateTime.parse('2026-10-12T08:34:16+07:00'),
);

ParaclinicalPlanModel planFixture({
  String status = 'Completed',
  String source = 'MedicalOrders',
  List<ParaclinicalStepModel>? steps,
}) => ParaclinicalPlanModel(
  id: 'plan-1',
  encounterId: 'visit-1',
  status: status,
  source: source,
  nextAfterPlan: 'Quay lại bác sĩ đọc kết quả',
  steps:
      steps ??
      [
        serviceFixture(
          id: 'xray',
          title: 'Chụp X-Quang',
          room: 'Phòng X-Quang thực tế',
          order: 1,
        ),
        serviceFixture(
          id: 'lab',
          title: 'Xét nghiệm máu',
          room: 'Phòng xét nghiệm thực tế',
          order: 2,
        ),
      ],
);

ParaclinicalStepModel serviceFixture({
  String id = 'lab',
  String title = 'Xét nghiệm máu',
  String room = 'Phòng xét nghiệm thực tế',
  int order = 1,
  String status = 'Completed',
  bool held = false,
}) => ParaclinicalStepModel(
  id: id,
  serviceTypeName: title,
  roomName: room,
  building: 'Nhà A',
  floor: '1',
  stepOrder: order,
  status: status,
  queueNumber: 2,
  isHeldForResult: held,
  waitsForResultOf: held ? ['Xét nghiệm máu'] : [],
  skipReason: status == 'Skipped' ? 'Bệnh nhân vắng mặt' : null,
  resultReadyTime: status == 'Completed'
      ? DateTime.parse('2026-10-12T13:11:10+07:00')
      : null,
);
