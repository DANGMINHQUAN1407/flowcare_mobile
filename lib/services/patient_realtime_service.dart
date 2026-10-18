import 'package:signalr_netcore/signalr_client.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/api_client.dart';
import '../core/network/api_exceptions.dart';

typedef PatientEventCallback = void Function(String event);

class PatientRealtimeService {
  HubConnection? _connection;
  String? _encounterId;
  int _version = 0;

  Future<void> connect({
    required String encounterId,
    required PatientEventCallback onEvent,
    required void Function(bool connected) onConnectionChanged,
  }) async {
    final sessionVersion = ApiClient.sessionVersion;
    await ApiClient.ensureAuthenticated();
    if (_encounterId == encounterId &&
        _connection?.state == HubConnectionState.Connected) {
      return;
    }
    await disconnect();
    final version = _version;
    if (sessionVersion != ApiClient.sessionVersion) return;
    _encounterId = encounterId;
    final base = Uri.parse(ApiEndpoints.defaultBaseUrl);
    final apiSuffix = '/api/v1';
    final prefix = base.path.endsWith(apiSuffix)
        ? base.path.substring(0, base.path.length - apiSuffix.length)
        : '';
    final hub = HubConnectionBuilder()
        .withUrl(
          base.replace(path: '$prefix/hubs/patient', query: '').toString(),
          options: HttpConnectionOptions(
            accessTokenFactory: () async {
              if (sessionVersion != ApiClient.sessionVersion) {
                throw SessionChangedException();
              }
              await ApiClient.ensureAuthenticated();
              return ApiClient.authToken ?? '';
            },
          ),
        )
        .withAutomaticReconnect()
        .build();
    _connection = hub;
    for (final event in const [
      'QueueTicketCreated',
      'QueueTicketUpdated',
      'EncounterStatusChanged',
      'MedicalOrderUpdated',
      'PreExamOrderUpdated',
      'NotificationReceived',
      'ParaclinicalPlanCreated',
      'ParaclinicalStepTransitioned',
      'ParaclinicalResultReady',
      'ParaclinicalPlanStatusChanged',
      'RoutingRecommendationChanged',
    ]) {
      hub.on(event, (_) {
        if (version == _version && sessionVersion == ApiClient.sessionVersion) {
          onEvent(event);
        }
      });
    }
    hub.onreconnecting(({error}) {
      if (version == _version && sessionVersion == ApiClient.sessionVersion) {
        onConnectionChanged(false);
      }
    });
    hub.onclose(({error}) {
      if (version == _version && sessionVersion == ApiClient.sessionVersion) {
        onConnectionChanged(false);
      }
    });
    hub.onreconnected(({connectionId}) async {
      if (version != _version || sessionVersion != ApiClient.sessionVersion) {
        return;
      }
      try {
        await hub.invoke('JoinEncounter', args: [encounterId]);
        if (version == _version && sessionVersion == ApiClient.sessionVersion) {
          onConnectionChanged(true);
          onEvent('Reconnected');
        }
      } catch (_) {
        if (version == _version && sessionVersion == ApiClient.sessionVersion) {
          onConnectionChanged(false);
        }
      }
    });
    try {
      await hub.start()!.timeout(const Duration(seconds: 12));
      if (version != _version || sessionVersion != ApiClient.sessionVersion) {
        await hub.stop();
        return;
      }
      await hub.invoke('JoinEncounter', args: [encounterId]);
      if (version == _version && sessionVersion == ApiClient.sessionVersion) {
        onConnectionChanged(true);
        onEvent('Connected');
      }
    } catch (_) {
      if (version == _version && sessionVersion == ApiClient.sessionVersion) {
        onConnectionChanged(false);
        _connection = null;
        _encounterId = null;
      }
      try {
        await hub.stop();
      } catch (_) {
        /* already stopped */
      }
    }
  }

  Future<void> disconnect() async {
    _version++;
    final previous = _connection;
    _connection = null;
    _encounterId = null;
    try {
      await previous?.stop();
    } catch (_) {
      // Snapshot refresh remains available after a transport failure.
    }
  }
}
