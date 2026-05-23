import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/device_data.dart';

/// WebSocket 실시간 측정 데이터 서비스 — 지수 백오프 재연결
class RealtimeService {
  static const String _wsBaseUrl = 'ws://192.168.0.19:8000/api/v1';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  WebSocketChannel? _channel;
  StreamController<MeasurementUpdate>? _controller;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  int? _currentDeviceId;

  /// 재연결 지수 백오프 (초)
  int _reconnectDelaySec = 1;
  static const int _maxReconnectDelaySec = 30;

  /// 특정 기기의 실시간 데이터 스트림에 연결
  Stream<MeasurementUpdate> connect(int deviceId) {
    // 이전 연결 정리
    if (_currentDeviceId != deviceId) {
      disconnect();
    }

    if (_controller != null && !_controller!.isClosed) {
      return _controller!.stream;
    }

    _currentDeviceId = deviceId;
    _reconnectDelaySec = 1;   // 새 연결 시 백오프 리셋
    _controller = StreamController<MeasurementUpdate>.broadcast(
      onCancel: disconnect,
    );

    _establishConnection(deviceId);
    return _controller!.stream;
  }

  Future<void> _establishConnection(int deviceId) async {
    try {
      final token = await _storage.read(key: 'access_token');
      if (token == null) {
        _controller?.addError(Exception('인증 토큰이 없습니다'));
        return;
      }

      final uri = Uri.parse(
        '$_wsBaseUrl/measurements/$deviceId/realtime?token=$token',
      );

      _channel = WebSocketChannel.connect(uri);

      // 연결 대기
      await _channel!.ready;

      // 연결 성공 → 백오프 리셋
      _reconnectDelaySec = 1;
      debugPrint('[WS] 연결 성공 (deviceId: $deviceId)');

      // 30초마다 ping 전송 (연결 유지)
      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        try {
          _channel?.sink.add('ping');
        } catch (_) {}
      });

      // 메시지 수신
      _channel!.stream.listen(
        (data) {
          try {
            final json = jsonDecode(data as String) as Map<String, dynamic>;
            final update = MeasurementUpdate.fromJson(json);
            _controller?.add(update);
          } catch (e) {
            debugPrint('[WS] 데이터 파싱 오류: $e');
          }
        },
        onError: (error) {
          debugPrint('[WS] 에러: $error');
          _scheduleReconnect(deviceId);
        },
        onDone: () {
          debugPrint('[WS] 연결 종료');
          _scheduleReconnect(deviceId);
        },
      );
    } catch (e) {
      debugPrint('[WS] 연결 실패: $e');
      _scheduleReconnect(deviceId);
    }
  }

  void _scheduleReconnect(int deviceId) {
    if (_controller == null || _controller!.isClosed) return;

    _pingTimer?.cancel();
    _reconnectTimer?.cancel();

    final delay = _reconnectDelaySec;
    // 지수 백오프: 1s → 2s → 4s → 8s → ... → 30s (최대)
    _reconnectDelaySec = min(_reconnectDelaySec * 2, _maxReconnectDelaySec);

    debugPrint('[WS] $delay초 후 재연결 시도 (다음 백오프: ${_reconnectDelaySec}s)');

    _reconnectTimer = Timer(Duration(seconds: delay), () {
      if (_controller != null && !_controller!.isClosed) {
        _establishConnection(deviceId);
      }
    });
  }

  /// 연결 해제
  void disconnect() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _channel?.sink.close();
    _channel = null;
    _controller?.close();
    _controller = null;
    _currentDeviceId = null;
    _reconnectDelaySec = 1;
  }

  void dispose() {
    disconnect();
  }
}
