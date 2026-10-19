import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../models/patient_registration.dart';
import '../../providers/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  final _linkCode = TextEditingController();
  DateTime? _dob;
  bool _obscure = true;
  bool _fromReception = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _password.dispose();
    _confirmation.dispose();
    _linkCode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    if (auth.isBusy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final userName = await auth.register(
      _fromReception
          ? PatientRegistration.fromReception(
              registrationLinkCode: _linkCode.text,
              password: _password.text,
            )
          : PatientRegistration(
              fullName: _name.text,
              phone: _phone.text,
              password: _password.text,
              dob: _dob,
            ),
    );
    if (mounted && userName != null) {
      _password.clear();
      _confirmation.clear();
      _linkCode.clear();
      Navigator.of(context).pop(userName);
    }
  }

  void _changeMode(bool fromReception) {
    final auth = context.read<AuthProvider>();
    if (auth.isBusy || fromReception == _fromReception) return;
    FocusScope.of(context).unfocus();
    _form.currentState?.reset();
    _name.clear();
    _phone.clear();
    _password.clear();
    _confirmation.clear();
    _linkCode.clear();
    auth.clearMessage();
    setState(() {
      _fromReception = fromReception;
      _dob = null;
    });
  }

  Future<void> _pickDob() async {
    FocusScope.of(context).unfocus();
    final value = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'Chọn ngày sinh',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
    );
    if (mounted && value != null) setState(() => _dob = value);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return PopScope(
      canPop: !auth.isBusy,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Đăng ký tài khoản'),
          leading: BackButton(
            onPressed: auth.isBusy ? null : () => Navigator.of(context).pop(),
          ),
        ),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: AutofillGroup(
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _fromReception
                              ? 'Kích hoạt hồ sơ tại quầy'
                              : 'Đăng ký tài khoản mới',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _fromReception
                              ? 'Dùng thông tin đã lưu tại quầy. Chỉ cần mã liên kết và mật khẩu bạn tự đặt. SĐT tại quầy sẽ là tên đăng nhập.'
                              : 'Nhập thông tin để tạo tài khoản và đặt lịch khám online. Số điện thoại sẽ là tên đăng nhập.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 24),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('Đăng ký mới'),
                              selected: !_fromReception,
                              selectedColor: AppColors.primary,
                              checkmarkColor: AppColors.onPrimary,
                              labelStyle: TextStyle(
                                color: !_fromReception
                                    ? AppColors.onPrimary
                                    : AppColors.primary,
                              ),
                              onSelected: auth.isBusy
                                  ? null
                                  : (_) => _changeMode(false),
                            ),
                            ChoiceChip(
                              label: const Text('Đã có mã tại quầy'),
                              selected: _fromReception,
                              selectedColor: AppColors.primary,
                              checkmarkColor: AppColors.onPrimary,
                              labelStyle: TextStyle(
                                color: _fromReception
                                    ? AppColors.onPrimary
                                    : AppColors.primary,
                              ),
                              onSelected: auth.isBusy
                                  ? null
                                  : (_) => _changeMode(true),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        if (!_fromReception) ...[
                          TextFormField(
                            key: const Key('register-name'),
                            controller: _name,
                            enabled: !auth.isBusy,
                            textCapitalization: TextCapitalization.words,
                            autofillHints: const [AutofillHints.name],
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Họ và tên',
                            ),
                            validator: PatientRegistration.nameError,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            key: const Key('register-phone'),
                            controller: _phone,
                            enabled: !auth.isBusy,
                            keyboardType: TextInputType.phone,
                            autofillHints: const [
                              AutofillHints.telephoneNumber,
                            ],
                            textInputAction: TextInputAction.next,
                            autocorrect: false,
                            decoration: const InputDecoration(
                              labelText: 'Số điện thoại',
                            ),
                            validator: PatientRegistration.phoneError,
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: auth.isBusy ? null : _pickDob,
                            icon: const Icon(
                              Icons.calendar_today_outlined,
                              size: 20,
                            ),
                            label: Text(
                              _dob == null
                                  ? 'Ngày sinh (không bắt buộc)'
                                  : 'Ngày sinh: ${DateFormat('dd/MM/yyyy').format(_dob!)}',
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (_fromReception) ...[
                          TextFormField(
                            key: const Key('register-link-code'),
                            controller: _linkCode,
                            enabled: !auth.isBusy,
                            textCapitalization: TextCapitalization.characters,
                            autocorrect: false,
                            enableSuggestions: false,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Mã liên kết trên phiếu khám',
                              helperText: 'Mã riêng được quầy giao, không phải STT.\nKhông cần nhập lại họ tên, SĐT hoặc ngày sinh.',
                              helperMaxLines: 3,
                            ),
                            validator: PatientRegistration.linkCodeError,
                          ),
                          const SizedBox(height: 16),
                        ],
                        TextFormField(
                          key: const Key('register-password'),
                          controller: _password,
                          enabled: !auth.isBusy,
                          obscureText: _obscure,
                          autocorrect: false,
                          enableSuggestions: false,
                          autofillHints: const [AutofillHints.newPassword],
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Mật khẩu',
                            helperText: 'Từ 8 đến 256 ký tự',
                            suffixIcon: IconButton(
                              tooltip: _obscure
                                  ? 'Hiện mật khẩu'
                                  : 'Ẩn mật khẩu',
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: PatientRegistration.passwordError,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          key: const Key('register-confirmation'),
                          controller: _confirmation,
                          enabled: !auth.isBusy,
                          obscureText: _obscure,
                          autocorrect: false,
                          enableSuggestions: false,
                          autofillHints: const [AutofillHints.newPassword],
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: const InputDecoration(
                            labelText: 'Nhập lại mật khẩu',
                          ),
                          validator: (value) =>
                              value?.isNotEmpty == true &&
                                  value == _password.text
                              ? null
                              : 'Mật khẩu nhập lại chưa khớp.',
                        ),
                        if (auth.message != null) ...[
                          const SizedBox(height: 16),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              auth.message!,
                              style: const TextStyle(
                                color: AppColors.emergency,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: auth.isBusy ? null : _submit,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: auth.isBusy
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    _fromReception
                                        ? 'Kích hoạt tài khoản'
                                        : 'Tạo tài khoản',
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: auth.isBusy
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: const Text('Về đăng nhập'),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _fromReception
                              ? 'Tài khoản dùng hồ sơ và lượt khám đã có. Mã dùng một lần, có hạn 24 giờ.'
                              : 'Nếu đã được tiếp nhận tại bệnh viện và có mã liên kết, chọn “Đã có mã tại quầy” để dùng hồ sơ hiện có.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
