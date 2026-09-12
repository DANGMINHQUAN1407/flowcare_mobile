import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../providers/booking_provider.dart';
import '../providers/history_provider.dart';
import '../providers/home_provider.dart';
import '../providers/profile_provider.dart';
import 'booking/booking_screen.dart';
import 'history/history_screen.dart';
import 'home/home_screen.dart';
import 'profile/profile_screen.dart';
import 'route/route_screen.dart';

class MainShellScreen extends StatefulWidget {
  final int initialTabIndex;

  const MainShellScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex;
  }

  void _onTabSelected(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
      });
      final homeProvider = Provider.of<HomeProvider>(context, listen: false);

      if (index == 1) {
        final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
        bookingProvider.initBooking(homeProvider.currentPhone);
      } else if (index == 3) {
        final historyProvider = Provider.of<HistoryProvider>(context, listen: false);
        historyProvider.loadAppointments(
          homeProvider.patient?.id,
          phone: homeProvider.currentPhone,
          patientName: homeProvider.patient?.fullName,
        );
      } else if (index == 4) {
        final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
        profileProvider.loadProfile(homeProvider.currentPhone);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      HomeScreen(onNavigateToTab: _onTabSelected),
      BookingScreen(onNavigateToTab: _onTabSelected),
      const RouteScreen(),
      HistoryScreen(onNavigateToTab: _onTabSelected),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(
              color: AppColors.border,
              width: 1,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _onTabSelected,
          backgroundColor: AppColors.surface,
          indicatorColor: AppColors.primaryLight,
          elevation: 0,
          height: 65,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined, color: AppColors.textSecondary),
              selectedIcon: Icon(Icons.home_rounded, color: AppColors.primary),
              label: 'Trang chủ',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined, color: AppColors.textSecondary),
              selectedIcon: Icon(Icons.calendar_month_rounded, color: AppColors.primary),
              label: 'Đặt lịch',
            ),
            NavigationDestination(
              icon: Icon(Icons.alt_route_outlined, color: AppColors.textSecondary),
              selectedIcon: Icon(Icons.alt_route_rounded, color: AppColors.primary),
              label: 'Lộ trình',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined, color: AppColors.textSecondary),
              selectedIcon: Icon(Icons.receipt_long_rounded, color: AppColors.primary),
              label: 'Lịch sử',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded, color: AppColors.textSecondary),
              selectedIcon: Icon(Icons.person_rounded, color: AppColors.primary),
              label: 'Hồ sơ',
            ),
          ],
        ),
      ),
    );
  }
}
