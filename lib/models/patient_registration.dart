import '../core/network/api_exceptions.dart';

class PatientRegistration {
  final String fullName, phone, password;
  final DateTime? dob;

  const PatientRegistration({
    required this.fullName,
    required this.phone,
    required this.password,
    this.dob,
  });

  static String? nameError(String? value) {
    final length = value?.trim().length ?? 0;
    return length >= 2 && length <= 150
        ? null
        : 'Nhập họ tên từ 2 đến 150 ký tự.';
  }

  static String? phoneError(String? value) {
    final phone = value?.trim() ?? '';
    return phone.length <= 20 && RegExp(r'^\+?[0-9]{8,20}$').hasMatch(phone)
        ? null
        : 'Nhập số điện thoại hợp lệ, từ 8 đến 20 ký tự.';
  }

  static String? passwordError(String? value) {
    final password = value ?? '';
    return password.trim().isNotEmpty &&
            password.length >= 8 &&
            password.length <= 256
        ? null
        : 'Mật khẩu cần từ 8 đến 256 ký tự.';
  }

  Map<String, dynamic> toJson() {
    final error =
        nameError(fullName) ?? phoneError(phone) ?? passwordError(password);
    if (error != null) throw ValidationException(error);
    final today = DateTime.now();
    if (dob != null && (dob!.year < 1900 || dob!.isAfter(today))) {
      throw ValidationException('Ngày sinh không hợp lệ.');
    }
    return {
      'userName': phone.trim(),
      'password': password,
      'fullName': fullName.trim(),
      'phone': phone.trim(),
      if (dob != null)
        'dob':
            '${dob!.year.toString().padLeft(4, '0')}-'
            '${dob!.month.toString().padLeft(2, '0')}-'
            '${dob!.day.toString().padLeft(2, '0')}',
    };
  }
}
