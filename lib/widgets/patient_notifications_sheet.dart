import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/utils/hospital_time.dart';
import '../providers/home_provider.dart';

void showPatientNotifications(BuildContext context) {
  context.read<HomeProvider>().markNoticesRead();
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.6,
        child: Consumer<HomeProvider>(
          builder: (context, home, _) => Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Text(
                  'Thông báo lượt khám',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                ),
              ),
              Expanded(
                child: home.notices.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Chưa có thông báo mới trong phiên này.\nCác cập nhật về gọi số và tiến trình khám sẽ xuất hiện tại đây.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: home.notices.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final notice = home.notices[index];
                          return ListTile(
                            leading: const Icon(Icons.notifications_outlined),
                            title: Text(
                              notice.message,
                              style: const TextStyle(fontSize: 13),
                            ),
                            subtitle: Text(
                              hospitalTime(
                                notice.createdAt,
                                pattern: 'HH:mm:ss',
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
