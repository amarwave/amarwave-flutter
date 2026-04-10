// ignore_for_file: constant_identifier_names

// ─── Cluster map ─────────────────────────────────────────────────────────────

class _ClusterEntry {
  final String wsHost;
  final int wsPort;
  final int wssPort;
  final String apiHost;
  final int apiPort;
  const _ClusterEntry(
      this.wsHost, this.wsPort, this.wssPort, this.apiHost, this.apiPort);
}

/// Maps cluster shorthand names to their resolved WebSocket and API endpoints.
///
/// Both `"default"` and named clusters resolve to `amarwave.com`.
/// Use `"local"` to connect to a self-hosted server on localhost.
const Map<String, _ClusterEntry> _clusters = {
  'default': _ClusterEntry('amarwave.com', 80, 443, 'amarwave.com', 443),
  'local':   _ClusterEntry('localhost',   3001, 3001, 'localhost',  8000),
  'eu':      _ClusterEntry('amarwave.com', 80, 443, 'amarwave.com', 443),
  'us':      _ClusterEntry('amarwave.com', 80, 443, 'amarwave.com', 443),
  'ap1':     _ClusterEntry('amarwave.com', 80, 443, 'amarwave.com', 443),
  'ap2':     _ClusterEntry('amarwave.com', 80, 443, 'amarwave.com', 443),
};

// ─── AmarWaveConfig ───────────────────────────────────────────────────────────

/// Configuration for the AmarWave WebSocket client.
///
/// Only [appKey] is required. Use [cluster] to connect to a named AmarWave
/// cluster — all host/port values are resolved automatically.
///
/// Example (cloud):
/// ```dart
/// final aw = AmarWave(
///   AmarWaveConfig(
///     appKey: 'my-app-key',
///     cluster: 'default',   // resolves amarwave.com automatically
///   ),
/// );
/// ```
///
/// Example (self-hosted):
/// ```dart
/// final aw = AmarWave(
///   AmarWaveConfig(
///     appKey: 'my-app-key',
///     wsHost: 'ws.example.com',
///     wsPort: 3001,
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

  /// Named cluster shorthand. Automatically resolves [wsHost], [wsPort],
  /// [wssPort], [apiHost], and [apiPort].
  ///
  /// Built-in clusters: `'default'`, `'local'`, `'eu'`, `'us'`, `'ap1'`, `'ap2'`.
  ///
  /// When set, explicit [wsHost]/[wsPort] values still take priority if they
  /// differ from their defaults (`'localhost'` / `3001`).
  final String? cluster;

  /// WebSocket server hostname override.
  /// Leave `null` (or omit) when using [cluster].
  final String wsHost;

  /// WebSocket plain port (ws://) override.
  /// Leave at default `3001` (or omit) when using [cluster].
  final int wsPort;

  /// WebSocket TLS port (wss://). Used when [forceTLS] is true. Default: `443`.
  final int wssPort;

  /// HTTP API hostname for publishing events.
  /// Defaults to the cluster's API host, then falls back to [wsHost].
  final String? apiHost;

  /// HTTP API port. Default: `8000` (overridden by cluster when using [cluster]).
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
    this.cluster,
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

  // ── Resolved accessors ────────────────────────────────────────────────────

  /// Returns the cluster entry for [cluster], if set.
  _ClusterEntry? get _entry => cluster != null ? _clusters[cluster!] : null;

  /// Resolved WebSocket hostname.
  /// Cluster value is used when [wsHost] was not explicitly changed from its
  /// default of `'localhost'`.
  String get resolvedWsHost {
    final e = _entry;
    if (e != null && wsHost == 'localhost') return e.wsHost;
    return wsHost;
  }

  /// Resolved plain WebSocket port.
  /// Cluster value is used when [wsPort] was not explicitly changed from its
  /// default of `3001`.
  int get resolvedWsPort {
    final e = _entry;
    if (e != null && wsPort == 3001) return e.wsPort;
    return wsPort;
  }

  /// Resolved TLS WebSocket port.
  /// Cluster value is used when [wssPort] was not explicitly changed from its
  /// default of `443`.
  int get resolvedWssPort {
    final e = _entry;
    if (e != null && wssPort == 443) return e.wssPort;
    return wssPort;
  }

  /// Resolved HTTP API hostname.
  String get resolvedApiHost {
    if (apiHost != null) return apiHost!;
    final e = _entry;
    if (e != null) return e.apiHost;
    return wsHost;
  }

  /// Resolved HTTP API port.
  /// Cluster value is used when [apiPort] was not explicitly changed from its
  /// default of `8000`.
  int get resolvedApiPort {
    if (apiHost != null) return apiPort; // explicit apiHost → trust apiPort
    final e = _entry;
    if (e != null && apiPort == 8000) return e.apiPort;
    return apiPort;
  }
}
