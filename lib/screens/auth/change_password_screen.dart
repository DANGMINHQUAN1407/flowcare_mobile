import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../models/patient_registration.dart';
import '../../providers/auth_provider.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});
  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController(),
      _password = TextEditingController(),
      _confirmation = TextEditingController();
  bool _obscure = true;
  @override
  void dispose() {
    _current.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final changed = await context.read<AuthProvider>().changePassword(
      _current.text,
      _password.text,
    );
    if (changed && mounted) {
      _current.clear();
      _password.clear();
      _confirmation.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Đổi mật khẩu tạm'),
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.lock_reset,
                        size: 48,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 16),
                      Text('Tài khoản: ${auth.currentUser?.userName ?? ''}'),
                      const SizedBox(height: 8),
                      const Text(
                        'Đổi mật khẩu tạm được cấp tại quầy trước khi xem hồ sơ và sử dụng ứng dụng.',
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        key: const Key('change-current-password'),
                        controller: _current,
                        enabled: !auth.isBusy,
                        obscureText: _obscure,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: const InputDecoration(
                          labelText: 'Mật khẩu hiện tại (mật khẩu tạm)',
                        ),
                        validator: PatientRegistration.passwordError,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('change-new-password'),
                        controller: _password,
                        enabled: !auth.isBusy,
                        obscureText: _obscure,
                        autocorrect: false,
                        enableSuggestions: false,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: const InputDecoration(
                          labelText: 'Mật khẩu mới',
                        ),
                        validator: (value) =>
                            PatientRegistration.passwordError(value) ??
                            (value == _current.text
                                ? 'Mật khẩu mới phải khác mật khẩu tạm.'
                                : null),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('change-confirm-password'),
                        controller: _confirmation,
                        enabled: !auth.isBusy,
                        obscureText: _obscure,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: const InputDecoration(
                          labelText: 'Nhập lại mật khẩu mới',
                        ),
                        onFieldSubmitted: (_) => _submit(),
                        validator: (value) =>
                            value?.isNotEmpty == true && value == _password.text
                            ? null
                            : 'Mật khẩu nhập lại chưa khớp.',
                      ),
                      TextButton(
                        onPressed: auth.isBusy
                            ? null
                            : () => setState(() => _obscure = !_obscure),
                        child: Text(_obscure ? 'Hiện mật khẩu' : 'Ẩn mật khẩu'),
                      ),
                      if (auth.message != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              auth.message!,
                              style: const TextStyle(
                                color: AppColors.emergency,
                              ),
                            ),
                          ),
                        ),
                      FilledButton(
                        key: const Key('change-password-submit'),
                        onPressed: auth.isBusy ? null : _submit,
                        child: Text(
                          auth.isBusy
                              ? 'Đang đổi mật khẩu…'
                              : 'Đổi mật khẩu và tiếp tục',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: auth.isBusy ? null : () => auth.logout(),
                        child: const Text('Đăng xuất / đăng nhập lại'),
                      ),
                    ],
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
