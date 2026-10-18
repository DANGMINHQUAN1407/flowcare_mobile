import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _userName = TextEditingController(),
      _password = TextEditingController();
  bool _obscure = true;
  String? _notice;
  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _notice = null);
    final success = await context.read<AuthProvider>().login(
      _userName.text,
      _password.text,
    );
    if (mounted && success) _password.clear();
  }

  Future<void> _openRegistration() async {
    final auth = context.read<AuthProvider>();
    auth.clearMessage();
    _password.clear();
    setState(() => _notice = null);
    final userName = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const RegisterScreen()));
    if (!mounted) return;
    auth.clearMessage();
    if (userName != null) {
      setState(() {
        _userName.text = userName;
        _notice = 'Tạo tài khoản thành công. Đăng nhập để đặt lịch khám.';
      });
    }
  }

  @override
  void dispose() {
    _userName.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
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
                      const Icon(
                        Icons.local_hospital_rounded,
                        size: 56,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'FlowCare',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Đăng nhập bệnh nhân',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Đăng nhập bằng tài khoản đã đăng ký hoặc được bệnh viện cấp.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),
                      TextFormField(
                        controller: _userName,
                        enabled: !auth.isBusy,
                        autocorrect: false,
                        autofillHints: const [AutofillHints.username],
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Số điện thoại / Tên đăng nhập',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => value?.trim().isNotEmpty == true
                            ? null
                            : 'Nhập tên đăng nhập.',
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _password,
                        enabled: !auth.isBusy,
                        obscureText: _obscure,
                        autocorrect: false,
                        enableSuggestions: false,
                        autofillHints: const [AutofillHints.password],
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) {
                          if (!auth.isBusy) _submit();
                        },
                        decoration: InputDecoration(
                          labelText: 'Mật khẩu',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            tooltip: _obscure ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (value) =>
                            value?.isNotEmpty == true ? null : 'Nhập mật khẩu.',
                      ),
                      if (_notice != null) ...[
                        const SizedBox(height: 16),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            _notice!,
                            style: const TextStyle(color: AppColors.secondary),
                          ),
                        ),
                      ],
                      if (auth.message != null) ...[
                        const SizedBox(height: 16),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            auth.message!,
                            style: const TextStyle(color: AppColors.emergency),
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
                              : const Text('Đăng nhập'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: auth.isBusy ? null : _openRegistration,
                        child: const Text('Đăng ký tài khoản'),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Đã có hồ sơ tại bệnh viện hoặc quên mật khẩu? Liên hệ quầy tiếp đón để được hỗ trợ.',
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
    );
  }
}
