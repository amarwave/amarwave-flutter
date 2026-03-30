import 'dart:async';

import 'event_emitter.dart';

typedef _HttpPublish = Future<bool> Function(
    String channel, String event, dynamic data);

class _QueuedPublish {
  final String event;
  final dynamic data;
  final Completer<bool> completer;
  _QueuedPublish(
      {required this.event, required this.data, required this.completer});
}

/// Represents a subscription to a named channel on the AmarWave server.
///
/// Obtained via `aw.subscribe('channel-name')` — never constructed directly.
///
/// Example:
/// ```dart
/// final ch = aw.subscribe('public-chat');
/// ch.bind('message', (data) => print(data));
/// ch.publish('message', {'user': 'Ali', 'text': 'Hello!'});
/// ```
class AmarWaveChannel extends EventEmitter {
  /// The channel name (e.g. `"public-chat"`, `"private-orders"`).
  final String name;

  /// `true` once the server has confirmed the subscription.
  bool isSubscribed = false;

  final _HttpPublish _httpPublish;
  final List<_QueuedPublish> _queue = [];

  /// @internal
  AmarWaveChannel(this.name, this._httpPublish);

  /// Publish an event to this channel via the HTTP API.
  ///
  /// Safe to call before [isSubscribed] is true — the call is queued and
  /// flushed automatically once the subscription is confirmed.
  ///
  /// Returns `true` on success, `false` on failure.
  ///
  /// Example:
  /// ```dart
  /// await ch.publish('message', {'user': 'Ali', 'text': 'Hello!'});
  /// ```
  Future<bool> publish(String event, dynamic data) {
    if (!isSubscribed) {
      final completer = Completer<bool>();
      _queue.add(_QueuedPublish(
          event: event, data: data, completer: completer));
      return completer.future;
    }
    return _httpPublish(name, event, data);
  }

  /// Alias for [publish]. Kept for Pusher-compatible API.
  Future<bool> trigger(String event, dynamic data) => publish(event, data);

  /// @internal Called when subscription_succeeded arrives.
  void flushQueue() {
    final items = List<_QueuedPublish>.from(_queue);
    _queue.clear();
    for (final item in items) {
      _httpPublish(name, item.event, item.data)
          .then(item.completer.complete)
          .catchError((_) => item.completer.complete(false));
    }
  }

  /// @internal Delegate to the base emitter.
  void fireEvent(String event, [dynamic data]) => emit(event, data);
}

/// A presence channel that tracks which members are currently subscribed.
///
/// Example:
/// ```dart
/// final presence = aw.subscribe('presence-lobby') as AmarWavePresenceChannel;
///
/// presence.bind('member_added', (_) {
///   print('Members now: ${presence.memberCount}');
/// });
/// ```
class AmarWavePresenceChannel extends AmarWaveChannel {
  /// All currently subscribed members, keyed by their `user_id`.
  final Map<String, dynamic> members = {};

  /// The current user's presence data (set when subscription is confirmed).
  Map<String, dynamic>? me;

  /// Number of members currently subscribed to this channel.
  int get memberCount => members.length;

  /// @internal
  AmarWavePresenceChannel(super.name, super.httpPublish);

  @override
  void fireEvent(String event, [dynamic data]) {
    switch (event) {
      case 'amarwave_internal:subscription_succeeded':
      case 'subscribed':
        if (data is Map) {
          final presence = data['presence'];
          if (presence is Map) {
            final hash = presence['hash'];
            if (hash is Map) {
              members.clear();
              hash.forEach((k, v) => members[k.toString()] = v);
            }
          }
        }

      case 'amarwave_internal:member_added':
        if (data is Map) {
          final userId = data['user_id']?.toString();
          if (userId != null) {
            members[userId] = data['user_info'] ?? {};
          }
        }

      case 'amarwave_internal:member_removed':
        if (data is Map) {
          final userId = data['user_id']?.toString();
          if (userId != null) members.remove(userId);
        }
    }
    super.fireEvent(event, data);
  }
}
