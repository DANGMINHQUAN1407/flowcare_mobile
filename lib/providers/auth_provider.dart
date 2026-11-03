import 'dart:async' hide TimeoutException;

import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../core/network/api_exceptions.dart';
import '../models/patient_registration.dart';
import '../services/auth_service.dart';
import '../services/patient_session_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _service;
  final PatientSessionService _session;
  AuthProvider({AuthService? service, PatientSessionService? session})
    : _service = service ?? AuthService(),
      _session = session ?? PatientSessionService() {
    ApiClient.onUnauthorized = _expire;
    ApiClient.onPasswordChangeRequired = _requirePasswordChange;
  }
  PatientLogin? _login;
  Timer? _expiry;
  int _version = 0;
  bool _busy = false, _disposed = false;
  bool _passwordChangeRequired = false;
  String? _message;
  bool get isAuthenticated => _login != null;
  bool get isBusy => _busy;
  String? get message => _message;
  int get version => _version;
  PatientLogin? get currentUser => _login;
  bool get mustChangePassword =>
      _passwordChangeRequired || (_login?.mustChangePassword ?? false);

  void _requirePasswordChange() {
    if (_disposed || _login == null || mustChangePassword) return;
    _passwordChangeRequired = true;
    _version++;
    _session.clearSession();
    notifyListeners();
  }

  void _publishLogin(PatientLogin result) {
    _passwordChangeRequired = result.mustChangePassword;
    if (result.mustChangePassword) {
      _session.clearSession();
    } else {
      _session.bindPatient(
        patientId: result.patientId,
        userName: result.userName,
        isDemo: result.isDemo,
      );
      _session.setPhone(result.patientPhone ?? '');
    }
    ApiClient.setAuthToken(result.token, readOnlyDemo: result.isDemo);
    _login = result;
    _expiry?.cancel();
    _expiry = Timer(result.expiresAt.difference(DateTime.now()), _expire);
  }

  Future<bool> login(String userName, String password) async {
    if (_busy) return false;
    final version = ++_version;
    _busy = true;
    _message = null;
    notifyListeners();
    try {
      final result = await _service.login(userName, password);
      if (_disposed || version != _version) return false;
      if (!result.expiresAt.isAfter(DateTime.now())) {
        throw UnauthorizedException();
      }
      _publishLogin(result);
      return true;
    } catch (error) {
      if (!_disposed && version == _version) {
        _message = patientErrorMessage(error);
      }
      return false;
    } finally {
      if (!_disposed && version == _version) {
        _busy = false;
        notifyListeners();
      }
    }
  }

  Future<String?> register(PatientRegistration registration) async {
    if (_busy || isAuthenticated) return null;
    final version = ++_version;
    _busy = true;
    _message = null;
    notifyListeners();
    try {
      final userName = await _service.register(registration);
      return !_disposed && version == _version ? userName : null;
    } catch (error) {
      if (!_disposed && version == _version) {
        _message = patientErrorMessage(
          error,
          fallback: 'Không thể đăng ký. Vui lòng thử lại sau.',
        );
      }
      return null;
    } finally {
      if (!_disposed && version == _version) {
        _busy = false;
        notifyListeners();
      }
    }
  }

  Future<bool> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    if (_busy || _login == null || !mustChangePassword) return false;
    final owner = _login!;
    final version = _version;
    var changed = false;
    _busy = true;
    _message = null;
    notifyListeners();
    try {
      await _service.changePassword(currentPassword, newPassword);
      changed = true;
      if (_disposed || version != _version) return false;
      ApiClient.setAuthToken(null);
      _session.clearSession();
      final fresh = await _service.login(owner.userName, newPassword);
      if (_disposed || version != _version) return false;
      if (fresh.patientId != owner.patientId ||
          fresh.mustChangePassword ||
          !fresh.expiresAt.isAfter(DateTime.now())) {
        throw ApiException(
          'Không xác minh được phiên mới sau khi đổi mật khẩu.',
        );
      }
      _publishLogin(fresh);
      _busy = false;
      _version++;
      notifyListeners();
      return true;
    } catch (error) {
      if (!_disposed && version == _version) {
        if (changed) {
          logout(
            message: 'Mật khẩu đã được đổi. Vui lòng đăng nhập lại bằng SĐT và mật khẩu mới.',
          );
        } else {
          _message = error is NetworkException || error is TimeoutException
              ? 'Chưa xác nhận được việc đổi mật khẩu. Thử đăng nhập lại bằng mật khẩu mới trước khi thao tác lại.'
              : patientErrorMessage(error);
        }
      }
      return false;
    } finally {
      if (!_disposed && version == _version) {
        _busy = false;
        notifyListeners();
      }
    }
  }

  void clearMessage() {
    if (_disposed || _message == null) return;
    _message = null;
    notifyListeners();
  }

  void checkExpiry() {
    if (_login != null && !_login!.expiresAt.isAfter(DateTime.now())) _expire();
  }

  void _expire() =>
      logout(message: 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
  void logout({String? message}) {
    if (_disposed) return;
    _version++;
    _expiry?.cancel();
    _login = null;
    _passwordChangeRequired = false;
    _busy = false;
    _message = message;
    ApiClient.setAuthToken(null);
    _session.clearSession();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _version++;
    _expiry?.cancel();
    ApiClient.onUnauthorized = null;
    ApiClient.onPasswordChangeRequired = null;
    ApiClient.setAuthToken(null);
    _session.clearSession();
    super.dispose();
  }
}
