# AmarWave Flutter / Dart SDK

Official Dart/Flutter client SDK for [AmarWave](https://github.com/amarwave/amarwave-flutter) — the self-hosted real-time WebSocket platform.

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  amarwave:
    path: ../sdk/flutter   # local path during development
    # OR from pub.dev once published:
    # amarwave: ^1.0.0
```

## Quick Start

```dart
import 'package:amarwave/amarwave.dart';

void main() {
  final aw = AmarWave(
    const AmarWaveConfig(
      appKey: 'YOUR_APP_KEY',
      cluster: 'default',   // resolves amarwave.com automatically
    ),
  );

  aw.connection.bind('connected', (_) {
    print('Connected! Socket ID: ${aw.connection.socketId}');
  });

  final ch = aw.subscribe('public-chat');

  ch.bind('message', (data) {
    print('New message: $data');
  });

  aw.connect();
}
```

## Configuration

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `appKey` | `String` | required | Your AmarWave application key |
| `cluster` | `String?` | `null` | Named cluster — auto-resolves host/port (`'default'`, `'local'`, `'eu'`, `'us'`, `'ap1'`, `'ap2'`) |
| `appSecret` | `String?` | `null` | App secret for client-side HMAC auth |
| `wsHost` | `String` | cluster value | WebSocket hostname override (self-hosted only) |
| `wsPort` | `int` | cluster value | WebSocket plain port override (self-hosted only) |
| `wssPort` | `int` | cluster value | WebSocket TLS port override |
| `apiHost` | `String?` | cluster value | HTTP API hostname override |
| `apiPort` | `int` | cluster value | HTTP API port override |
| `forceTLS` | `bool` | `false` | Force wss:// and https:// |
| `authEndpoint` | `String` | `'/broadcasting/auth'` | Server-side auth endpoint |
| `authHeaders` | `Map<String,String>` | `{}` | Extra auth request headers |
| `reconnectDelay` | `Duration` | `1s` | Base reconnect delay |
| `maxReconnectDelay` | `Duration` | `30s` | Max reconnect delay |
| `maxRetries` | `int` | `5` | Max retries (0 = infinite) |
| `activityTimeout` | `Duration` | `120s` | Ping inactivity timeout |
| `pongTimeout` | `Duration` | `30s` | Pong wait timeout |
| `disableStats` | `bool` | `false` | Disable usage stats in pings |

## Channel Types

### Public Channel

No authentication required.

```dart
final ch = aw.subscribe('public-chat');
ch.bind('message', (data) => print(data));
```

### Private Channel

Requires HMAC auth. Either set `appSecret` in config (client-side, **not for production**) or configure an `authEndpoint` on your backend.

```dart
final ch = aw.subscribe('private-orders');
ch.bind('order-placed', (data) => print(data));
```

### Presence Channel

Like private channels, but also tracks which members are subscribed.

```dart
final lobby = aw.subscribe('presence-lobby') as AmarWavePresenceChannel;

lobby.bind('subscribed', (_) {
  print('Members: ${lobby.memberCount}');
  print('All members: ${lobby.members}');
});

lobby.bind('amarwave_internal:member_added', (data) {
  print('Joined: $data');
});

lobby.bind('amarwave_internal:member_removed', (data) {
  print('Left: $data');
});
```

## Publishing Events

Events can be published via the HTTP API. This works from both client and server.

### Via channel reference

```dart
final ch = aw.subscribe('public-chat');
await ch.publish('message', {'user': 'Alice', 'text': 'Hello!'});
```

### Via top-level shortcut

```dart
await aw.publish('public-chat', 'message', {'user': 'Alice', 'text': 'Hello!'});
```

Publishing is queued automatically before subscription confirmation and flushed once the server confirms the subscription.

## Connection Lifecycle Events

Bind on `aw.connection` or directly on `aw`:

```dart
aw.connection.bind('connected', (_) => print('Connected'));
aw.connection.bind('disconnected', (_) => print('Disconnected'));
aw.connection.bind('connecting', (_) => print('Connecting...'));
aw.connection.bind('failed', (_) => print('Max retries exceeded'));
aw.bind('error', (err) => print('Error: $err'));
```

## Disconnect

```dart
aw.disconnect();
```

This stops all reconnect attempts and closes the WebSocket cleanly.

## Unsubscribe

```dart
aw.unsubscribe('public-chat');
```

## Global Event Listener

Listen to every event on a channel:

```dart
ch.bindGlobal((event, data) => print('Event: $event, Data: $data'));
```

## Server-Side Auth Endpoint

For private/presence channels in production, implement an auth endpoint on your backend:

```
POST /broadcasting/auth
Body: { "socket_id": "...", "channel_name": "private-orders" }
Response: { "auth": "<appKey>:<hmac_signature>" }
```

The PHP SDK ships with `authenticate()` and `authenticatePresence()` helpers for this.

## License

MIT
