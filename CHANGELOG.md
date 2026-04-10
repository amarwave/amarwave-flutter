# Changelog

All notable changes to the AmarWave Dart/Flutter SDK will be documented in this file.

## 1.0.0

- Initial stable release.
- WebSocket connection with exponential-backoff reconnect.
- Public, private (`private-`), and presence (`presence-`) channel support.
- Client-side HMAC-SHA256 auth via `appSecret` (dev/testing only).
- Server-side channel auth via configurable `authEndpoint`.
- `AmarWavePresenceChannel` with live `members` map, `memberCount`, and `me`.
- `channel.publish()` with pre-subscription queue (calls buffered until subscribed).
- Named cluster support (`cluster: 'default'` / `'local'` / `'eu'` etc.) — auto-resolves host and port.
- Ping/pong keepalive with configurable `activityTimeout` and `pongTimeout`.
- `connection.bind()` for lifecycle events (`connected`, `disconnected`, `state_change`, `error`).
- Full `AmarWaveConnection` proxy with `socketId` and `state` accessors.
