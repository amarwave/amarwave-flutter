// ignore_for_file: avoid_print

import 'package:amarwave/amarwave.dart';

/// Basic example: connect, subscribe to a public channel, publish events.
void main() async {
  final aw = AmarWave(
    const AmarWaveConfig(
      appKey: 'YOUR_APP_KEY',
      appSecret: 'YOUR_APP_SECRET', // optional — enables client-side HMAC auth
      wsHost: 'localhost',
      wsPort: 3001,
      apiHost: 'localhost',
      apiPort: 8000,
    ),
  );

  // ── Connection lifecycle ─────────────────────────────────────────────────

  aw.connection.bind('connected', (_) {
    print('✅ Connected! Socket ID: ${aw.connection.socketId}');
  });

  aw.connection.bind('disconnected', (_) {
    print('🔌 Disconnected.');
  });

  aw.bind('error', (err) {
    print('❌ Error: $err');
  });

  // ── Public channel ───────────────────────────────────────────────────────

  final chat = aw.subscribe('public-chat');

  chat.bind('subscribed', (_) {
    print('📡 Subscribed to public-chat');
  });

  chat.bind('message', (data) {
    print('💬 Message: $data');
  });

  // ── Private channel (requires appSecret or authEndpoint) ─────────────────

  final orders = aw.subscribe('private-orders');

  orders.bind('subscribed', (_) {
    print('🔒 Subscribed to private-orders');
  });

  orders.bind('order-placed', (data) {
    print('🛒 Order: $data');
  });

  // ── Presence channel ─────────────────────────────────────────────────────

  final lobby = aw.subscribe('presence-lobby') as AmarWavePresenceChannel;

  lobby.bind('subscribed', (_) {
    print('👥 In lobby. Members: ${lobby.memberCount}');
  });

  lobby.bind('amarwave_internal:member_added', (_) {
    print('➕ Member joined. Total: ${lobby.memberCount}');
  });

  lobby.bind('amarwave_internal:member_removed', (_) {
    print('➖ Member left. Total: ${lobby.memberCount}');
  });

  // ── Open connection ──────────────────────────────────────────────────────

  aw.connect();

  // ── Publish after 2 seconds ──────────────────────────────────────────────

  await Future.delayed(const Duration(seconds: 2));

  final ok = await aw.publish('public-chat', 'message', {
    'user': 'Alice',
    'text': 'Hello from Flutter!',
  });
  print('Publish result: $ok');

  // Keep running for 10 seconds then disconnect.
  await Future.delayed(const Duration(seconds: 10));
  aw.disconnect();
}
