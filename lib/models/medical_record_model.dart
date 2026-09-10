class PrescriptionItem {
  final String medicineName;
  final String dosage;
  final String usage;
  final int quantity;
  final String unit;

  const PrescriptionItem({
    required this.medicineName,
    required this.dosage,
    required this.usage,
    required this.quantity,
    required this.unit,
  });

  factory PrescriptionItem.fromJson(Map<String, dynamic> json) {
    return PrescriptionItem(
      medicineName: json['medicineName']?.toString() ?? '',
      dosage: json['dosage']?.toString() ?? '',
      usage: json['usage']?.toString() ?? '',
      quantity: json['quantity'] is int ? json['quantity'] as int : int.tryParse(json['quantity']?.toString() ?? '1') ?? 1,
      unit: json['unit']?.toString() ?? 'Viên',
    );
  }

  Map<String, dynamic> toJson() => {
        'medicineName': medicineName,
        'dosage': dosage,
        'usage': usage,
        'quantity': quantity,
        'unit': unit,
      };
}

class ClinicalLabOrder {
  final String orderName;
  final String departmentRoom;
  final String status;
  final String result;

  const ClinicalLabOrder({
    required this.orderName,
    required this.departmentRoom,
    required this.status,
    required this.result,
  });

  factory ClinicalLabOrder.fromJson(Map<String, dynamic> json) {
    return ClinicalLabOrder(
      orderName: json['orderName']?.toString() ?? '',
      departmentRoom: json['departmentRoom']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Completed',
      result: json['result']?.toString() ?? 'Bình thường',
    );
  }

  Map<String, dynamic> toJson() => {
        'orderName': orderName,
        'departmentRoom': departmentRoom,
        'status': status,
        'result': result,
      };
}

class VitalSignsRecord {
  final String bloodPressure;
  final int pulse;
  final double weight;
  final int? gestationalWeeks;
  final int? fetalHeartRate; // FHR in bpm

  const VitalSignsRecord({
    required this.bloodPressure,
    required this.pulse,
    required this.weight,
    this.gestationalWeeks,
    this.fetalHeartRate,
  });

  factory VitalSignsRecord.fromJson(Map<String, dynamic> json) {
    return VitalSignsRecord(
      bloodPressure: json['bloodPressure']?.toString() ?? '115/75 mmHg',
      pulse: json['pulse'] is int ? json['pulse'] as int : 78,
      weight: (json['weight'] as num?)?.toDouble() ?? 58.5,
      gestationalWeeks: json['gestationalWeeks'] as int? ?? 28,
      fetalHeartRate: json['fetalHeartRate'] as int? ?? 142,
    );
  }
}

class MedicalRecordModel {
  final String id;
  final String encounterId;
  final DateTime visitDate;
  final String departmentName;
  final String roomName;
  final String doctorName;
  final String ticketNumber;
  final String status;
  final String diagnosis;
  final String doctorAdvice;
  final DateTime? followUpDate;
  final VitalSignsRecord? vitalSigns;
  final List<PrescriptionItem> prescriptions;
  final List<ClinicalLabOrder> labOrders;

  const MedicalRecordModel({
    required this.id,
    required this.encounterId,
    required this.visitDate,
    required this.departmentName,
    required this.roomName,
    required this.doctorName,
    required this.ticketNumber,
    required this.status,
    required this.diagnosis,
    required this.doctorAdvice,
    this.followUpDate,
    this.vitalSigns,
    required this.prescriptions,
    required this.labOrders,
  });

  factory MedicalRecordModel.createDemoRecord({
    required String patientName,
    required String phone,
    String? customEncounterId,
    String? customTicket,
  }) {
    final now = DateTime.now();
    return MedicalRecordModel(
      id: 'REC-${now.millisecondsSinceEpoch}',
      encounterId: customEncounterId ?? 'ENC-8899',
      visitDate: now,
      departmentName: 'Khoa Sản - Phụ Khoa',
      roomName: 'Phòng Khám 302 (Khu Khám Sản)',
      doctorName: 'BS. CKI Trần Mai Anh',
      ticketNumber: customTicket ?? '#A-136',
      status: 'Completed',
      diagnosis: 'Thai 28 tuần tiến triển thuận lợi. Ngôi đầu, bánh rau bám mặt trước nhóm 1, ối bình thường.',
      doctorAdvice: 'Uống thuốc bổ sung vi chất đều đặn sau ăn. Theo dõi cử động thai (ít nhất 4 lần/ngày). Tái khám sau 4 tuần hoặc ngay khi có dấu hiệu bất thường (đau bụng, ra huyết).',
      followUpDate: now.add(const Duration(days: 28)),
      vitalSigns: const VitalSignsRecord(
        bloodPressure: '115/75 mmHg',
        pulse: 78,
        weight: 58.5,
        gestationalWeeks: 28,
        fetalHeartRate: 142,
      ),
      prescriptions: const [
        PrescriptionItem(
          medicineName: 'Fumafer B9 Corbiere (Sắt sinh học + Acid Folic)',
          dosage: '50mg/0.5mg',
          usage: 'Uống 1 viên / ngày sau ăn sáng 30 phút. Tránh uống cùng trà/sữa.',
          quantity: 30,
          unit: 'Viên',
        ),
        PrescriptionItem(
          medicineName: 'Ostelin Vitamin D3 & Calcium',
          dosage: '600mg Calcium / 500IU D3',
          usage: 'Uống 1 viên / ngày vào buổi sáng cùng nhiều nước.',
          quantity: 60,
          unit: 'Viên',
        ),
        PrescriptionItem(
          medicineName: 'BioIsland DHA for Pregnancy',
          dosage: 'DHA 210mg',
          usage: 'Uống 1 viên / ngày sau bữa trưa.',
          quantity: 30,
          unit: 'Viên nang',
        ),
      ],
      labOrders: const [
        ClinicalLabOrder(
          orderName: 'Tổng phân tích tế bào máu ngoại vi (18 thông số)',
          departmentRoom: 'P.102 - Xét nghiệm Huyết học',
          status: 'Đã có kết quả',
          result: 'Hồng cầu: 4.1 T/L, Hb: 12.8 g/dL (Bình thường)',
        ),
        ClinicalLabOrder(
          orderName: 'Siêu âm 4D hình thái thai nhi 3 tháng giữa',
          departmentRoom: 'P.105 - Siêu âm Sản 4D',
          status: 'Đã có kết quả',
          result: 'Trọng lượng thai ~1,150g, tim thai 142 ck/p (Bình thường)',
        ),
        ClinicalLabOrder(
          orderName: 'Đo biểu đồ tim thai & Cơn gò tử cung (Non-Stress Test)',
          departmentRoom: 'P.108 - Đo Monitoring Sản khoa',
          status: 'Đã thực hiện',
          result: 'Đáp ứng tốt (Reactive NST)',
        ),
      ],
    );
  }
}
