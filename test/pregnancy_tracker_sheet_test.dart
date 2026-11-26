import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowcare_mobile/models/patient_model.dart';
import 'package:flowcare_mobile/screens/home/pregnancy_tracker_sheet.dart';

void main() {
  Future<void> showTracker(WidgetTester tester, PatientModel? patient) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: PregnancyTrackerSheet(
        patient: patient,
        onBookAppointment: () {},
      )),
    ));
  }

  testWidgets('keeps milestones without duplicating the pregnancy profile', (tester) async {
    await showTracker(tester, const PatientModel(
      id: 'test', fullName: 'Thu Như', phone: '0971237865',
      gestationalWeeks: 21, gestationalDays: 6,
      lmp: '2026-06-26', edd: '2027-04-02', para: '1000',
    ));
    expect(find.text('Tuần 21 + 6 ngày'), findsNothing);
    expect(find.text('Dự sinh (EDD): 2027-04-02'), findsNothing);
    expect(find.text('Đặt lịch khám thai mốc tiếp theo'), findsOneWidget);
  });

  testWidgets('does not invent missing pregnancy information', (tester) async {
    await showTracker(tester, null);
    expect(find.text('Đặt lịch khám thai mốc tiếp theo'), findsOneWidget);
    expect(find.text('Các mốc khám thai quan trọng (Chuẩn Bộ Y Tế)'), findsOneWidget);
  });
}
