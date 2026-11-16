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

Future<bool?> showMedicalPaymentReminder(
  BuildContext context, {
  required String encounterId,
  required String patientId,
  required String orderId,
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
          'và thu phí $serviceName. Sau khi thanh toán, quay lại phòng dịch vụ theo lộ trình.'
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

  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _MedicalQrDialog(
      encounterId: encounterId,
      patientId: patientId,
      orderId: orderId,
      serviceName: serviceName,
      paymentService: paymentService,
    ),
  );
}

class _MedicalQrDialog extends StatefulWidget {
  final String encounterId;
  final String patientId;
  final String orderId;
  final String serviceName;
  final MedicalPaymentService? paymentService;

  const _MedicalQrDialog({
    required this.encounterId,
    required this.patientId,
    required this.orderId,
    required this.serviceName,
    this.paymentService,
  });

  @override
  State<_MedicalQrDialog> createState() => _MedicalQrDialogState();
}

class _MedicalQrDialogState extends State<_MedicalQrDialog> {
  late final MedicalPaymentService _service;
  MedicalPaymentLink? _link;
  Timer? _expiryTimer;
  String? _error;
  bool _busy = false;
  bool _settled = false;
  bool _unavailable = false;

  @override
  void initState() {
    super.initState();
    _service = widget.paymentService ?? MedicalPaymentService();
    unawaited(_update());
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    if (widget.paymentService == null) _service.close();
    super.dispose();
  }

  Future<void> _update({bool check = false}) async {
    if (_busy || _settled || _unavailable) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final link = check
          ? await _service.checkLink(
              widget.encounterId,
              widget.patientId,
              widget.orderId,
              _link!.orderCode,
            )
          : await _service.createLink(
              widget.encounterId,
              widget.patientId,
              widget.orderId,
            );
      if (!mounted) return;
      setState(() {
        _link = link;
        _settled = link.isPaid;
      });
      _expiryTimer?.cancel();
      if (link.isPayable) {
        _expiryTimer = Timer(link.expiresAt.difference(DateTime.now()), () {
          if (mounted) setState(() {});
        });
      }
    } catch (error) {
      if (!mounted) return;
      final codes = error is ApiException ? error.codes : <String>{};
      setState(() {
        _settled = codes.contains('ALREADY_PAID');
        _unavailable = codes.contains('ITEM_NOT_BILLABLE');
        if (!_settled) {
          _error = _unavailable
              ? 'Chỉ định này hiện không có khoản phí để thanh toán.'
              : patientErrorMessage(
                  error,
                  fallback: 'Chưa xác minh được thanh toán.',
                );
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
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
          if (_settled)
            const Text('Đã xác nhận thanh toán. Hãy tiếp tục theo lộ trình.'),
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
            const Text('Sau khi chuyển khoản, bấm Kiểm tra thanh toán.'),
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
          onPressed: _busy ? null : () => Navigator.pop(context, _settled),
          child: const Text('Đóng'),
        ),
        if (!_settled && !_unavailable && link != null)
          OutlinedButton(
            onPressed: _busy ? null : () => _update(check: true),
            child: const Text('Kiểm tra thanh toán'),
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
