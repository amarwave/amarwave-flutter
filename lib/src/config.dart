// ignore_for_file: constant_identifier_names

/// Configuration for the AmarWave WebSocket client.
///
/// Only [appKey] is required. All other fields default to sensible values
/// that work with a local AmarWave server.
///
/// Example:
/// ```dart
/// final aw = AmarWave(
///   AmarWaveConfig(
///     appKey: 'my-app-key',
///     appSecret: 'my-app-secret',    // optional – enables client-side HMAC auth
///     wsHost: 'ws.example.com',
///     wsPort: 3001,
///     forceTLS: false,
///   ),
/// );
/// ```
class AmarWaveConfig {
  /// Your AmarWave application key (required).
  final String appKey;

  /// Your AmarWave application secret.
  /// Used for client-side HMAC signing of private/presence channels.
  /// ⚠️  Do not expose in production — use [authEndpoint] instead.
  final String? appSecret;

  /// WebSocket server hostname. Default: `'localhost'`.
  final String wsHost;

  /// WebSocket plain port (ws://). Default: `3001`.
  final int wsPort;

  /// WebSocket TLS port (wss://). Used when [forceTLS] is true. Default: `443`.
  final int wssPort;

  /// HTTP API hostname for publishing events.
  /// Defaults to the same value as [wsHost].
  final String? apiHost;

  /// HTTP API port. Default: `8000`.
  final int apiPort;

  /// HTTP API trigger path. Default: `'/api/v1/trigger'`.
  final String apiPath;

  /// WebSocket upgrade path. Default: `'/ws'`.
  final String wsPath;

  /// Force WSS (secure WebSocket) and HTTPS. Default: `false`.
  final bool forceTLS;

  /// Server-side channel authentication endpoint URL.
  /// Required for private- and presence- channels when [appSecret] is not set.
  final String authEndpoint;

  /// Extra HTTP headers sent with every authentication request.
  final Map<String, String> authHeaders;

  /// Base delay before the first reconnect attempt (exponential backoff).
  final Duration reconnectDelay;

  /// Maximum delay between reconnect attempts.
  final Duration maxReconnectDelay;

  /// Maximum number of reconnect attempts before giving up (0 = infinite).
  final int maxRetries;

  /// Inactivity timeout. If no message is received within this window,
  /// a ping is sent to keep the connection alive.
  final Duration activityTimeout;

  /// How long to wait for a pong before closing and reconnecting.
  final Duration pongTimeout;

  /// Disable usage stat reporting in ping payloads.
  final bool disableStats;

  const AmarWaveConfig({
    required this.appKey,
    this.appSecret,
    this.wsHost = 'localhost',
    this.wsPort = 3001,
    this.wssPort = 443,
    this.apiHost,
    this.apiPort = 8000,
    this.apiPath = '/api/v1/trigger',
    this.wsPath = '/ws',
    this.forceTLS = false,
    this.authEndpoint = '/broadcasting/auth',
    this.authHeaders = const {},
    this.reconnectDelay = const Duration(seconds: 1),
    this.maxReconnectDelay = const Duration(seconds: 30),
    this.maxRetries = 5,
    this.activityTimeout = const Duration(seconds: 120),
    this.pongTimeout = const Duration(seconds: 30),
    this.disableStats = false,
  });

  /// The resolved API host (falls back to [wsHost] if [apiHost] is null).
  String get resolvedApiHost => apiHost ?? wsHost;
}
