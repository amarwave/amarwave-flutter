import 'event_emitter.dart';

/// All possible states of an AmarWave connection.
enum AmarWaveState {
  initialized,
  connecting,
  connected,
  disconnected,
  failed,
}

/// Connection proxy exposed as `aw.connection`.
///
/// Mirrors state and socketId from the parent [AmarWave] instance.
/// Useful for observing lifecycle events independently.
///
/// Example:
/// ```dart
/// aw.connection.bind('connected', (_) {
///   print('Socket ID: ${aw.connection.socketId}');
/// });
/// aw.connection.bind('disconnected', (_) {
///   print('Disconnected — retrying…');
/// });
/// ```
class AmarWaveConnection extends EventEmitter {
  AmarWaveState _state = AmarWaveState.initialized;

  final String? Function() _getSocketId;

  /// @internal
  AmarWaveConnection(this._getSocketId);

  /// Current connection state.
  AmarWaveState get state => _state;

  /// The socket ID assigned by the server. `null` when disconnected.
  String? get socketId => _getSocketId();

  /// @internal Called by [AmarWave] when state changes.
  void fireState(AmarWaveState newState, [dynamic data]) {
    _state = newState;
    emit(newState.name, data);
    emit('state_change', {
      'previous': _state.name,
      'current': newState.name,
    });
  }
}
