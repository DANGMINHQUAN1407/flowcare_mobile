import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/network/api_exceptions.dart';
import '../core/utils/hospital_time.dart';
import '../services/medical_payment_service.dart';

String formatMedicalPaymentAmount(num amount) => NumberFormat.currency(
  locale: 'vi_VN',
  symbol: '₫',
  decimalDigits: 0,
).format(amount);

typedef MedicalPaymentResult = ({
  num? transferredAmount,
  int? orderCode,
  bool billChanged,
});

Future<MedicalPaymentResult?> showMedicalPaymentReminder(
  BuildContext context, {
  required String encounterId,
  required String patientId,
  required List<String> orderIds,
  required String serviceName,
  required double outstanding,
  MedicalPaymentService? paymentService,
}) async {
  final payOnline = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Thanh toán trước khi thực hiện cận lâm sàng'),
      content: Text(
        'Bạn cần thanh toán khoản còn thiếu trước khi thực hiện $serviceName.\n\n'
        'Còn phải trả: ${formatMedicalPaymentAmount(outstanding)}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Đóng'),
        ),
        OutlinedButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Quay lại quầy lễ tân'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Thanh toán QR'),
        ),
      ],
    ),
  );
  if (payOnline == null || !context.mounted) return null;
  if (!payOnline) {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thanh toán tại quầy lễ tân'),
        content: Text(
          'Quay lại quầy lễ tân và cung cấp mã lượt khám '
          '${encounterId.split('-').first.toUpperCase()} để nhân viên kiểm tra '
          'và thu tổng $serviceName. Sau khi thanh toán, quay lại phòng dịch vụ theo lộ trình.'
          '\n\nCòn phải trả: ${formatMedicalPaymentAmount(outstanding)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
    return null;
  }

  return showDialog<MedicalPaymentResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _MedicalQrDialog(
      encounterId: encounterId,
      patientId: patientId,
      orderIds: orderIds,
      serviceName: serviceName,
      paymentService: paymentService,
    ),
  );
}

class _MedicalQrDialog extends StatefulWidget {
  final String encounterId;
  final String patientId;
  final List<String> orderIds;
  final String serviceName;
  final MedicalPaymentService? paymentService;

  const _MedicalQrDialog({
    required this.encounterId,
    required this.patientId,
    required this.orderIds,
    required this.serviceName,
    this.paymentService,
  });

  @override
  State<_MedicalQrDialog> createState() => _MedicalQrDialogState();
}

class _MedicalQrDialogState extends State<_MedicalQrDialog>
    with WidgetsBindingObserver {
  late final MedicalPaymentService _service;
  MedicalPaymentLink? _link;
  Timer? _expiryTimer;
  Timer? _pollTimer;
  String? _error;
  bool _busy = false;
  bool _polling = false;
  bool _settled = false;
  bool _unavailable = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _service = widget.paymentService ?? MedicalPaymentService();
    unawaited(_update());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _expiryTimer?.cancel();
    _pollTimer?.cancel();
    if (widget.paymentService == null) _service.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_pollStatus());
    }
  }

  void _completePayment({num? amount, bool billChanged = false}) {
    if (_settled) return;
    _expiryTimer?.cancel();
    _pollTimer?.cancel();
    _settled = true;
    if (mounted && ModalRoute.of(context)?.isCurrent == true) {
      Navigator.of(context).pop<MedicalPaymentResult>((
        transferredAmount: amount,
        orderCode: _link?.orderCode,
        billChanged: billChanged,
      ));
    }
  }

  void _schedulePoll() {
    _pollTimer?.cancel();
    final link = _link;
    if (!mounted ||
        _settled ||
        _unavailable ||
        link == null ||
        !link.isPayable) {
      return;
    }
    _pollTimer = Timer(const Duration(seconds: 3), () {
      unawaited(_pollStatus());
    });
  }

  Future<void> _pollStatus() async {
    final current = _link;
    if (!mounted ||
        _busy ||
        _polling ||
        _settled ||
        _unavailable ||
        current == null ||
        current.status != 'Pending') {
      return;
    }
    _polling = true;
    try {
      final next = await _service.checkLink(
        widget.encounterId,
        widget.patientId,
        widget.orderIds,
        current.orderCode,
      );
      if (!mounted || _settled) return;
      if (next.isPaid) {
        _link = next;
        _completePayment(amount: next.paidAmount ?? next.amount);
        return;
      }
      setState(() {
        _link = next;
        _error = null;
      });
      if (next.isPayable) {
        _schedulePoll();
      }
    } catch (error) {
      if (!mounted || _settled) return;
      final codes = error is ApiException ? error.codes : <String>{};
      if (codes.contains('ALREADY_PAID')) {
        _completePayment();
        return;
      }
      if (codes.contains('ITEM_NOT_BILLABLE')) {
        setState(() {
          _unavailable = true;
          _error = 'Chỉ định này hiện không có khoản phí để thanh toán.';
        });
        return;
      }
      if (_link?.isPayable == true) {
        _schedulePoll();
      }
    } finally {
      _polling = false;
    }
  }

  Future<void> _update() async {
    if (_busy || _polling || _settled || _unavailable) return;
    _pollTimer?.cancel();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final link = await _service.createLink(
        widget.encounterId,
        widget.patientId,
        widget.orderIds,
      );
      if (!mounted) return;
      if (link.isPaid) {
        _link = link;
        _completePayment(amount: link.paidAmount ?? link.amount);
        return;
      }
      setState(() {
        _link = link;
        _settled = false;
      });
      _expiryTimer?.cancel();
      if (link.isPayable) {
        _expiryTimer = Timer(link.expiresAt.difference(DateTime.now()), () {
          _pollTimer?.cancel();
          if (mounted) {
            setState(() {});
            unawaited(_pollStatus());
          }
        });
        _schedulePoll();
      }
    } catch (error) {
      if (!mounted) return;
      final codes = error is ApiException ? error.codes : <String>{};
      if (codes.contains('ALREADY_PAID')) {
        _completePayment();
        return;
      }
      if (codes.contains('PAYMENT_CHANGED')) {
        _completePayment(billChanged: true);
        return;
      }
      setState(() {
        _unavailable = codes.contains('ITEM_NOT_BILLABLE');
        _error = _unavailable
            ? 'Chỉ định này hiện không có khoản phí để thanh toán.'
            : patientErrorMessage(
                error,
                fallback: 'Chưa xác minh được thanh toán.',
              );
      });
    } finally {
      if (mounted && !_settled) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final link = _link;
    final isPayable = link?.isPayable == true && !_settled && !_unavailable;
    final checkout = link?.checkoutUrl;
    final trustedCheckout =
        checkout?.scheme == 'https' &&
        checkout?.host == 'pay.payos.vn' &&
        checkout?.userInfo.isEmpty == true;
    return AlertDialog(
      scrollable: true,
      title: const Text('Thanh toán QR PayOS'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.serviceName),
          if (_busy) const LinearProgressIndicator(),
          if (isPayable && link != null) ...[
            Text(
              'Số tiền thanh toán: ${formatMedicalPaymentAmount(link.amount)}',
            ),
            if (link.qrCode case final qr? when qr.isNotEmpty)
              Center(
                child: SizedBox.square(
                  dimension: 200,
                  child: QrImageView(
                    data: qr,
                    backgroundColor: Colors.white,
                    semanticsLabel: 'Mã VietQR thanh toán',
                  ),
                ),
              ),
            Text(
              'Mã có hiệu lực đến ${hospitalTime(link.expiresAt, pattern: 'HH:mm dd/MM')}.',
            ),
            if (trustedCheckout)
              TextButton(
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: checkout.toString()),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đã sao chép liên kết PayOS.'),
                      ),
                    );
                  }
                },
                child: const Text('Sao chép liên kết PayOS'),
              ),
            const Text(
              'Hệ thống sẽ tự động xác nhận ngay sau khi bạn chuyển khoản thành công.',
            ),
          ],
          if (link != null && !isPayable && !_settled && !_unavailable)
            Text(
              link.status == 'Cancelled'
                  ? 'Mã QR đã hủy.'
                  : 'Mã QR đã hết hạn.',
            ),
          if (_error != null) ...[
            Text(_error!),
            if (!_unavailable)
              const Text(
                'Bạn có thể quay lại quầy lễ tân để kiểm tra và thanh toán.',
              ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Đóng'),
        ),
        if (!_settled && !_unavailable && !isPayable)
          FilledButton(
            onPressed: _busy ? null : () => _update(),
            child: const Text('Lấy mã QR'),
          ),
      ],
    );
  }
}
