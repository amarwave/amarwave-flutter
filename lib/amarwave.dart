/// AmarWave — Official Dart/Flutter real-time WebSocket client SDK.
///
/// Provides a Pusher-compatible API for connecting to an AmarWave server,
/// subscribing to channels (public, private, presence), and publishing events.
///
/// Quick start:
/// ```dart
/// import 'package:amarwave/amarwave.dart';
///
/// void main() {
///   final aw = AmarWave(
///     AmarWaveConfig(appKey: 'YOUR_APP_KEY', appSecret: 'YOUR_APP_SECRET'),
///   );
///   aw.connect();
///
///   final ch = aw.subscribe('public-chat');
///   ch.bind('message', (data) => print('New message: $data'));
///   ch.publish('message', {'user': 'Alice', 'text': 'Hello!'});
/// }
/// ```
library amarwave;

export 'src/amarwave_client.dart';
export 'src/channel.dart';
export 'src/config.dart';
export 'src/connection.dart';
export 'src/event_emitter.dart';
