import '../core/network/api_client.dart';
import '../core/network/api_exceptions.dart';
import 'patient_session_service.dart';

typedef MedicalPaymentOrder = ({String id, String name});

class MedicalPaymentLink {
  final int orderCode;
  final num amount;
  final num? paidAmount;
  final String status;
  final String? qrCode;
  final Uri? checkoutUrl;
  final DateTime expiresAt;

  MedicalPaymentLink._(Map<String, dynamic> data)
    : orderCode = data['orderCode'] as int,
      amount = data['amount'] as num,
      paidAmount = data['paidAmount'] as num?,
      status = data['status'] as String,
      qrCode = data['qrCode'] as String?,
      checkoutUrl = Uri.tryParse(data['checkoutUrl'] as String? ?? ''),
      expiresAt = DateTime.parse(data['expiresAt'] as String);

  bool get isPaid => status == 'Paid';
  bool get isPayable =>
      status == 'Pending' && expiresAt.isAfter(DateTime.now());
}

class MedicalPaymentService {
  final ApiClient _api;
  MedicalPaymentService({ApiClient? api}) : _api = api ?? ApiClient();

  void close() => _api.close();

  String _visit(String encounterId) =>
      '/encounters/${Uri.encodeComponent(encounterId)}';

  void _requirePatient(String patientId) {
    final session = PatientSessionService();
    if (!session.isAuthenticated ||
        session.isDemo ||
        session.patientId != patientId) {
      throw ForbiddenException();
    }
  }

  Future<Map<String, double>> getOutstandingMedicalOrders(
    String encounterId,
    String patientId,
  ) async {
    _requirePatient(patientId);
    final session = PatientSessionService().version;
    final response = await _api.get<Map<String, dynamic>>(
      '${_visit(encounterId)}/billing',
    );
    if (session != PatientSessionService().version) {
      throw SessionChangedException();
    }
    _requirePatient(patientId);
    final data = response.data;
    final items = data?['items'];
    if (data?['encounterId'] != encounterId || items is! List) {
      throw ApiException('Bảng kê không khớp lượt khám đang mở.');
    }

    final outstandingByOrder = <String, double>{};
    for (final item in items) {
      if (item is! Map<String, dynamic>) {
        throw ApiException('Bảng kê thanh toán không hợp lệ.');
      }
      if (!['MedicalOrder', 'PreExamOrder'].contains(item['purpose'])) continue;
      final id = item['referenceId'];
      final amount = item['outstanding'];
      final settled = item['isSettled'];
      final payableBeforeService = item['payBeforeService'];
      if (id is! String ||
          id.isEmpty ||
          amount is! num ||
          !amount.isFinite ||
          amount < 0 ||
          settled is! bool ||
          payableBeforeService is! bool) {
        throw ApiException('Khoản phí cận lâm sàng không hợp lệ.');
      }
      if (payableBeforeService && !settled && amount > 0) {
        outstandingByOrder[id] = amount.toDouble();
      }
    }
    return outstandingByOrder;
  }

  Future<MedicalPaymentLink> createLink(
    String encounterId,
    String patientId,
    List<String> orderIds,
  ) async {
    _requirePatient(patientId);
    final response = await _api.post<Map<String, dynamic>>(
      '${_visit(encounterId)}/payos/payment-links',
      body: {'purpose': 'Paraclinical', 'orderIds': orderIds},
    );
    _requirePatient(patientId);
    return _readLink(response.data, encounterId, orderIds);
  }

  Future<MedicalPaymentLink> checkLink(
    String encounterId,
    String patientId,
    List<String> orderIds,
    int orderCode,
  ) async {
    _requirePatient(patientId);
    final response = await _api.get<Map<String, dynamic>>(
      '/payos/payment-links/$orderCode',
    );
    _requirePatient(patientId);
    return _readLink(
      response.data,
      encounterId,
      orderIds,
      expectedCode: orderCode,
    );
  }

  MedicalPaymentLink _readLink(
    Map<String, dynamic>? data,
    String encounterId,
    List<String> orderIds, {
    int? expectedCode,
  }) {
    final returnedIds = data?['orderIds'];
    if (data == null ||
        data['encounterId'] != encounterId ||
        data['purpose'] != 'Paraclinical' ||
        returnedIds is! List ||
        returnedIds.length != orderIds.length ||
        !returnedIds.toSet().containsAll(orderIds) ||
        data['orderCode'] is! int ||
        (expectedCode != null && data['orderCode'] != expectedCode) ||
        data['amount'] is! num ||
        (data['amount'] as num) <= 0 ||
        !['Pending', 'Paid', 'Cancelled', 'Expired'].contains(data['status'])) {
      throw ApiException(
        'Máy chủ chưa xác nhận mã thanh toán của chỉ định này.',
      );
    }
    try {
      return MedicalPaymentLink._(data);
    } on FormatException {
      throw ApiException('Thông tin mã thanh toán không hợp lệ.');
    } on TypeError {
      throw ApiException('Thông tin mã thanh toán không hợp lệ.');
    }
  }
}
