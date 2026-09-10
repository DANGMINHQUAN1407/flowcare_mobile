class PregnancyMilestoneModel {
  final int week;
  final String title;
  final String description;
  final String keyExams;
  final String babyDevelopment;
  final bool isCrucial;

  const PregnancyMilestoneModel({
    required this.week,
    required this.title,
    required this.description,
    required this.keyExams,
    required this.babyDevelopment,
    this.isCrucial = false,
  });

  static List<PregnancyMilestoneModel> get standardMilestones => const [
        PregnancyMilestoneModel(
          week: 6,
          title: 'Khám thai lần đầu & Siêu âm tim thai',
          description: 'Xác định thai trong tử cung, kiểm tra túi thai và hoạt động tim thai sớm.',
          keyExams: 'Siêu âm đầu dò 2D, Xét nghiệm nhóm máu ABO/Rh, Huyết đồ',
          babyDevelopment: 'Tim thai bắt đầu đập, các cơ quan sơ khai hình thành.',
          isCrucial: true,
        ),
        PregnancyMilestoneModel(
          week: 12,
          title: 'Đo độ mờ da gáy & Sàng lọc Double Test/NIPT',
          description: 'Thời điểm vàng đo khoảng sáng sau gáy (NT) tầm soát hội chứng Down (Trisomy 21, 18, 13).',
          keyExams: 'Siêu âm đo độ mờ da gáy NT, Xét nghiệm Double Test hoặc NIPT',
          babyDevelopment: 'Bé bắt đầu cử động nhẹ, các ngón tay và ngón chân tách rời.',
          isCrucial: true,
        ),
        PregnancyMilestoneModel(
          week: 16,
          title: 'Khám thai định kỳ & Triple Test',
          description: 'Đánh giá nguy cơ dị tật ống thần kinh và các bất thường nhiễm sắc thể bổ sung.',
          keyExams: 'Xét nghiệm Triple Test (nếu chưa làm NIPT), Kiểm tra huyết áp mẹ',
          babyDevelopment: 'Bé đã có thể nghe được âm thanh và nhịp tim của mẹ.',
        ),
        PregnancyMilestoneModel(
          week: 22,
          title: 'Siêu âm 4D hình thái học thai nhi',
          description: 'Khảo sát chi tiết cấu trúc giải phẫu: tim, não, mặt, cột sống, dạ dày, thận và tứ chi.',
          keyExams: 'Siêu âm 4D hình thái chi tiết, Đo chiều dài cổ tử cung',
          babyDevelopment: 'Khuôn mặt bé hoàn thiện rõ nét, có biểu cảm mút tay, chớp mắt.',
          isCrucial: true,
        ),
        PregnancyMilestoneModel(
          week: 26,
          title: 'Nghiệm pháp dung nạp đường huyết (OGTT)',
          description: 'Tầm soát đái tháo đường thai kỳ giúp phòng ngừa tiền sản giật và đa ối.',
          keyExams: 'Xét nghiệm dung nạp Glucose 75g (3 mẫu máu), Tiêm phòng uốn ván VAT mũi 1',
          babyDevelopment: 'Phổi bé phát triển thêm các phế nang sơ khai.',
          isCrucial: true,
        ),
        PregnancyMilestoneModel(
          week: 32,
          title: 'Siêu âm Doppler màu & Đánh giá tăng trưởng',
          description: 'Đánh giá lưu lượng tuần hoàn động mạch rốn, não giữa, kiểm tra ngôi thai và nước ối.',
          keyExams: 'Siêu âm Doppler màu, Tiêm uốn ván VAT mũi 2 (nếu có)',
          babyDevelopment: 'Bé tăng cân nhanh, tích lũy lớp mỡ dưới da.',
          isCrucial: true,
        ),
        PregnancyMilestoneModel(
          week: 36,
          title: 'Đo tim thai CTG (Non-Stress Test) & Khám tiền sản',
          description: 'Theo dõi nhịp tim thai và cơn co tử cung định kỳ hàng tuần chuẩn bị sinh.',
          keyExams: 'Monitoring tim thai CTG, Xét nghiệm liên cầu khuẩn nhóm B (GBS)',
          babyDevelopment: 'Bé đã quay đầu về vị trí thuận lợi sẵn sàng chào đời.',
          isCrucial: true,
        ),
      ];
}
