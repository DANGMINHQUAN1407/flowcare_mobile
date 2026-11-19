import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/utils/hospital_time.dart';
import '../providers/home_provider.dart';
import '../services/patient_session_service.dart';
import '../services/route_optimization_service.dart';
import 'route_optimization_card.dart';

Future<void> showPatientNotifications(
  BuildContext context, {
  RouteOptimizationService? optimizationService,
}) async {
  final home = context.read<HomeProvider>();
  final session = PatientSessionService();
  final version = session.version;
  home.markNoticesRead();
  final selected = await showModalBottomSheet<JourneyNotice>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    // The sheet is pushed on MaterialApp's navigator, above the patient-scoped
    // providers. Reuse this session's instance without changing its ownership.
    builder: (context) => ChangeNotifierProvider<HomeProvider>.value(
      value: home,
      child: SafeArea(
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
                              trailing: notice.proposedPlanId != null
                                  ? const Icon(Icons.chevron_right)
                                  : null,
                              onTap: notice.proposedPlanId != null
                                  ? () => Navigator.pop(context, notice)
                                  : null,
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  if (!context.mounted || session.version != version) return;
  final encounterId = selected?.encounterId;
  final offerId = selected?.proposedPlanId;
  final patientId = session.patientId;
  if (encounterId == null || offerId == null || patientId == null) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            ListenableBuilder(
              listenable: home,
              builder: (context, _) {
                final isCurrentVisit =
                    home.encounterSummary?.encounterId == encounterId;
                return RouteOptimizationCard(
                  encounterId: encounterId,
                  patientId: patientId,
                  requestedOfferId: offerId,
                  currentPlan: isCurrentVisit ? home.journey?.plan : null,
                  refreshToken: isCurrentVisit ? home.lastUpdatedAt : null,
                  isStale: isCurrentVisit && home.isJourneyStale,
                  service: optimizationService,
                  onChanged: () async {
                    if (session.version == version &&
                        home.encounterSummary?.encounterId == encounterId) {
                      await home.refreshJourney(includeFinalized: true);
                    }
                  },
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}
