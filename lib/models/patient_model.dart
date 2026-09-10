class PatientModel {
  final String id;
  final String fullName;
  final String phone;
  final String? dob;
  final String? gender;
  final String? address;
  final String? nationalId;
  final String? bloodGroup;
  final String? rhFactor;
  final double? prePregnancyWeight;
  final double? heightCm;
  final String? allergies;
  final String? medicalHistory;
  
  // Obstetric & Gynecological Context
  final int? gestationalWeeks;
  final int? gestationalDays;
  final String? para; // G_P_A_L code
  final String? lmp;  // Last Menstrual Period
  final String? edd;  // Expected Due Date
  final String? obstetricHistory;
  final String? menstrualCycle;
  final String? contraceptiveMethod;
  final DateTime? createdAt;

  const PatientModel({
    required this.id,
    required this.fullName,
    required this.phone,
    this.dob,
    this.gender,
    this.address,
    this.nationalId,
    this.bloodGroup,
    this.rhFactor,
    this.prePregnancyWeight,
    this.heightCm,
    this.allergies,
    this.medicalHistory,
    this.gestationalWeeks,
    this.gestationalDays,
    this.para,
    this.lmp,
    this.edd,
    this.obstetricHistory,
    this.menstrualCycle,
    this.contraceptiveMethod,
    this.createdAt,
  });

  /// Pre-pregnancy BMI calculation (kg / m^2)
  double? get prePregnancyBmi {
    if (prePregnancyWeight == null || heightCm == null || heightCm! <= 0) return null;
    final heightM = heightCm! / 100.0;
    return prePregnancyWeight! / (heightM * heightM);
  }

  /// BMI classification for Asian pregnant women
  String get bmiCategory {
    final bmi = prePregnancyBmi;
    if (bmi == null) return 'Chưa có chỉ số';
    if (bmi < 18.5) return 'Gầy (Thiếu cân)';
    if (bmi < 23.0) return 'Bình thường';
    if (bmi < 25.0) return 'Thừa cân';
    return 'Béo phì';
  }

  /// Check if patient has registered pregnancy information
  bool get hasPregnancyInfo => (gestationalWeeks != null && gestationalWeeks! > 0) || (edd != null && edd!.isNotEmpty);

  factory PatientModel.fromJson(Map<String, dynamic> json) {
    return PatientModel(
      id: json['id']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      dob: json['dob']?.toString(),
      gender: json['gender']?.toString() ?? 'Female',
      address: json['address']?.toString(),
      nationalId: json['nationalId']?.toString(),
      bloodGroup: json['bloodGroup']?.toString(),
      rhFactor: json['rhFactor']?.toString(),
      prePregnancyWeight: (json['prePregnancyWeight'] as num?)?.toDouble(),
      heightCm: (json['heightCm'] as num?)?.toDouble(),
      allergies: json['allergies']?.toString(),
      medicalHistory: json['medicalHistory']?.toString(),
      gestationalWeeks: json['gestationalWeeks'] is num ? (json['gestationalWeeks'] as num).toInt() : null,
      gestationalDays: json['gestationalDays'] is num ? (json['gestationalDays'] as num).toInt() : null,
      para: json['para']?.toString(),
      lmp: json['lmp']?.toString(),
      edd: json['edd']?.toString(),
      obstetricHistory: json['obstetricHistory']?.toString(),
      menstrualCycle: json['menstrualCycle']?.toString(),
      contraceptiveMethod: json['contraceptiveMethod']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'phone': phone,
      'dob': dob,
      'gender': gender,
      'address': address,
      'nationalId': nationalId,
      'bloodGroup': bloodGroup,
      'rhFactor': rhFactor,
      'prePregnancyWeight': prePregnancyWeight,
      'heightCm': heightCm,
      'allergies': allergies,
      'medicalHistory': medicalHistory,
      'gestationalWeeks': gestationalWeeks,
      'gestationalDays': gestationalDays,
      'para': para,
      'lmp': lmp,
      'edd': edd,
      'obstetricHistory': obstetricHistory,
      'menstrualCycle': menstrualCycle,
      'contraceptiveMethod': contraceptiveMethod,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  PatientModel copyWith({
    String? id,
    String? fullName,
    String? phone,
    String? dob,
    String? gender,
    String? address,
    String? nationalId,
    String? bloodGroup,
    String? rhFactor,
    double? prePregnancyWeight,
    double? heightCm,
    String? allergies,
    String? medicalHistory,
    int? gestationalWeeks,
    int? gestationalDays,
    String? para,
    String? lmp,
    String? edd,
    String? obstetricHistory,
    String? menstrualCycle,
    String? contraceptiveMethod,
    DateTime? createdAt,
  }) {
    return PatientModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      dob: dob ?? this.dob,
      gender: gender ?? this.gender,
      address: address ?? this.address,
      nationalId: nationalId ?? this.nationalId,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      rhFactor: rhFactor ?? this.rhFactor,
      prePregnancyWeight: prePregnancyWeight ?? this.prePregnancyWeight,
      heightCm: heightCm ?? this.heightCm,
      allergies: allergies ?? this.allergies,
      medicalHistory: medicalHistory ?? this.medicalHistory,
      gestationalWeeks: gestationalWeeks ?? this.gestationalWeeks,
      gestationalDays: gestationalDays ?? this.gestationalDays,
      para: para ?? this.para,
      lmp: lmp ?? this.lmp,
      edd: edd ?? this.edd,
      obstetricHistory: obstetricHistory ?? this.obstetricHistory,
      menstrualCycle: menstrualCycle ?? this.menstrualCycle,
      contraceptiveMethod: contraceptiveMethod ?? this.contraceptiveMethod,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
