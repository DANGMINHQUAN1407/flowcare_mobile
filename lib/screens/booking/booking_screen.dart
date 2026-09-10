import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/booking_provider.dart';
import '../../providers/history_provider.dart';
import '../../providers/home_provider.dart';
import '../../widgets/error_state_widget.dart';
import '../../widgets/loading_state_widget.dart';

class BookingScreen extends StatefulWidget {
  final void Function(int tabIndex)? onNavigateToTab;

  const BookingScreen({
    super.key,
    this.onNavigateToTab,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final TextEditingController _fullNameCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
      if (_fullNameCtrl.text.isEmpty && bookingProvider.fullName.isNotEmpty) {
        _fullNameCtrl.text = bookingProvider.fullName;
      }
      if (_phoneCtrl.text.isEmpty && bookingProvider.phone.isNotEmpty) {
        _phoneCtrl.text = bookingProvider.phone;
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
    _notesCtrl.dispose();
    super.dispose();
  }

  String _formatWeekdayShort(DateTime date) {
    const weekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    return weekdays[date.weekday - 1];
  }

  String _formatDateFull(DateTime date) {
    const weekdays = ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'Chủ Nhật'];
    final formatted = DateFormat('dd/MM/yyyy').format(date);
    return '$formatted (${weekdays[date.weekday - 1]})';
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat('#,###', 'en_US');
    return '${formatter.format(amount.toInt())} đ';
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
            // 1. Loading State
            if (bookingProvider.isLoading) {
              return const LoadingStateWidget(
                message: 'Đang tải danh mục dịch vụ khám & lịch hẹn...',
              );
            }

            // 2. Global Error State
            if (bookingProvider.errorMessage != null && bookingProvider.services.isEmpty) {
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

            // 4. Booking Form Wizard
            return RefreshIndicator(
              onRefresh: () async {
                await bookingProvider.initBooking();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Step 1: Thông tin người khám bệnh
                    _buildStepHeader(
                      stepNumber: '1',
                      title: 'Thông tin người khám bệnh',
                      subtitle: 'Họ tên và số điện thoại để nhận mã phiếu khám',
                    ),
                    const SizedBox(height: 12),
                    _buildPatientInfoInputSection(bookingProvider),
                    const SizedBox(height: 24),

                    // Step 2: Chọn phân nhóm chuyên khoa Sản - Phụ khoa
                    _buildStepHeader(
                      stepNumber: '2',
                      title: 'Chọn nhóm dịch vụ khám',
                      subtitle: 'Phân loại theo nhu cầu chăm sóc mẹ & bé',
                    ),
                    const SizedBox(height: 12),
                    _buildCategorySelector(bookingProvider),
                    const SizedBox(height: 14),
                    _buildServiceSection(bookingProvider),
                    const SizedBox(height: 24),

                    // Step 3: Khai báo ngữ cảnh chuyên khoa tự nguyện
                    _buildStepHeader(
                      stepNumber: '3',
                      title: bookingProvider.selectedCategory == 'prenatal'
                          ? 'Thông tin thai kỳ (Tùy chọn)'
                          : (bookingProvider.selectedCategory == 'gynecology'
                              ? 'Thông tin phụ khoa (Tùy chọn)'
                              : 'Ghi chú triệu chứng (Tùy chọn)'),
                      subtitle: 'Giúp bác sĩ tiếp đón và chuẩn bị lộ trình khám chu đáo hơn',
                    ),
                    const SizedBox(height: 12),
                    _buildSpecialtyContextSection(context, bookingProvider),
                    const SizedBox(height: 24),

                    // Step 4: Chọn ngày khám
                    _buildStepHeader(
                      stepNumber: '4',
                      title: 'Chọn ngày khám',
                      subtitle: 'Không áp dụng đặt lịch cho các ngày trong quá khứ',
                    ),
                    const SizedBox(height: 12),
                    _buildDateSelector(context, bookingProvider),
                    const SizedBox(height: 24),

                    // Step 5: Chọn khung giờ khả dụng
                    _buildStepHeader(
                      stepNumber: '5',
                      title: 'Chọn khung giờ khám',
                      subtitle: 'Các khung giờ còn trống được cập nhật thời gian thực từ viện',
                    ),
                    const SizedBox(height: 12),
                    _buildSlotsSection(bookingProvider),
                    const SizedBox(height: 24),

                    // Step 6: Tóm tắt & Xác nhận
                    _buildSummaryCard(bookingProvider),
                    const SizedBox(height: 20),

                    // Submit Error Banner
                    if (bookingProvider.errorMessage != null)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.emergencyLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.emergency.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: AppColors.emergency, size: 20),
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

                    // Confirm Booking Action Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: bookingProvider.canSubmit
                            ? () async {
                                final success = await bookingProvider.submitBooking();
                                if (success && context.mounted) {
                                  final homeProvider = Provider.of<HomeProvider>(context, listen: false);
                                  final historyProvider = Provider.of<HistoryProvider>(context, listen: false);
                                  homeProvider.loadHomeData(isRefresh: true);
                                  historyProvider.loadAppointments(bookingProvider.patient?.id, isRefresh: true);
                                }
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: bookingProvider.isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_circle_outline_rounded),
                        label: Text(
                          bookingProvider.isSubmitting
                              ? 'Đang gửi yêu cầu đặt lịch...'
                              : 'Xác nhận đặt lịch khám',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // --- WIDGET BUILDERS ---

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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Họ và tên field
          TextFormField(
            controller: _fullNameCtrl,
            decoration: InputDecoration(
              labelText: 'Họ và tên bệnh nhân *',
              hintText: 'Nhập họ và tên đầy đủ',
              prefixIcon: const Icon(Icons.person_outline_rounded, size: 20, color: AppColors.primary),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            onChanged: (val) => bookingProvider.setFullName(val),
          ),
          const SizedBox(height: 14),

          // Số điện thoại field
          TextFormField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Số điện thoại liên hệ *',
              hintText: 'VD: 0912345678',
              prefixIcon: const Icon(Icons.phone_android_rounded, size: 20, color: AppColors.primary),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            onChanged: (val) => bookingProvider.setPhone(val),
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
            onTap: () => bookingProvider.setSelectedCategory(cat['id'] as String),
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
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
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
                    isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                    color: isSelected ? AppColors.primary : AppColors.textTertiary,
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
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                            color: isSelected ? AppColors.primary : AppColors.textPrimary,
                          ),
                        ),
                        if (service.description != null && service.description!.isNotEmpty) ...[
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

  Widget _buildSpecialtyContextSection(BuildContext context, BookingProvider bookingProvider) {
    if (bookingProvider.selectedCategory == 'prenatal') {
      return _buildPrenatalContextCard(context, bookingProvider);
    }
    if (bookingProvider.selectedCategory == 'gynecology') {
      return _buildGynecologyContextCard(context, bookingProvider);
    }
    return _buildGeneralContextCard(bookingProvider);
  }

  Widget _buildPrenatalContextCard(BuildContext context, BookingProvider bookingProvider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.maternityPink.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pregnant_woman_rounded, color: AppColors.maternityPink, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Ngữ cảnh thai sản mẹ & bé',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
              ),
              if (bookingProvider.hasProfileHealthData)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '✓ Y tế đã có',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.success),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Tuần thai & Ngày kinh cuối
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: bookingProvider.lmp ?? DateTime.now().subtract(const Duration(days: 70)),
                      firstDate: DateTime.now().subtract(const Duration(days: 300)),
                      lastDate: DateTime.now(),
                      helpText: 'Chọn ngày đầu kỳ kinh cuối (LMP)',
                    );
                    if (picked != null) {
                      bookingProvider.setLmp(picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Kỳ kinh cuối (LMP)', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                        const SizedBox(height: 2),
                        Text(
                          bookingProvider.lmp != null ? DateFormat('dd/MM/yyyy').format(bookingProvider.lmp!) : 'Chạm để chọn',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withValues(alpha: 0.3),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Tuổi thai ước tính', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                      const SizedBox(height: 2),
                      Text(
                        bookingProvider.gestationalWeeks != null
                            ? 'Tuần ${bookingProvider.gestationalWeeks} + ${bookingProvider.gestationalDays ?? 0} ngày'
                            : 'Chưa ước tính',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Tình trạng thai máy
          const Text('Tình trạng cử động thai:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: ['Bình thường', 'Yếu / Ít hơn', 'Chưa cảm nhận'].map((status) {
              final isSel = bookingProvider.fetalMovementStatus == status;
              return ChoiceChip(
                label: Text(status),
                selected: isSel,
                onSelected: (val) {
                  if (val) bookingProvider.setFetalMovementStatus(status);
                },
                selectedColor: AppColors.primaryLight,
                labelStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isSel ? AppColors.primary : AppColors.textSecondary,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildGynecologyContextCard(BuildContext context, BookingProvider bookingProvider) {
    final commonReasons = [
      'Khám phụ khoa định kỳ',
      'Viêm nhiễm / Ngứa rát',
      'Rối loạn kinh nguyệt',
      'Đau bụng hạ vị',
      'Tầm soát ung thư CTC',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.spa_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Ngữ cảnh khám phụ khoa',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
              ),
              if (bookingProvider.hasProfileHealthData)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '✓ Y tế đã có',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.success),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          const Text('Lý do chính đi khám:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: commonReasons.map((reason) {
              final isSel = bookingProvider.gynVisitReason == reason;
              return ChoiceChip(
                label: Text(reason),
                selected: isSel,
                onSelected: (val) {
                  bookingProvider.setGynVisitReason(val ? reason : null);
                },
                selectedColor: AppColors.primaryLight,
                labelStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isSel ? AppColors.primary : AppColors.textSecondary,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // Chu kỳ kinh nguyệt
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Chu kỳ kinh', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                      const SizedBox(height: 2),
                      Text(
                        bookingProvider.menstrualCycle,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: bookingProvider.lastPeriodDate ?? DateTime.now().subtract(const Duration(days: 14)),
                      firstDate: DateTime.now().subtract(const Duration(days: 90)),
                      lastDate: DateTime.now(),
                      helpText: 'Chọn ngày kinh gần nhất',
                    );
                    if (picked != null) {
                      bookingProvider.setLastPeriodDate(picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Ngày kinh gần nhất', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                        const SizedBox(height: 2),
                        Text(
                          bookingProvider.lastPeriodDate != null
                              ? DateFormat('dd/MM/yyyy').format(bookingProvider.lastPeriodDate!)
                              : 'Chạm để chọn',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralContextCard(BookingProvider bookingProvider) {
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
            'Ghi chú triệu chứng hoặc yêu cầu đặc biệt:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _notesCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Nhập ghi chú hoặc tiền sử cần bác sĩ lưu ý...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.all(12),
            ),
            onChanged: (val) => bookingProvider.setClinicalNotes(val),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector(BuildContext context, BookingProvider bookingProvider) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
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
              final date = today.add(Duration(days: index));
              final isSelected = selectedDate.year == date.year &&
                  selectedDate.month == date.month &&
                  selectedDate.day == date.day;
              final isToday = index == 0;

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
                        isToday ? 'H.nay' : _formatWeekdayShort(date),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white70 : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('dd').format(date),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('MM').format(date),
                        style: TextStyle(
                          fontSize: 10,
                          color: isSelected ? Colors.white70 : AppColors.textTertiary,
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

    final hasAvailableSlot = bookingProvider.availableSlots.any((s) => s.isAvailable);

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
                Icon(Icons.info_outline_rounded, size: 16, color: Colors.amber.shade900),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Các khung giờ hôm nay đã qua giờ khám thực tế. Vui lòng chọn ngày tiếp theo (ngày mai) để đặt lịch.',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.amber.shade900),
                  ),
                ),
              ],
            ),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: bookingProvider.availableSlots.map((slot) {
        final isSelected = bookingProvider.selectedSlot?.timeRange == slot.timeRange;
        final isAvailable = slot.isAvailable;

        return InkWell(
          onTap: isAvailable ? () => bookingProvider.selectSlot(slot) : null,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary
                  : (!isAvailable ? Colors.grey.shade100 : AppColors.surface),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? AppColors.primary
                    : (!isAvailable ? Colors.grey.shade300 : AppColors.border),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isAvailable ? Icons.access_time_rounded : Icons.block_rounded,
                  size: 14,
                  color: isSelected
                      ? Colors.white
                      : (!isAvailable ? Colors.grey.shade400 : AppColors.textSecondary),
                ),
                const SizedBox(width: 6),
                Text(
                  slot.timeRange,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : (!isAvailable ? Colors.grey.shade400 : AppColors.textPrimary),
                    decoration: !isAvailable ? TextDecoration.lineThrough : null,
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
            valueColor: name.startsWith('Chưa') ? AppColors.textTertiary : AppColors.textPrimary,
          ),
          const SizedBox(height: 8),
          _buildSummaryRow(
            label: 'Số điện thoại:',
            value: phone,
            valueColor: phone.startsWith('Chưa') ? AppColors.textTertiary : AppColors.textPrimary,
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
            valueColor: service != null ? AppColors.textPrimary : AppColors.textTertiary,
          ),
          const SizedBox(height: 8),
          _buildSummaryRow(
            label: 'Ngày khám:',
            value: _formatDateFull(date),
          ),
          const SizedBox(height: 8),
          _buildSummaryRow(
            label: 'Khung giờ:',
            value: slot?.timeRange ?? 'Chưa chọn giờ',
            valueColor: slot != null ? AppColors.secondary : AppColors.textTertiary,
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

  Widget _buildSuccessView(BuildContext context, BookingProvider bookingProvider) {
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
                  value: result.id.length >= 8 ? result.id.substring(0, 8).toUpperCase() : result.id,
                  valueColor: AppColors.primary,
                ),
                const Divider(height: 16),
                _buildSummaryRow(label: 'Bệnh nhân:', value: result.patientName),
                const SizedBox(height: 8),
                _buildSummaryRow(label: 'Dịch vụ:', value: result.serviceTypeName),
                const SizedBox(height: 8),
                _buildSummaryRow(
                  label: 'Thời gian khám:',
                  value: DateFormat('HH:mm - dd/MM/yyyy').format(result.scheduledTime),
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
              child: const Text('Về trang chủ', style: TextStyle(fontWeight: FontWeight.w700)),
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
              child: const Text('Xem sổ lịch hẹn', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
