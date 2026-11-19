import '../core/network/api_client.dart';
import '../models/notification_model.dart';

class NotificationService {
  final ApiClient _apiClient;

  NotificationService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  /// Retrieves notifications for a specific encounter ID.
  Future<List<NotificationModel>> getNotificationsByEncounter(
    String encounterId,
  ) async {
    final response = await _apiClient.get<List<NotificationModel>>(
      '/notifications/by-encounter/${Uri.encodeComponent(encounterId)}',
      fromJsonT: (json) {
        if (json is List) {
          return json
              .map((item) => NotificationModel.fromJson(item as Map<String, dynamic>))
              .toList();
        }
        return <NotificationModel>[];
      },
    );
    return response.data ?? <NotificationModel>[];
  }

  /// Marks a specific notification as read.
  Future<bool> markAsRead(String notificationId) async {
    try {
      final response = await _apiClient.patch<Map<String, dynamic>>(
        '/notifications/${Uri.encodeComponent(notificationId)}/read',
      );
      return response.success;
    } catch (_) {
      return false;
    }
  }

  /// Triggers a backend check to evaluate and issue active reminders.
  Future<bool> runRemindersCheck() async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/notifications/reminders/run',
      );
      return response.success;
    } catch (_) {
      return false;
    }
  }
}
