import 'dart:async';

/// Callback type for specific events.
typedef EventHandler = void Function(dynamic data);

/// Callback type for global (all-events) listeners.
typedef GlobalEventHandler = void Function(String event, dynamic data);

/// Minimal event emitter base class.
///
/// Used by both [AmarWave] (connection-level events) and [AmarWaveChannel]
/// (channel-level events).
class EventEmitter {
  final Map<String, List<EventHandler>> _listeners = {};
  final List<GlobalEventHandler> _globals = [];

  /// Register a listener for [event]. Multiple listeners per event are allowed.
  void bind(String event, EventHandler handler) {
    _listeners.putIfAbsent(event, () => []).add(handler);
  }

  /// Alias for [bind].
  void on(String event, EventHandler handler) => bind(event, handler);

  /// Remove a listener for [event].
  /// If [handler] is omitted, all listeners for that event are removed.
  void unbind(String event, [EventHandler? handler]) {
    if (handler == null) {
      _listeners.remove(event);
    } else {
      _listeners[event]?.remove(handler);
    }
  }

  /// Alias for [unbind].
  void off(String event, [EventHandler? handler]) => unbind(event, handler);

  /// Register a listener that fires for **every** event on this emitter.
  void bindGlobal(GlobalEventHandler handler) => _globals.add(handler);

  /// Remove a global listener (or all if [handler] is omitted).
  void unbindGlobal([GlobalEventHandler? handler]) {
    if (handler == null) {
      _globals.clear();
    } else {
      _globals.remove(handler);
    }
  }

  /// Returns a [Future] that resolves on the next emission of [event].
  /// Automatically removes itself after firing once.
  Future<dynamic> once(String event) {
    final completer = Completer<dynamic>();
    late EventHandler fn;
    fn = (data) {
      unbind(event, fn);
      if (!completer.isCompleted) completer.complete(data);
    };
    bind(event, fn);
    return completer.future;
  }

  /// @internal Emit [event] to all registered listeners.
  void emit(String event, [dynamic data]) {
    final handlers = List<EventHandler>.from(_listeners[event] ?? []);
    for (final h in handlers) {
      h(data);
    }
    final globals = List<GlobalEventHandler>.from(_globals);
    for (final g in globals) {
      g(event, data);
    }
  }
}
