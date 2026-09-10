import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flowcare_mobile/providers/booking_provider.dart';
import 'package:flowcare_mobile/providers/history_provider.dart';
import 'package:flowcare_mobile/providers/home_provider.dart';
import 'package:flowcare_mobile/providers/profile_provider.dart';
import 'package:flowcare_mobile/screens/main_shell_screen.dart';

void main() {
  Widget buildTestApp({int initialIndex = 0}) {
    final homeProvider = HomeProvider();
    final bookingProvider = BookingProvider();
    final historyProvider = HistoryProvider();
    final profileProvider = ProfileProvider();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<HomeProvider>.value(value: homeProvider),
        ChangeNotifierProvider<BookingProvider>.value(value: bookingProvider),
        ChangeNotifierProvider<HistoryProvider>.value(value: historyProvider),
        ChangeNotifierProvider<ProfileProvider>.value(value: profileProvider),
      ],
      child: MaterialApp(
        home: MainShellScreen(initialTabIndex: initialIndex),
      ),
    );
  }

  testWidgets('App Shell loads with 5 navigation destinations', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pump();

    expect(find.text('Trang chủ'), findsWidgets);
    expect(find.text('Đặt lịch'), findsWidgets);
    expect(find.text('Lộ trình'), findsWidgets);
    expect(find.text('Lịch sử'), findsWidgets);
    expect(find.text('Hồ sơ'), findsWidgets);
  });

  testWidgets('Bottom navigation tab transitions test', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pump();

    // 1. Booking tab
    await tester.tap(find.widgetWithText(NavigationDestination, 'Đặt lịch'));
    await tester.pumpAndSettle();
    expect(find.text('Đặt lịch khám trực tuyến'), findsOneWidget);

    // 2. Route tab
    await tester.tap(find.widgetWithText(NavigationDestination, 'Lộ trình'));
    await tester.pumpAndSettle();
    expect(find.text('Lộ trình khám Sản - Phụ khoa'), findsOneWidget);

    // 3. History tab
    await tester.tap(find.widgetWithText(NavigationDestination, 'Lịch sử'));
    await tester.pumpAndSettle();
    expect(find.text('Lịch sử lịch hẹn & Khám'), findsOneWidget);

    // 4. Profile tab
    await tester.tap(find.widgetWithText(NavigationDestination, 'Hồ sơ'));
    await tester.pumpAndSettle();
    expect(find.text('Hồ sơ sức khỏe Sản - Phụ khoa'), findsOneWidget);

    // 5. Return to Home
    await tester.tap(find.widgetWithText(NavigationDestination, 'Trang chủ'));
    await tester.pumpAndSettle();
    expect(find.text('Bệnh viện Phụ Sản Thông Minh'), findsOneWidget);
  });

  testWidgets('HomeScreen displays maternity greeting and quick actions', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pump();

    expect(find.textContaining('Xin chào'), findsOneWidget);
    expect(find.text('Bệnh viện Phụ Sản Thông Minh'), findsOneWidget);
    expect(find.text('Đặt lịch khám'), findsWidgets);
    expect(find.text('Theo dõi thai kỳ'), findsOneWidget);
  });

  testWidgets('BookingScreen renders OB/GYN categories and step wizard', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestApp(initialIndex: 1));
    await tester.pump();

    expect(find.text('Đặt lịch khám trực tuyến'), findsOneWidget);
    expect(find.text('Khám thai'), findsOneWidget);
    expect(find.text('Khám phụ khoa'), findsOneWidget);
  });

  testWidgets('HistoryScreen renders empty state when patient has no appointments', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestApp(initialIndex: 3));
    await tester.pumpAndSettle();

    expect(find.text('Lịch sử lịch hẹn & Khám'), findsOneWidget);
  });

  testWidgets('ProfileScreen renders OB/GYN health sections', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestApp(initialIndex: 4));
    await tester.pumpAndSettle();

    expect(find.text('Hồ sơ sức khỏe Sản - Phụ khoa'), findsOneWidget);
    expect(find.text('1. Thông tin định danh cá nhân'), findsOneWidget);
    expect(find.text('2. Thông tin y tế & Nhóm máu'), findsOneWidget);
    expect(find.text('3. Hồ sơ thai sản & Tiền sử sản khoa'), findsOneWidget);
    expect(find.text('4. Hồ sơ sức khỏe phụ khoa'), findsOneWidget);
  });
}
