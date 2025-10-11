import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';

class EchoService {
  static PusherChannelsFlutter? _pusher;
  static final _storage = const FlutterSecureStorage();
  static final Map<String, Map<String, Function(dynamic)>> _listeners = {};
  static bool _isConnecting = false;

  static Future<void> connect() async {
    if (_pusher != null || _isConnecting) {
      return;
    }

    _isConnecting = true;

    try {
      final token = await _storage.read(key: 'auth_token');
      if (token == null) {
        _isConnecting = false;
        return;
      }

      _pusher = PusherChannelsFlutter.getInstance();

      await _pusher!.init(
        apiKey: AppConfig.pusherAppKey,
        cluster: AppConfig.pusherCluster,
        onConnectionStateChange: (state, previousState) {
          if (kDebugMode) {
            print('Pusher connection state: $previousState -> $state');
          }

          // Handle disconnection - don't reset immediately, allow reconnection
          if (state == 'DISCONNECTED') {
            if (kDebugMode) {
              print('Pusher disconnected, will attempt reconnection automatically');
            }
          }
        },
        onError: (message, code, error) {
          if (kDebugMode) {
            print('Pusher error: $message (code: $code)');
          }

          // Only reset on critical auth errors, not on network issues
          if (code != null && (code == 4001 || code == 4004 || code == 4009)) {
            if (kDebugMode) {
              print('Critical Pusher error, resetting connection');
            }
            _pusher = null;
            _isConnecting = false;
          }
        },
        onEvent: (event) {
          final channelName = event.channelName;
          final eventName = event.eventName;
          final eventData = event.data;

          if (_listeners.containsKey(channelName) &&
              _listeners[channelName]!.containsKey(eventName)) {
            _listeners[channelName]![eventName]!(eventData);
          }
        },
      );

      await _pusher!.connect();
      _isConnecting = false;
    } catch (e) {
      if (kDebugMode) {
        print('Pusher connection error: $e');
      }
      _pusher = null;
      _isConnecting = false;
    }
  }

  static Future<void> subscribe(String channelName) async {
    if (_pusher == null) {
      if (kDebugMode) {
        print('Cannot subscribe to $channelName: Pusher not connected');
      }
      return;
    }

    try {
      await _pusher!.subscribe(channelName: channelName);
    } catch (e) {
      if (kDebugMode) {
        print('Error subscribing to $channelName: $e');
      }
    }
  }

  static void listen(String channelName, String eventName, Function(dynamic) callback) {
    if (!_listeners.containsKey(channelName)) {
      _listeners[channelName] = {};
    }
    _listeners[channelName]![eventName] = callback;
  }

  static void stopListening(String channelName, String eventName) {
    if (_listeners.containsKey(channelName)) {
      _listeners[channelName]!.remove(eventName);
      if (_listeners[channelName]!.isEmpty) {
        _listeners.remove(channelName);
      }
    }
  }

  static Future<void> unsubscribe(String channelName) async {
    if (_pusher == null) return;

    try {
      await _pusher!.unsubscribe(channelName: channelName);
      _listeners.remove(channelName);
    } catch (e) {
      if (kDebugMode) {
        print('Error unsubscribing from $channelName: $e');
      }
      // Still remove listeners even if unsubscribe fails
      _listeners.remove(channelName);
    }
  }

  static Future<void> disconnect() async {
    try {
      await _pusher?.disconnect();
    } catch (e) {
      if (kDebugMode) {
        print('Error disconnecting Pusher: $e');
      }
    } finally {
      _pusher = null;
      _isConnecting = false;
      _listeners.clear();
    }
  }
}
