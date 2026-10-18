import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'providers/booking_provider.dart';
import 'providers/history_provider.dart';
import 'providers/home_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/auth_provider.dart';
import 'services/auth_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/main_shell_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FlowCareApp());
}

class FlowCareApp extends StatelessWidget {
  final AuthService? authService;
  const FlowCareApp({super.key, this.authService});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(service: authService),
      child: Consumer<AuthProvider>(
        builder: (context, auth, _) => MaterialApp(
          key: ValueKey(
            auth.isAuthenticated ? 'patient-${auth.version}' : 'signed-out',
          ),
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          home: const PatientAuthGate(),
        ),
      ),
    );
  }
}

class PatientAuthGate extends StatefulWidget {
  const PatientAuthGate({super.key});
  @override
  State<PatientAuthGate> createState() => _PatientAuthGateState();
}

class _PatientAuthGateState extends State<PatientAuthGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<AuthProvider>().checkExpiry();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isAuthenticated) return const LoginScreen();
    // A new account gets fresh providers, forms, caches and realtime connections.
    return MultiProvider(
      key: ValueKey('patient-session-${auth.version}'),
      providers: [
        ChangeNotifierProvider(create: (_) => HomeProvider()),
        ChangeNotifierProvider(create: (_) => BookingProvider()),
        ChangeNotifierProvider(create: (_) => HistoryProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
      ],
      child: const MainShellScreen(
        initialTabIndex: int.fromEnvironment('INITIAL_TAB', defaultValue: 0),
      ),
    );
  }
}
