import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/booking_provider.dart';
import '../../services/patient_session_service.dart';
import '../../providers/history_provider.dart';
import '../../providers/home_provider.dart';
import '../../widgets/error_state_widget.dart';
import '../../widgets/loading_state_widget.dart';

class BookingScreen extends StatefulWidget {
  final void Function(int tabIndex)? onNavigateToTab;

  const BookingScreen({super.key, this.onNavigateToTab});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final TextEditingController _fullNameCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _nationalIdCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();
  int _currentStep = 0; // 0: Dịch vụ & Người khám | 1: Ngày & Giờ khám | 2: Xác nhận & Đặt lịch

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bookingProvider = Provider.of<BookingProvider>(
        context,
        listen: false,
      );
      if (_fullNameCtrl.text.isEmpty && bookingProvider.fullName.isNotEmpty) {
        _fullNameCtrl.text = bookingProvider.fullName;
      }
      if (_phoneCtrl.text.isEmpty && bookingProvider.phone.isNotEmpty) {
        _phoneCtrl.text = bookingProvider.phone;
      }
      if (_nationalIdCtrl.text.isEmpty &&
          (bookingProvider.nationalId?.isNotEmpty ?? false)) {
        _nationalIdCtrl.text = bookingProvider.nationalId!;
      }
      if (_addressCtrl.text.isEmpty &&
          (bookingProvider.address?.isNotEmpty ?? false)) {
        _addressCtrl.text = bookingProvider.address!;
      }
      if (bookingProvider.services.isEmpty && !bookingProvider.isLoading) {
        bookingProvider.initBooking();
      }
    });
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _phoneCtrl.dispose();
    _nationalIdCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  String _formatWeekdayShort(DateTime date) {
    const weekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    return weekdays[date.weekday - 1];
  }

  String _formatDateFull(DateTime date) {
    const weekdays = [
      'Thứ 2',
      'Thứ 3',
      'Thứ 4',
      'Thứ 5',
      'Thứ 6',
      'Thứ 7',
      'Chủ Nhật',
    ];
    final formatted = DateFormat('dd/MM/yyyy').format(date);
    return '$formatted (${weekdays[date.weekday - 1]})';
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat('#,###', 'en_US');
    return '${formatter.format(amount.toInt())} đ';
  }

  Widget _buildStepIndicator() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildStepBadge(0, '1', 'Dịch vụ'),
          _buildStepConnector(0),
          _buildStepBadge(1, '2', 'Thời gian'),
          _buildStepConnector(1),
          _buildStepBadge(2, '3', 'Xác nhận'),
        ],
      ),
    );
  }

  Widget _buildStepBadge(int stepIndex, String number, String label) {
    final isActive = _currentStep == stepIndex;
    final isDone = _currentStep > stepIndex;

    return InkWell(
      onTap: () {
        // Allow going back to previous completed steps
        if (stepIndex < _currentStep) {
          setState(() => _currentStep = stepIndex);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: isDone
                  ? AppColors.secondary
                  : (isActive ? AppColors.primary : AppColors.surfaceVariant),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: isDone
                ? const Icon(Icons.check, color: Colors.white, size: 15)
                : Text(
                    number,
                    style: TextStyle(
                      color: isActive ? Colors.white : AppColors.textSecondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
              color: isActive
                  ? AppColors.primary
                  : (isDone ? AppColors.textPrimary : AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepConnector(int beforeIndex) {
    final isPassed = _currentStep > beforeIndex;
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        color: isPassed ? AppColors.secondary : AppColors.border,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Đặt lịch khám trực tuyến',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              'Bệnh viện Phụ Sản Thông Minh FlowCare',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Consumer<BookingProvider>(
          builder: (context, bookingProvider, child) {
            if (PatientSessionService().isDemo) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Chức năng đặt lịch cần đăng nhập bằng tài khoản bệnh nhân.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            // 1. Loading State
            if (bookingProvider.isLoading) {
              return const LoadingStateWidget(
                message: 'Đang tải danh mục dịch vụ khám & lịch hẹn...',
              );
            }

            // 2. Global Error State
            if (bookingProvider.errorMessage != null &&
                bookingProvider.services.isEmpty) {
              return ErrorStateWidget(
                message: bookingProvider.errorMessage!,
                onRetry: () {
                  bookingProvider.initBooking();
                },
              );
            }

            // 3. Success State (Booking created)
            if (bookingProvider.bookingSuccessResult != null) {
              return _buildSuccessView(context, bookingProvider);
            }

            // 4. Booking Step Wizard Box View
            return Column(
              children: [
                // Top Progress Stepper
                _buildStepIndicator(),

                // Main Content Card
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _buildCurrentStepBox(context, bookingProvider),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCurrentStepBox(
    BuildContext context,
    BookingProvider bookingProvider,
  ) {
    switch (_currentStep) {
      case 0:
        return _buildStep1Box(context, bookingProvider);
      case 1:
        return _buildStep2Box(context, bookingProvider);
      case 2:
      default:
        return _buildStep3Box(context, bookingProvider);
    }
  }

  // --- STEP 1 BOX: Người khám & Dịch vụ ---
  Widget _buildStep1Box(BuildContext context, BookingProvider bookingProvider) {
    return Column(
      key: const ValueKey('step_1_box'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Booking Type Switcher (Khám Mới vs Tái Khám)
        _buildBookingTypeSelector(bookingProvider),
        const SizedBox(height: 14),

        if (bookingProvider.followUpError != null) ...[
          Text(
            'Lịch tái khám: ${bookingProvider.followUpError}',
            style: const TextStyle(color: AppColors.emergency),
          ),
          const SizedBox(height: 12),
        ],
        // If in Follow-Up mode, show Follow-Up Context Banner
        if (bookingProvider.isFollowUp) ...[
          _buildFollowUpContextCard(bookingProvider),
          const SizedBox(height: 14),
        ],

        // Step 1: Thông tin người khám bệnh
        _buildStepHeader(
          stepNumber: '1',
          title: 'Thông tin người khám bệnh',
          subtitle: 'Họ tên và số điện thoại để nhận mã phiếu khám',
        ),
        const SizedBox(height: 10),
        _buildPatientInfoInputSection(bookingProvider),
        const SizedBox(height: 18),

        // Step 2: Chọn phân nhóm chuyên khoa Sản - Phụ khoa
        _buildStepHeader(
          stepNumber: '2',
          title: 'Chọn nhóm dịch vụ khám',
          subtitle: 'Phân loại theo nhu cầu chăm sóc mẹ & bé',
        ),
        const SizedBox(height: 10),
        _buildCategorySelector(bookingProvider),
        const SizedBox(height: 12),
        _buildServiceSection(bookingProvider),
        const SizedBox(height: 22),

        // Next to Step 2 Button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: () {
              if (bookingProvider.fullName.trim().isEmpty ||
                  bookingProvider.phone.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Vui lòng nhập họ tên và số điện thoại liên hệ!',
                    ),
                    backgroundColor: Colors.orange,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              if (bookingProvider.selectedService == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Vui lòng chọn dịch vụ khám!'),
                    backgroundColor: Colors.orange,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              setState(() => _currentStep = 1);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: const Text(
              'Tiếp tục: Chọn thời gian khám',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  // --- STEP 2 BOX: Ngày & Khung giờ khám ---
  Widget _buildStep2Box(BuildContext context, BookingProvider bookingProvider) {
    return Column(
      key: const ValueKey('step_2_box'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Step 1: Chọn ngày khám
        _buildStepHeader(
          stepNumber: '1',
          title: 'Chọn ngày khám',
          subtitle: 'Đặt hẹn trước tối thiểu 1 ngày (14 ngày tới)',
        ),
        const SizedBox(height: 10),
        _buildDateSelector(context, bookingProvider),
        const SizedBox(height: 18),

        // Step 2: Chọn khung giờ khả dụng
        _buildStepHeader(
          stepNumber: '2',
          title: 'Chọn khung giờ khám',
          subtitle: 'Các khung giờ còn trống được cập nhật từ viện',
        ),
        const SizedBox(height: 10),
        _buildSlotsSection(bookingProvider),
        const SizedBox(height: 22),

        // Navigation Row (Quay lại / Tiếp tục)
        Row(
          children: [
            Expanded(
              flex: 1,
              child: SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _currentStep = 0),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text(
                    'Quay lại',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (bookingProvider.selectedSlot == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Vui lòng chọn một khung giờ khám khả dụng!',
                          ),
                          backgroundColor: Colors.orange,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }
                    setState(() => _currentStep = 2);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text(
                    'Tiếp tục: Xem xác nhận',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- STEP 3 BOX: Xác nhận & Đặt lịch ---
  Widget _buildStep3Box(BuildContext context, BookingProvider bookingProvider) {
    return Column(
      key: const ValueKey('step_3_box'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary Card
        _buildSummaryCard(bookingProvider),
        const SizedBox(height: 14),

        // Ghi chú cho Bác sĩ (Tùy chọn)
        _buildStepHeader(
          stepNumber: '+',
          title: 'Ghi chú cho Bác sĩ (Tùy chọn)',
          subtitle:
              'Nhập lý do khám hoặc triệu chứng để Bác sĩ chuẩn bị chu đáo hơn',
        ),
        const SizedBox(height: 10),
        _buildSpecialtyContextSection(context, bookingProvider),
        const SizedBox(height: 18),

        // Submit Error Banner
        if (bookingProvider.errorMessage != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.emergencyLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.emergency.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.emergency,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    bookingProvider.errorMessage!,
                    style: const TextStyle(
                      color: AppColors.emergency,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Navigation Row (Quay lại / Xác nhận)
        Row(
          children: [
            Expanded(
              flex: 1,
              child: SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _currentStep = 1),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text(
                    'Quay lại',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed:
                      bookingProvider.canSubmit && !bookingProvider.isSubmitting
                      ? () async {
                          final success = await bookingProvider.submitBooking();
                          if (success && context.mounted) {
                            final homeProvider = Provider.of<HomeProvider>(
                              context,
                              listen: false,
                            );
                            final historyProvider =
                                Provider.of<HistoryProvider>(
                                  context,
                                  listen: false,
                                );
                            homeProvider.loadHomeData(isRefresh: true);
                            historyProvider.loadAppointments(
                              bookingProvider.patient?.id,
                              isRefresh: true,
                            );
                          } else if (!success && context.mounted) {
                            final errorMsg =
                                bookingProvider.errorMessage ??
                                'Không thể đặt lịch khám. Vui lòng kiểm tra lại!';
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(errorMsg),
                                backgroundColor: Colors.red.shade700,
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0077C8),
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: bookingProvider.isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 20,
                        ),
                  label: Text(
                    bookingProvider.isSubmitting
                        ? 'Đang gửi yêu cầu...'
                        : 'Xác nhận đặt lịch',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildBookingTypeSelector(BookingProvider bookingProvider) {
    final pendingOrders = bookingProvider.pendingFollowUpOrders;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () {
                if (bookingProvider.isFollowUp) {
                  bookingProvider.clearFollowUp();
                }
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: !bookingProvider.isFollowUp
                      ? AppColors.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_circle_outline_rounded,
                      size: 16,
                      color: !bookingProvider.isFollowUp
                          ? Colors.white
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Khám mới',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: !bookingProvider.isFollowUp
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: !bookingProvider.isFollowUp
                            ? Colors.white
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: InkWell(
              onTap: () {
                if (!bookingProvider.isFollowUp) {
                  if (pendingOrders.isNotEmpty) {
                    bookingProvider.setupFollowUpFromOrder(pendingOrders.first);
                  } else {
                    bookingProvider.setIsFollowUp(true);
                  }
                }
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: bookingProvider.isFollowUp
                      ? const Color(0xFF0077C8)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.sync_rounded,
                      size: 16,
                      color: bookingProvider.isFollowUp
                          ? Colors.white
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Tái khám theo hẹn',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: bookingProvider.isFollowUp
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: bookingProvider.isFollowUp
                            ? Colors.white
                            : AppColors.textSecondary,
                      ),
                    ),
                    if (pendingOrders.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: bookingProvider.isFollowUp
                              ? Colors.white
                              : AppColors.secondary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${pendingOrders.length}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: bookingProvider.isFollowUp
                                ? const Color(0xFF0077C8)
                                : Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowUpContextCard(BookingProvider bookingProvider) {
    final doctorName =
        bookingProvider.originalDoctorName ?? 'Bác sĩ chuyên khoa theo dõi';
    final diagnosis =
        bookingProvider.previousDiagnosis ??
        'Tái khám định kỳ theo hẹn của Bác sĩ';
    final targetDate = bookingProvider.recommendedFollowUpDate;
    final dateStr = targetDate != null
        ? DateFormat('dd/MM/yyyy').format(targetDate)
        : null;
    final pendingOrders = bookingProvider.pendingFollowUpOrders;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEBF5FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF0077C8).withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0077C8).withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0077C8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.sync_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CHẾ ĐỘ TÁI KHÁM / THEO HẸN',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF005BAC),
                        letterSpacing: 0.3,
                      ),
                    ),
                    Text(
                      'Ưu tiên giữ liên kết hồ sơ y tế & Bác sĩ điều trị',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () => bookingProvider.clearFollowUp(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Text(
                    'Đổi sang khám mới',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.person_rounded,
                size: 16,
                color: Color(0xFF005BAC),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Bác sĩ điều trị trước: $doctorName',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.assignment_outlined,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Chẩn đoán trước: $diagnosis',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          if (dateStr != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF0077C8).withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.event_available_rounded,
                    size: 14,
                    color: Color(0xFF005BAC),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Ngày bác sĩ hẹn: $dateStr',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF005BAC),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (pendingOrders.length > 1) ...[
            const SizedBox(height: 10),
            const Text(
              'Chọn phiếu tái khám từ danh sách:',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: pendingOrders.map((ord) {
                final isCurrent = bookingProvider.followUpOrderId == ord.id;
                return ChoiceChip(
                  label: Text(
                    'Phiếu ${DateFormat('dd/MM').format(ord.targetDate)} - ${ord.originalDoctorName}',
                  ),
                  selected: isCurrent,
                  onSelected: (selected) {
                    if (selected) {
                      bookingProvider.setupFollowUpFromOrder(ord);
                    }
                  },
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStepHeader({
    required String stepNumber,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: Text(
            stepNumber,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPatientInfoInputSection(BookingProvider bookingProvider) {
    final patient = bookingProvider.patient;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hồ sơ của tài khoản đang đăng nhập',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(patient?.fullName ?? 'Chưa tải được hồ sơ bệnh nhân'),
          if (patient != null) ...[
            const SizedBox(height: 4),
            Text(patient.phone),
          ],
          const SizedBox(height: 8),
          const Text(
            'Lịch hẹn được tạo cho hồ sơ này. Đăng xuất nếu bạn cần dùng tài khoản khác.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector(BookingProvider bookingProvider) {
    final categories = [
      {
        'id': 'prenatal',
        'title': 'Khám thai',
        'subtitle': 'Quản lý thai kỳ & Mẹ bé',
        'icon': Icons.pregnant_woman_rounded,
        'color': AppColors.maternityPink,
        'bgColor': AppColors.maternityPinkLight,
      },
      {
        'id': 'gynecology',
        'title': 'Khám phụ khoa',
        'subtitle': 'Tầm soát & Viêm nhiễm',
        'icon': Icons.spa_rounded,
        'color': AppColors.primary,
        'bgColor': AppColors.primaryLight,
      },
      {
        'id': 'other',
        'title': 'Sản - Phụ khoa khác',
        'subtitle': 'Cận lâm sàng & Tiền sản',
        'icon': Icons.medical_services_outlined,
        'color': AppColors.secondary,
        'bgColor': AppColors.secondaryLight,
      },
    ];

    return Row(
      children: categories.map((cat) {
        final isSelected = bookingProvider.selectedCategory == cat['id'];
        final color = cat['color'] as Color;
        final bgColor = cat['bgColor'] as Color;

        return Expanded(
          child: InkWell(
            onTap: () =>
                bookingProvider.setSelectedCategory(cat['id'] as String),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              decoration: BoxDecoration(
                color: isSelected ? bgColor : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? color : AppColors.border,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(cat['icon'] as IconData, color: color, size: 22),
                  const SizedBox(height: 6),
                  Text(
                    cat['title'] as String,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w600,
                      color: isSelected ? color : AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildServiceSection(BookingProvider bookingProvider) {
    final services = bookingProvider.filteredServices;

    if (services.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: const Text(
          'Chưa có dịch vụ phù hợp trong nhóm này. Vui lòng chọn nhóm khác.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      children: services.map((service) {
        final isSelected = bookingProvider.selectedService?.id == service.id;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: InkWell(
            onTap: () => bookingProvider.selectService(service),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryLight : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isSelected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textTertiary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          service.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textPrimary,
                          ),
                        ),
                        if (service.description != null &&
                            service.description!.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            service.description!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (service.price != null)
                    Text(
                      _formatCurrency(service.price!),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.secondary,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSpecialtyContextSection(
    BuildContext context,
    BookingProvider bookingProvider,
  ) {
    final isPrenatal = bookingProvider.selectedCategory == 'prenatal';
    final isGyn = bookingProvider.selectedCategory == 'gynecology';

    final quickSuggestions = isPrenatal
        ? [
            'Khám thai định kỳ',
            'Đau bụng âm ỉ',
            'Nghén nhiều / Mệt mỏi',
            'Tái khám theo hẹn',
          ]
        : (isGyn
              ? [
                  'Khám phụ khoa định kỳ',
                  'Rối loạn kinh nguyệt',
                  'Viêm ngứa / Khó chịu',
                  'Tư vấn sức khỏe',
                ]
              : ['Khám định kỳ', 'Tư vấn sức khỏe', 'Tái khám']);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lý do khám hoặc triệu chứng khó chịu (nếu có):',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),

          // Gợi ý nhanh thân thiện cho bệnh nhân
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: quickSuggestions.map((sug) {
              return ActionChip(
                label: Text(
                  sug,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                backgroundColor: AppColors.primaryLight,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                side: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.2),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                onPressed: () {
                  final current = _notesCtrl.text.trim();
                  if (current.isEmpty) {
                    _notesCtrl.text = sug;
                  } else if (!current.contains(sug)) {
                    _notesCtrl.text = '$current, $sug';
                  }
                  bookingProvider.setClinicalNotes(_notesCtrl.text);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _notesCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText:
                  'Nhập thêm ghi chú hoặc triệu chứng cần bác sĩ lưu ý...',
              hintStyle: const TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
            onChanged: (val) => bookingProvider.setClinicalNotes(val),
          ),
          const SizedBox(height: 14),

          // Hướng dẫn y tế chuẩn mực đúng vai trò Bác sĩ chuyên khoa
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.health_and_safety_outlined,
                  size: 18,
                  color: Color(0xFF16A34A),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Các dữ liệu lâm sàng chi tiết (ngày kinh cuối LMP, tuổi thai, chỉ số PARA, tiền sử sản phụ khoa, siêu âm...) sẽ do Bác sĩ chuyên khoa trực tiếp thăm khám và ghi nhận vào hồ sơ bệnh án tại phòng khám.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF15803D),
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector(
    BuildContext context,
    BookingProvider bookingProvider,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Bắt đầu từ ngày mai (chỉ cho phép đặt từ ngày mai trở đi)
    final minDate = today.add(const Duration(days: 1));
    final selectedDate = bookingProvider.selectedDate;

    return Column(
      children: [
        SizedBox(
          height: 82,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 14,
            separatorBuilder: (_, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final date = minDate.add(Duration(days: index));
              final isSelected =
                  selectedDate.year == date.year &&
                  selectedDate.month == date.month &&
                  selectedDate.day == date.day;
              final isTomorrow = index == 0;

              return InkWell(
                onTap: () => bookingProvider.selectDate(date),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 62,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.border,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isTomorrow ? 'N.mai' : _formatWeekdayShort(date),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white70
                              : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('dd').format(date),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isSelected
                              ? Colors.white
                              : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('MM').format(date),
                        style: TextStyle(
                          fontSize: 10,
                          color: isSelected
                              ? Colors.white70
                              : AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSlotsSection(BookingProvider bookingProvider) {
    if (bookingProvider.isSlotsLoading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: const Column(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            SizedBox(height: 10),
            Text(
              'Đang tra cứu khung giờ trống...',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (bookingProvider.slotsErrorMessage != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.emergencyLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.emergency.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(
              bookingProvider.slotsErrorMessage!,
              style: const TextStyle(fontSize: 12, color: AppColors.emergency),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => bookingProvider.retrySlots(),
              child: const Text('Thử lại', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
    }

    if (bookingProvider.availableSlots.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: Text(
            'Không có khung giờ khám khả dụng trong ngày này. Vui lòng chọn ngày khác.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final hasAvailableSlot = bookingProvider.availableSlots.any(
      (s) => s.isAvailable,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!hasAvailableSlot)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: Colors.amber.shade900,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Các khung giờ hôm nay đã qua giờ khám thực tế. Vui lòng chọn ngày tiếp theo (ngày mai) để đặt lịch.',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: bookingProvider.availableSlots.map((slot) {
            final isSelected =
                bookingProvider.selectedSlot?.timeRange == slot.timeRange;
            final isAvailable = slot.isAvailable;

            return InkWell(
              onTap: isAvailable
                  ? () => bookingProvider.selectSlot(slot)
                  : null,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary
                      : (!isAvailable
                            ? Colors.grey.shade100
                            : AppColors.surface),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : (!isAvailable
                              ? Colors.grey.shade300
                              : AppColors.border),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isAvailable
                          ? Icons.access_time_rounded
                          : Icons.block_rounded,
                      size: 14,
                      color: isSelected
                          ? Colors.white
                          : (!isAvailable
                                ? Colors.grey.shade400
                                : AppColors.textSecondary),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      slot.timeRange,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : (!isAvailable
                                  ? Colors.grey.shade400
                                  : AppColors.textPrimary),
                        decoration: !isAvailable
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(BookingProvider bookingProvider) {
    final name = bookingProvider.fullName.trim().isNotEmpty
        ? bookingProvider.fullName.trim()
        : (bookingProvider.patient?.fullName ?? 'Chưa nhập họ tên');
    final phone = bookingProvider.phone.trim().isNotEmpty
        ? bookingProvider.phone.trim()
        : (bookingProvider.patient?.phone ?? 'Chưa nhập SĐT');
    final service = bookingProvider.selectedService;
    final date = bookingProvider.selectedDate;
    final slot = bookingProvider.selectedSlot;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tóm tắt thông tin đặt hẹn',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const Divider(height: 20),
          _buildSummaryRow(
            label: 'Bệnh nhân:',
            value: name,
            valueColor: name.startsWith('Chưa')
                ? AppColors.textTertiary
                : AppColors.textPrimary,
          ),
          const SizedBox(height: 8),
          _buildSummaryRow(
            label: 'Số điện thoại:',
            value: phone,
            valueColor: phone.startsWith('Chưa')
                ? AppColors.textTertiary
                : AppColors.textPrimary,
          ),
          const SizedBox(height: 8),
          _buildSummaryRow(
            label: 'Chuyên khoa:',
            value: bookingProvider.selectedCategory == 'prenatal'
                ? 'Khám thai & Quản lý thai kỳ'
                : (bookingProvider.selectedCategory == 'gynecology'
                      ? 'Khám phụ khoa & Tầm soát'
                      : 'Sản - Phụ khoa khác'),
            valueColor: AppColors.primary,
          ),
          const SizedBox(height: 8),
          _buildSummaryRow(
            label: 'Dịch vụ khám:',
            value: service?.name ?? 'Chưa chọn dịch vụ',
            valueColor: service != null
                ? AppColors.textPrimary
                : AppColors.textTertiary,
          ),
          const SizedBox(height: 8),
          _buildSummaryRow(label: 'Ngày khám:', value: _formatDateFull(date)),
          const SizedBox(height: 8),
          _buildSummaryRow(
            label: 'Khung giờ:',
            value: slot?.timeRange ?? 'Chưa chọn giờ',
            valueColor: slot != null
                ? AppColors.secondary
                : AppColors.textTertiary,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow({
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessView(
    BuildContext context,
    BookingProvider bookingProvider,
  ) {
    final result = bookingProvider.bookingSuccessResult!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AppColors.successLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: AppColors.success,
              size: 64,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Đặt lịch khám thành công!',
            style: AppTextStyles.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          const Text(
            'Lịch hẹn của quý khách đã được ghi nhận trên hệ thống tiếp đón Bệnh viện Phụ Sản FlowCare.',
            style: AppTextStyles.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Appointment Detail Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                _buildSummaryRow(
                  label: 'Mã lịch hẹn:',
                  value: result.id.length >= 8
                      ? result.id.substring(0, 8).toUpperCase()
                      : result.id,
                  valueColor: AppColors.primary,
                ),
                const Divider(height: 16),
                _buildSummaryRow(
                  label: 'Bệnh nhân:',
                  value: result.patientName,
                ),
                const SizedBox(height: 8),
                _buildSummaryRow(
                  label: 'Dịch vụ:',
                  value: result.serviceTypeName,
                ),
                const SizedBox(height: 8),
                _buildSummaryRow(
                  label: 'Thời gian khám:',
                  value: DateFormat('HH:mm - dd/MM/yyyy')
                      .format(result.scheduledTime),
                  valueColor: AppColors.secondary,
                ),
                const SizedBox(height: 8),
                _buildSummaryRow(
                  label: 'Hình thức tiếp đón:',
                  value: 'Tiếp đón ưu tiên AI',
                  valueColor: AppColors.success,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Action Buttons
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                bookingProvider.resetBooking();
                widget.onNavigateToTab?.call(0); // Return Home
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Về trang chủ',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: () {
                bookingProvider.resetBooking();
                widget.onNavigateToTab?.call(3); // Go to History
              },
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Xem sổ lịch hẹn',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
