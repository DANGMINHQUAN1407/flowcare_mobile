import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../models/patient_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/patient_session_service.dart';
import '../../providers/home_provider.dart';
import '../../providers/profile_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<HomeProvider, ProfileProvider>(
      builder: (context, homeProvider, profileProvider, child) {
        final patient = profileProvider.patient ?? homeProvider.patient;
        final phone = homeProvider.currentPhone;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Hồ sơ sức khỏe Sản - Phụ khoa'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Làm mới hồ sơ',
                onPressed: () async {
                  await profileProvider.loadProfile(phone, isRefresh: true);
                  if (context.mounted) {
                    await homeProvider.loadHomeData(isRefresh: true);
                  }
                },
              ),
              if (PatientSessionService().isAuthenticated)
                IconButton(
                  icon: const Icon(
                    Icons.logout_rounded,
                    color: AppColors.emergency,
                  ),
                  tooltip: 'Đăng xuất hồ sơ',
                  onPressed: () => _showLogoutConfirmationDialog(
                    context,
                    homeProvider,
                    profileProvider,
                  ),
                ),
            ],
          ),
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                await profileProvider.loadProfile(phone, isRefresh: true);
                if (context.mounted) {
                  await homeProvider.loadHomeData(isRefresh: true);
                }
              },
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Header Card
                    _buildProfileHeaderCard(
                      context,
                      homeProvider,
                      profileProvider,
                      patient,
                      phone,
                    ),

                    const SizedBox(height: 20),

                    if (patient != null) ...[
                      // Section 1: 👤 Thông tin cá nhân
                      _buildSectionHeader(
                        icon: Icons.badge_outlined,
                        title: '1. Thông tin định danh cá nhân',
                        subtitle:
                            'Thông tin hành chính bệnh nhân trên hệ thống EMR',
                      ),
                      const SizedBox(height: 10),
                      _buildPersonalSection(patient, phone),

                      const SizedBox(height: 20),

                      // Section 2: 🩸 Thông tin y tế & Nhóm máu
                      _buildSectionHeader(
                        icon: Icons.bloodtype_outlined,
                        title: '2. Thông tin y tế & Nhóm máu',
                        subtitle: 'Chỉ số an toàn y khoa và tiền sử dị ứng',
                      ),
                      const SizedBox(height: 10),
                      _buildMedicalSection(patient),

                      const SizedBox(height: 20),

                      // Section 3: 🤰 Hồ sơ thai sản & Tiền sử sản khoa
                      _buildSectionHeader(
                        icon: Icons.pregnant_woman_rounded,
                        title: '3. Hồ sơ thai sản & Tiền sử sản khoa',
                        subtitle: 'Chỉ số PARA và theo dõi thai sản mẹ bé',
                      ),
                      const SizedBox(height: 10),
                      _buildObstetricSection(patient),

                      const SizedBox(height: 20),

                      // Section 4: 🩺 Hồ sơ sức khỏe phụ khoa
                      _buildSectionHeader(
                        icon: Icons.spa_outlined,
                        title: '4. Hồ sơ sức khỏe phụ khoa',
                        subtitle: 'Chu kỳ kinh nguyệt và sức khỏe sinh sản',
                      ),
                      const SizedBox(height: 10),
                      _buildGynecologySection(patient),

                      const SizedBox(height: 20),
                    ],
                    // Section 5: Cài đặt & Hỗ trợ y tế
                    _buildSectionHeader(
                      icon: Icons.support_agent_rounded,
                      title: 'Hỗ trợ & Bảo mật y tế',
                      subtitle: 'Tổng đài viện và tiêu chuẩn bảo mật dữ liệu',
                    ),
                    const SizedBox(height: 10),
                    _buildSupportSection(
                      context,
                      homeProvider,
                      profileProvider,
                      phone,
                    ),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // The account is authenticated even if BE has not enabled profile reads yet.
  Widget _buildProfileHeaderCard(
    BuildContext context,
    HomeProvider homeProvider,
    ProfileProvider profileProvider,
    PatientModel? patient,
    String phone,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            patient?.fullName ?? PatientSessionService().userName,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            PatientSessionService().isDemo
                ? 'Phiên chỉ xem'
                : 'Tài khoản bệnh nhân đã đăng nhập',
          ),
          if (patient != null && phone.isNotEmpty) Text('SĐT: $phone'),
          if (profileProvider.isLoading)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(),
            ),
          if (profileProvider.errorMessage != null ||
              homeProvider.patient == null) ...[
            const SizedBox(height: 12),
            Text(
              profileProvider.errorMessage ??
                  'Chưa tải được hồ sơ sức khỏe. Hãy thử làm mới.',
              style: const TextStyle(color: AppColors.emergency),
            ),
          ],
        ],
      ),
    );
  }

  // --- SECTION HEADER ---
  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
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

  // --- 1. PERSONAL SECTION ---
  Widget _buildPersonalSection(PatientModel? patient, String phone) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _buildInfoRow('Họ và tên:', patient?.fullName ?? 'Chưa cập nhật'),
          const Divider(height: 16),
          _buildInfoRow(
            'Số điện thoại:',
            phone.isNotEmpty ? phone : (patient?.phone ?? 'Chưa có'),
          ),
          const Divider(height: 16),
          _buildInfoRow('Ngày sinh (DOB):', patient?.dob ?? 'Chưa cập nhật'),
          const Divider(height: 16),
          _buildInfoRow('Giới tính:', 'Nữ (Mẹ & Bé)'),
          const Divider(height: 16),
          _buildInfoRow(
            'Mã định danh (CCCD):',
            patient?.nationalId ?? 'Chưa cập nhật',
          ),
          const Divider(height: 16),
          _buildInfoRow(
            'Địa chỉ thường trú:',
            patient?.address ?? 'Chưa cập nhật',
          ),
        ],
      ),
    );
  }

  // --- 2. MEDICAL & BLOOD SECTION ---
  Widget _buildMedicalSection(PatientModel? patient) {
    final bloodStr =
        (patient?.bloodGroup != null && patient!.bloodGroup!.isNotEmpty)
        ? '${patient.bloodGroup} (Rh${patient.rhFactor ?? "+"})'
        : 'Chưa xét nghiệm';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _buildInfoRow(
            'Nhóm máu & Yếu tố Rh:',
            bloodStr,
            valueColor: patient?.bloodGroup != null
                ? AppColors.secondary
                : null,
            isBold: true,
          ),
          const Divider(height: 16),
          _buildInfoRow(
            'Tiền sử dị ứng:',
            patient?.allergies ?? 'Không ghi nhận dị ứng thuốc/thực phẩm',
            valueColor:
                (patient?.allergies != null && patient!.allergies != 'Không có')
                ? AppColors.emergency
                : null,
          ),
          const Divider(height: 16),
          _buildInfoRow(
            'Tiền sử bệnh lý:',
            patient?.medicalHistory ?? 'Chưa ghi nhận bệnh nền mạn tính',
          ),
        ],
      ),
    );
  }

  // --- 3. OBSTETRIC SECTION ---
  Widget _buildObstetricSection(PatientModel? patient) {
    final bmi = patient?.prePregnancyBmi;
    final bmiText = bmi != null
        ? '${bmi.toStringAsFixed(1)} kg/m² (${patient!.bmiCategory})'
        : 'Chưa có dữ liệu';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.maternityPink.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          _buildInfoRow(
            'Chỉ số PARA (G-P-A-L):',
            patient?.para ?? 'Chưa ghi nhận (Khám lần đầu)',
            valueColor: AppColors.maternityPink,
            isBold: true,
          ),
          const Divider(height: 16),
          _buildInfoRow(
            'Tuổi thai hiện tại:',
            patient?.gestationalWeeks != null
                ? 'Tuần ${patient!.gestationalWeeks} + ${patient.gestationalDays ?? 0} ngày'
                : 'Chưa có dữ liệu thai kỳ',
            valueColor: patient?.gestationalWeeks != null
                ? AppColors.primary
                : null,
          ),
          const Divider(height: 16),
          _buildInfoRow('Ngày dự sinh (EDD):', patient?.edd ?? 'Chưa xác định'),
          const Divider(height: 16),
          _buildInfoRow('Kỳ kinh cuối (LMP):', patient?.lmp ?? 'Chưa ghi nhận'),
          const Divider(height: 16),
          _buildInfoRow(
            'Tiền sử sản khoa:',
            patient?.obstetricHistory ?? 'Chưa ghi nhận tiền sử bất thường',
          ),
          const Divider(height: 16),
          _buildInfoRow(
            'Chiều cao:',
            patient?.heightCm != null ? '${patient!.heightCm} cm' : 'Chưa đo',
          ),
          const Divider(height: 16),
          _buildInfoRow(
            'Cân nặng tiền thai kỳ:',
            patient?.prePregnancyWeight != null
                ? '${patient!.prePregnancyWeight} kg'
                : 'Chưa đo',
          ),
          const Divider(height: 16),
          _buildInfoRow('Chỉ số BMI tiền mang thai:', bmiText),
        ],
      ),
    );
  }

  // --- 4. GYNECOLOGY SECTION ---
  Widget _buildGynecologySection(PatientModel? patient) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _buildInfoRow(
            'Chu kỳ kinh nguyệt:',
            patient?.menstrualCycle ?? '28 - 30 ngày (Bình thường)',
          ),
          const Divider(height: 16),
          _buildInfoRow(
            'Biện pháp tránh thai:',
            patient?.contraceptiveMethod ?? 'Không áp dụng',
          ),
          const Divider(height: 16),
          _buildInfoRow(
            'Tầm soát ung thư CTC:',
            'Khuyến cáo thực hiện định kỳ hàng năm',
          ),
        ],
      ),
    );
  }

  // --- 5. SUPPORT & SECURITY SECTION ---
  Widget _buildSupportSection(
    BuildContext context,
    HomeProvider homeProvider,
    ProfileProvider profileProvider,
    String phone,
  ) {
    return Column(
      children: [
        _buildActionTile(
          icon: Icons.logout_rounded,
          title: 'Đăng xuất tài khoản',
          subtitle: 'Xóa phiên đăng nhập và dữ liệu đang xem trên thiết bị',
          isDestructive: true,
          onTap: () => _showLogoutConfirmationDialog(
            context,
            homeProvider,
            profileProvider,
          ),
        ),
        _buildActionTile(
          icon: Icons.headset_mic_outlined,
          title: 'Tổng đài cấp cứu & Chăm sóc sản khoa',
          subtitle: AppConstants.hotline,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Tổng đài hỗ trợ cấp cứu & tư vấn thai sản: 1900 6868',
                ),
              ),
            );
          },
        ),
        _buildActionTile(
          icon: Icons.local_hospital_outlined,
          title: 'Địa chỉ Bệnh viện Phụ Sản FlowCare',
          subtitle: AppConstants.hospitalAddress,
          onTap: () {},
        ),
        _buildActionTile(
          icon: Icons.privacy_tip_outlined,
          title: 'Bảo mật hồ sơ bệnh án điện tử (EMR)',
          subtitle: 'Chuẩn bảo mật dữ liệu y tế HL7/FHIR & HIPAA',
          onTap: () {},
        ),
        _buildActionTile(
          icon: Icons.info_outline_rounded,
          title: 'Phiên bản ứng dụng',
          subtitle: 'FlowCare AI Patient Mobile v${AppConstants.appVersion}',
          onTap: () {},
        ),
      ],
    );
  }

  void _showLogoutConfirmationDialog(
    BuildContext context,
    HomeProvider homeProvider,
    ProfileProvider profileProvider,
  ) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: AppColors.emergency),
            SizedBox(width: 8),
            Text(
              'Đăng xuất hồ sơ',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: const Text(
          'Bạn có chắc chắn muốn đăng xuất và xóa phiên bệnh nhân hiện tại khỏi thiết bị này?',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text(
              'Hủy',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emergency,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.pop(dialogCtx);
              context.read<AuthProvider>().logout();
            },
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    Color? valueColor,
    bool isBold = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
              color: valueColor ?? AppColors.textPrimary,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Color? iconColor,
    Color? iconBgColor,
    bool isDestructive = false,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDestructive
              ? AppColors.emergency.withValues(alpha: 0.3)
              : AppColors.border,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBgColor ?? AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor ?? AppColors.primary, size: 20),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDestructive
                  ? AppColors.emergency
                  : AppColors.textPrimary,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: isDestructive ? AppColors.emergency : AppColors.textTertiary,
            size: 20,
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}
