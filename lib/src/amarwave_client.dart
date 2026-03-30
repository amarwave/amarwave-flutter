import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import 'channel.dart';
import 'config.dart';
import 'connection.dart';
import 'crypto.dart' as aw_crypto;
import 'event_emitter.dart';

/// AmarWave real-time WebSocket client.
///
/// Example:
/// ```dart
/// final aw = AmarWave(
///   AmarWaveConfig(appKey: 'KEY', appSecret: 'SECRET'),
/// );
///
/// final ch = aw.subscribe('public-chat');
/// ch.bind('message', (data) => print(data));
/// ch.publish('message', {'user': 'Ali', 'text': 'Hello!'});
/// ```
class AmarWave extends EventEmitter {
  /// Socket ID assigned by the server. `null` when disconnected.
  String? socketId;

  /// Current connection state.
  AmarWaveState state = AmarWaveState.initialized;

  /// Connection proxy. Exposes [AmarWaveConnection.state] and
  /// [AmarWaveConnection.socketId], and lets you bind lifecycle events.
  late final AmarWaveConnection connection;

  // ── Private ────────────────────────────────────────────────────────────────

  final AmarWaveConfig _cfg;

  WebSocketChannel? _ws;
  StreamSubscription? _wsSub;

  final Map<String, AmarWaveChannel> _channels = {};

  int _retries = 0;
  bool _intentional = false;

  Timer? _actTimer;
  Timer? _pongTimer;
  Timer? _reTimer;

  // ── Constructor ────────────────────────────────────────────────────────────

  AmarWave(AmarWaveConfig config) : _cfg = config {
    connection = AmarWaveConnection(() => socketId);
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Open the WebSocket. No-op if already connected/connecting.
  void connect() {
    if (state == AmarWaveState.connecting ||
        state == AmarWaveState.connected) return;
    _intentional = false;
    _openSocket();
  }

  /// Close the connection. Auto-reconnect will not fire after this.
  void disconnect() {
    _intentional = true;
    _clearTimers();
    _ws?.sink.close(1000, 'user');
    _wsSub?.cancel();
    _ws = null;
    _setState(AmarWaveState.disconnected);
  }

  /// Subscribe to a channel. Auto-connects if needed.
  ///
  /// Returns the [AmarWaveChannel] immediately — safe to [AmarWaveChannel.bind]
  /// and [AmarWaveChannel.publish] before the subscription is confirmed.
  ///
  /// Example:
  /// ```dart
  /// final ch = aw.subscribe('public-chat');
  /// ch.bind('message', (data) => print(data));
  /// ```
  AmarWaveChannel subscribe(String channelName) {
    if (_channels.containsKey(channelName)) return _channels[channelName]!;

    final AmarWaveChannel ch;
    if (channelName.startsWith('presence-')) {
      ch = AmarWavePresenceChannel(channelName, _httpPublish);
    } else {
      ch = AmarWaveChannel(channelName, _httpPublish);
    }
    _channels[channelName] = ch;

    if (state == AmarWaveState.connected) {
      _doSubscribe(ch);
    } else {
      connect();
    }
    return ch;
  }

  /// Unsubscribe from a channel and remove it.
  void unsubscribe(String channelName) {
    if (!_channels.containsKey(channelName)) return;
    _channels.remove(channelName);
    _rawSend({'event': 'amarwave:unsubscribe', 'data': {'channel': channelName}});
  }

  /// Get an already-subscribed channel by name. Returns `null` if not found.
  AmarWaveChannel? channel(String channelName) => _channels[channelName];

  /// Top-level publish shortcut (no channel reference needed).
  ///
  /// POSTs to the HTTP API. Returns `true` on success, `false` on failure.
  ///
  /// Example:
  /// ```dart
  /// await aw.publish('public-chat', 'message', {'user': 'Ali', 'text': 'Hi'});
  /// ```
  Future<bool> publish(String channelName, String event, dynamic data) {
    return _httpPublish(channelName, event, data);
  }

  // ── HTTP publish ───────────────────────────────────────────────────────────

  /// @internal Called by Channel.publish() and aw.publish().
  Future<bool> _httpPublish(
      String channelName, String event, dynamic data) async {
    final c = _cfg;
    final proto = c.forceTLS ? 'https' : 'http';
    final url = Uri.parse(
        '$proto://${c.resolvedApiHost}:${c.apiPort}${c.apiPath}');

    try {
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'app_key': c.appKey,
          'app_secret': c.appSecret,
          'channel': channelName,
          'name': event,
          'data': data,
        }),
      );
      if (res.statusCode < 200 || res.statusCode >= 300) {
        // ignore: avoid_print
        print('[AmarWave] publish failed: HTTP ${res.statusCode} ${res.body.substring(0, min(res.body.length, 200))}');
        return false;
      }
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('[AmarWave] publish error: $e');
      return false;
    }
  }

  // ── WebSocket lifecycle ────────────────────────────────────────────────────

  Uri _buildWsUri() {
    final c = _cfg;
    final scheme = c.forceTLS ? 'wss' : 'ws';
    final port = c.forceTLS ? c.wssPort : c.wsPort;
    return Uri.parse(
        '$scheme://${c.wsHost}:$port${c.wsPath}?app_key=${Uri.encodeQueryComponent(c.appKey)}');
  }

  void _openSocket() {
    _setState(AmarWaveState.connecting);

    try {
      _ws = WebSocketChannel.connect(_buildWsUri());
    } catch (e) {
      _onError(e);
      return;
    }

    _wsSub = _ws!.stream.listen(
      _onRawMessage,
      onError: (_) => _onError(_),
      onDone: _onClose,
    );
    _resetActivity();
  }

  void _onRawMessage(dynamic raw) {
    _resetActivity();
    if (raw is! String) return;

    Map<String, dynamic> msg;
    try {
      msg = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    // Parse nested JSON string (server may send data as a JSON-encoded string)
    if (msg['data'] is String) {
      try {
        msg['data'] = jsonDecode(msg['data'] as String);
      } catch (_) {
        // leave as string
      }
    }

    _handleMessage(msg);
  }

  void _handleMessage(Map<String, dynamic> msg) {
    final event = msg['event'] as String? ?? '';
    final channelName = msg['channel'] as String?;
    final data = msg['data'];

    switch (event) {
      case 'amarwave:connection_established':
        final d = data as Map?;
        final sid = d?['socket_id'] as String?;
        if (sid != null) {
          socketId = sid;
          _retries = 0;
          _setState(AmarWaveState.connected);
          // Re-subscribe all channels (also handles reconnect)
          for (final ch in _channels.values) {
            ch.isSubscribed = false;
            _doSubscribe(ch);
          }
        }

      case 'amarwave:error':
        final errMsg = data is Map
            ? (data['message'] as String? ?? 'Server error')
            : data?.toString() ?? 'Server error';
        _onError(Exception(errMsg));

      case 'amarwave:pong':
        _clearPongTimer();

      case 'amarwave_internal:subscription_succeeded':
        if (channelName != null) {
          final ch = _channels[channelName];
          if (ch != null) {
            ch.isSubscribed = true;
            ch.fireEvent('subscribed', data);
            ch.fireEvent('amarwave_internal:subscription_succeeded', data);
            ch.flushQueue();
          }
        }

      case 'amarwave_internal:subscription_error':
        if (channelName != null) {
          _channels[channelName]?.fireEvent('error', data);
        }

      default:
        if (channelName != null && _channels.containsKey(channelName)) {
          _channels[channelName]!.fireEvent(event, data);
        }
        // Bubble to instance listeners
        emit(event, {'channel': channelName, 'data': data});
    }
  }

  void _onError(dynamic err) {
    emit('error', err);
    connection.fireState(state);
  }

  void _onClose() {
    _clearTimers();
    socketId = null;
    for (final ch in _channels.values) {
      ch.isSubscribed = false;
    }

    if (_intentional) {
      _setState(AmarWaveState.disconnected);
      return;
    }

    _setState(AmarWaveState.disconnected);

    final maxR = _cfg.maxRetries;
    if (maxR > 0 && _retries >= maxR) {
      // ignore: avoid_print
      print('[AmarWave] Max reconnect attempts reached.');
      _setState(AmarWaveState.failed);
      return;
    }

    final delay = _minDuration(
      Duration(
          milliseconds: (_cfg.reconnectDelay.inMilliseconds *
                  pow(2, _retries))
              .toInt()),
      _cfg.maxReconnectDelay,
    );
    _retries++;
    _reTimer = Timer(delay, _openSocket);
  }

  // ── Channel subscribe ──────────────────────────────────────────────────────

  void _doSubscribe(AmarWaveChannel ch) {
    final name = ch.name;
    final Map<String, dynamic> data = {'channel': name};

    if (name.startsWith('presence-')) {
      final secret = _cfg.appSecret;
      if (secret != null && secret.isNotEmpty) {
        final cd = jsonEncode({'user_id': aw_crypto.uid(), 'user_info': {}});
        final sig = aw_crypto.hmacSHA256(
            secret, '${socketId ?? ''}:$name:$cd');
        data['auth'] = '${_cfg.appKey}:$sig';
        data['channel_data'] = cd;
        _rawSend({'event': 'amarwave:subscribe', 'data': data});
      } else {
        _serverAuth(ch, data);
      }
    } else if (name.startsWith('private-')) {
      final secret = _cfg.appSecret;
      if (secret != null && secret.isNotEmpty) {
        final sig = aw_crypto.hmacSHA256(
            secret, '${socketId ?? ''}:$name');
        data['auth'] = '${_cfg.appKey}:$sig';
        _rawSend({'event': 'amarwave:subscribe', 'data': data});
      } else {
        _serverAuth(ch, data);
      }
    } else {
      _rawSend({'event': 'amarwave:subscribe', 'data': data});
    }
  }

  void _serverAuth(
      AmarWaveChannel ch, Map<String, dynamic> data) {
    final endpoint = _cfg.authEndpoint;
    final headers = <String, String>{
      'Content-Type': 'application/json',
      ..._cfg.authHeaders,
    };
    http
        .post(
          Uri.parse(endpoint),
          headers: headers,
          body: jsonEncode({
            'socket_id': socketId,
            'channel_name': ch.name,
          }),
        )
        .then((res) {
      if (res.statusCode < 200 || res.statusCode >= 300) {
        ch.fireEvent('error', 'Auth failed: HTTP ${res.statusCode}');
        return;
      }
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      data.addAll(json.map((k, v) => MapEntry(k, v)));
      _rawSend({'event': 'amarwave:subscribe', 'data': data});
    }).catchError((e) {
      ch.fireEvent('error', 'Auth request failed: $e');
    });
  }

  // ── Utilities ──────────────────────────────────────────────────────────────

  void _rawSend(Map<String, dynamic> payload) {
    try {
      _ws?.sink.add(jsonEncode(payload));
    } catch (e) {
      // ignore: avoid_print
      print('[AmarWave] send error: $e');
    }
  }

  void _setState(AmarWaveState s) {
    state = s;
    emit(s.name);
    connection.fireState(s);
  }

  void _resetActivity() {
    _clearActivityTimer();
    _actTimer = Timer(_cfg.activityTimeout, () {
      final ping = _cfg.disableStats
          ? {'event': 'amarwave:ping', 'data': {'stats': false}}
          : {'event': 'amarwave:ping', 'data': <String, dynamic>{}};
      _rawSend(ping);
      _pongTimer = Timer(_cfg.pongTimeout, () {
        // ignore: avoid_print
        print('[AmarWave] Pong timeout — reconnecting');
        _ws?.sink.close();
      });
    });
  }

  void _clearActivityTimer() {
    _actTimer?.cancel();
    _actTimer = null;
  }

  void _clearPongTimer() {
    _pongTimer?.cancel();
    _pongTimer = null;
  }

  void _clearTimers() {
    _clearActivityTimer();
    _clearPongTimer();
    _reTimer?.cancel();
    _reTimer = null;
  }

  Duration _minDuration(Duration a, Duration b) =>
      a.inMilliseconds < b.inMilliseconds ? a : b;
}
