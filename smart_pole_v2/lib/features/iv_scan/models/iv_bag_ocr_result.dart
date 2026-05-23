/// OCR 후보 타입
enum OcrCandidateType {
  volume,
  fluidName,
  concentration,
}

/// OCR 결과에서 추출된 개별 후보값
///
/// 디버깅과 confidence 계산에 사용.
/// 하나의 OCR 텍스트에서 여러 후보가 나올 수 있다.
class IVBagOcrCandidate {
  final OcrCandidateType type;
  final String value;
  final String normalizedValue;
  final double score;
  final String source; // 어떤 규칙으로 추출되었는지 (예: "regex_ml", "keyword_saline")

  const IVBagOcrCandidate({
    required this.type,
    required this.value,
    required this.normalizedValue,
    required this.score,
    required this.source,
  });

  @override
  String toString() =>
      'Candidate($type, "$value" → "$normalizedValue", score=$score, src=$source)';
}

/// 수액팩 OCR 파싱 결과 통합 모델
///
/// 파서가 생성하며, UI에서 판독 결과를 표시하고
/// confidence 기반 자동 확정 여부를 판단하는 데 사용한다.
class IVBagOcrResult {
  /// ML Kit에서 받은 원본 텍스트
  final String rawText;

  /// 정규화 처리된 텍스트
  final String normalizedText;

  /// 최종 선택된 수액 용량 (mL)
  final double? totalMl;

  /// OCR에서 읽은 약품명 원문
  final String? fluidName;

  /// 대표 약품명으로 정규화된 이름 (예: "생리식염수")
  final String? normalizedFluidName;

  /// 농도 (예: "0.9%")
  final String? concentration;

  /// 종합 신뢰도 (0.0 ~ 1.0)
  final double confidence;

  /// 사용자에게 표시할 경고 메시지 목록
  final List<String> warnings;

  /// 파싱 중 매칭된 키워드 목록
  final List<String> matchedKeywords;

  /// 파싱 중 발견된 모든 후보값
  final List<IVBagOcrCandidate> candidates;

  const IVBagOcrResult({
    required this.rawText,
    required this.normalizedText,
    this.totalMl,
    this.fluidName,
    this.normalizedFluidName,
    this.concentration,
    required this.confidence,
    required this.warnings,
    required this.matchedKeywords,
    required this.candidates,
  });

  /// 빈 결과 (OCR 실패 시)
  factory IVBagOcrResult.empty(String rawText) {
    return IVBagOcrResult(
      rawText: rawText,
      normalizedText: '',
      confidence: 0.0,
      warnings: ['텍스트를 인식하지 못했습니다.'],
      matchedKeywords: [],
      candidates: [],
    );
  }

  // ── 계산 getter ──

  bool get hasVolume => totalMl != null;

  bool get hasFluidName =>
      normalizedFluidName != null && normalizedFluidName!.isNotEmpty;

  /// confidence >= 0.90 이고 용량이 있으면 자동 확정 가능
  bool get canAutoConfirm => totalMl != null && confidence >= 0.90;

  /// 신뢰도 라벨
  String get confidenceLabel {
    if (confidence >= 0.90) return '자동 판독 가능';
    if (confidence >= 0.70) return '확인 필요';
    return '수동 입력 권장';
  }

  /// 판독 결과 요약 문자열 (UI 표시용)
  String get displaySummary {
    final parts = <String>[];

    if (normalizedFluidName != null) {
      parts.add(normalizedFluidName!);
    }
    if (totalMl != null) {
      parts.add('${totalMl!.toStringAsFixed(0)}mL');
    }
    if (concentration != null) {
      parts.add(concentration!);
    }

    if (parts.isEmpty) return '판독된 정보가 없습니다.';
    return parts.join(' / ');
  }

  /// 신뢰도 퍼센트 문자열 (예: "92%")
  String get confidencePercent => '${(confidence * 100).round()}%';

  @override
  String toString() =>
      'OcrResult(totalMl=$totalMl, fluid=$normalizedFluidName, '
      'conc=$concentration, confidence=${confidencePercent}, '
      'warnings=${warnings.length}, candidates=${candidates.length})';
}
