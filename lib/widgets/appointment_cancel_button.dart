import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/appointment_model.dart';
import '../providers/history_provider.dart';
import '../providers/home_provider.dart';
import '../providers/booking_provider.dart';
import '../core/utils/hospital_time.dart';

class AppointmentCancelButton extends StatelessWidget {
  final AppointmentModel appointment;
  const AppointmentCancelButton({super.key, required this.appointment});

  Future<void> _confirm(BuildContext context) async {
    final history = context.read<HistoryProvider>();
    final home = context.read<HomeProvider>();
    final booking = context.read<BookingProvider>();
    final confirmed = await showDialog<String>(
      context: context,
      builder: (_) => _CancellationDialog(appointment: appointment),
    );
    if (confirmed == null || !context.mounted) return;
    final saved = await history.cancelAppointment(
      appointment.id,
      reason: confirmed,
    );
    if (!context.mounted) return;
    if (saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã hủy lịch hẹn. Bạn có thể đặt lại lịch.'),
        ),
      );
      await home.loadHomeData(isRefresh: true);
      booking.resetBooking();
      await booking.initBooking();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            history.errorMessage ??
                'Chưa hủy được lịch. Vui lòng tải lại lịch sử.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!appointment.canCancel) return const SizedBox.shrink();
    final busy = context.select<HistoryProvider, bool>(
      (provider) => provider.cancellingAppointmentId != null,
    );
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        onPressed: busy ? null : () => _confirm(context),
        icon: const Icon(Icons.event_busy_outlined, size: 18),
        label: Text(busy ? 'Đang xử lý…' : 'Hủy lịch hẹn'),
      ),
    );
  }
}

class _CancellationDialog extends StatefulWidget {
  final AppointmentModel appointment;
  const _CancellationDialog({required this.appointment});
  @override
  State<_CancellationDialog> createState() => _CancellationDialogState();
}

class _CancellationDialogState extends State<_CancellationDialog> {
  final _reason = TextEditingController();
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Hủy lịch hẹn?'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${widget.appointment.serviceTypeName}\n${hospitalTime(widget.appointment.scheduledTime)}',
          ),
          const SizedBox(height: 12),
          const Text(
            'Chỗ trong ca trực sẽ được trả lại. Phiếu tái khám liên quan có thể dùng để đặt lại.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reason,
            maxLength: 500,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Lý do (không bắt buộc)',
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Giữ lịch'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(_reason.text.trim()),
        child: const Text('Xác nhận hủy'),
      ),
    ],
  );
}
