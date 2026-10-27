import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// 알림 타입별 UI 설정 (알림 화면, IV 상태 카드, 로컬 알림 제목에서 공용)
class AlertTypeConfig {
  final IconData icon;
  final Color color;
  final Color bg;
  final String label;

  /// true면 히어로/안전 카드가 빨간 "위험" 톤으로 바뀐다. false는 주황 "주의".
  final bool isDanger;

  const AlertTypeConfig({
    required this.icon,
    required this.color,
    required this.bg,
    required this.label,
    this.isDanger = false,
  });
}

const Map<String, AlertTypeConfig> alertTypeConfigs = {
  'low_fluid': AlertTypeConfig(
    icon: LucideIcons.droplets,
    color: Color(0xFF3B82F6),
    bg: Color(0xFFEFF6FF),
    label: '수액 잔량 부족',
  ),
  'flow_stop': AlertTypeConfig(
    icon: LucideIcons.alertOctagon,
    color: Color(0xFFEF4444),
    bg: Color(0xFFFEF2F2),
    label: '줄 꺾임·혈액 역류 가능',
    isDanger: true,
  ),
  'flow_fast': AlertTypeConfig(
    icon: LucideIcons.gauge,
    color: Color(0xFFEF4444),
    bg: Color(0xFFFEF2F2),
    label: '유속 과다',
    isDanger: true,
  ),
  'flow_slow': AlertTypeConfig(
    icon: LucideIcons.timer,
    color: Color(0xFFD97706),
    bg: Color(0xFFFFF7ED),
    label: '유속 느림',
  ),
};

const AlertTypeConfig defaultAlertTypeConfig = AlertTypeConfig(
  icon: LucideIcons.info,
  color: Color(0xFF94A3B8),
  bg: Color(0xFFF8FAFC),
  label: '알림',
);

AlertTypeConfig alertConfigFor(String type) =>
    alertTypeConfigs[type] ?? defaultAlertTypeConfig;

/// 해당 타입이 "위험(빨강)" 톤인지
bool isDangerAlertType(String type) => alertConfigFor(type).isDanger;
