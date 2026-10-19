import '../core/network/api_exceptions.dart';

class PatientRegistration {
  final String fullName, phone, password;
  final DateTime? dob;
  final String? registrationLinkCode;
  final bool isFromReception;

  const PatientRegistration({
    required this.fullName,
    required this.phone,
    required this.password,
    this.dob,
  }) : registrationLinkCode = null,
       isFromReception = false;

  const PatientRegistration.fromReception({
    required this.registrationLinkCode,
    required this.password,
  }) : fullName = '',
       phone = '',
       dob = null,
       isFromReception = true;

  static String normalizeLinkCode(String? value) =>
      (value ?? '').replaceAll(RegExp(r'[-\s]'), '').toUpperCase();

  static String? linkCodeError(String? value) =>
      RegExp(r'^[0-9A-F]{24}$').hasMatch(normalizeLinkCode(value))
      ? null
      : 'Nhập đủ mã liên kết 24 ký tự 0–9, A–F trên phiếu khám.';

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
    if (isFromReception) {
      final error =
          linkCodeError(registrationLinkCode) ?? passwordError(password);
      if (error != null) throw ValidationException(error);
      return {
        'registrationLinkCode': normalizeLinkCode(registrationLinkCode),
        'password': password,
      };
    }
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
