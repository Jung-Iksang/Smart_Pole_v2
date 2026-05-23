import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// BLE 권한 체크 결과
enum BleReadiness {
  ready,
  bluetoothOff,
  permissionDenied,
  permissionPermanentlyDenied,
}

/// BLE 스캔 전 필요한 권한과 어댑터 상태를 확인합니다.
/// Android 12+: BLUETOOTH_SCAN + BLUETOOTH_CONNECT
/// Android 11-: ACCESS_FINE_LOCATION
/// iOS: flutter_blue_plus가 자동 처리
Future<BleReadiness> ensureBlePermissions() async {
  // 1. Bluetooth 어댑터 상태 체크
  final adapterState = await FlutterBluePlus.adapterState.first;
  if (adapterState != BluetoothAdapterState.on) {
    debugPrint('[BLE] Bluetooth 어댑터 꺼짐: $adapterState');
    return BleReadiness.bluetoothOff;
  }

  // 2. 플랫폼별 권한 요청
  if (Platform.isAndroid) {
    // Android 12+ (API 31+): BLUETOOTH_SCAN, BLUETOOTH_CONNECT
    // Android 11- (API 30-): ACCESS_FINE_LOCATION
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    debugPrint('[BLE] 권한 상태: $statuses');

    // 하나라도 영구 거부되었으면
    if (statuses.values.any((s) => s.isPermanentlyDenied)) {
      return BleReadiness.permissionPermanentlyDenied;
    }

    // BLE 스캔에 필요한 권한 중 하나라도 거부되었으면
    final scanGranted = statuses[Permission.bluetoothScan]?.isGranted ?? false;
    final connectGranted =
        statuses[Permission.bluetoothConnect]?.isGranted ?? false;
    final locationGranted =
        statuses[Permission.locationWhenInUse]?.isGranted ?? false;

    // Android 12+에서는 bluetoothScan이 핵심, 11-에서는 location이 핵심
    // 둘 다 요청하고 하나라도 되면 진행 가능
    if (!scanGranted && !locationGranted) {
      return BleReadiness.permissionDenied;
    }

    if (!connectGranted) {
      return BleReadiness.permissionDenied;
    }
  }

  // iOS: flutter_blue_plus가 CBManager 권한을 자동으로 요청
  return BleReadiness.ready;
}

/// BLE 준비 상태에 따른 사용자 메시지
String bleReadinessMessage(BleReadiness readiness) {
  switch (readiness) {
    case BleReadiness.ready:
      return '';
    case BleReadiness.bluetoothOff:
      return 'Bluetooth를 켜주세요.\n설정에서 Bluetooth를 활성화한 후 다시 시도해주세요.';
    case BleReadiness.permissionDenied:
      return 'BLE 검색을 위해 권한이 필요합니다.\n권한을 허용한 후 다시 시도해주세요.';
    case BleReadiness.permissionPermanentlyDenied:
      return '권한이 영구 거부되었습니다.\n설정 > 앱 > 권한에서 위치/Bluetooth 권한을 허용해주세요.';
  }
}
