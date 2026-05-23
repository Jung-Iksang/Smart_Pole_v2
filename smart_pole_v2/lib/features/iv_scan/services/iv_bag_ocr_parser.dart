import 'dart:math' as math;

import '../models/iv_bag_ocr_result.dart';

/// 수액팩 OCR 텍스트 파서
///
/// Google ML Kit Text Recognition 결과를 받아서
/// 용량, 약품명, 농도를 구조적으로 추출하고 confidence score를 산출한다.
///
/// 설계 원칙:
/// - 순수 함수 기반 (static) → 테스트 용이
/// - 의료 보조 목적이므로 오탐 방지 우선
/// - confidence가 높아도 최종 확인은 사용자에게 위임
class IVBagOcrParser {
  IVBagOcrParser._();

  /// 대표 수액 용량 (우선순위 높은 값)
  static const _standardVolumes = [50.0, 100.0, 250.0, 500.0, 1000.0];

  /// 유효 용량 범위
  static const _minVolume = 50.0;
  static const _maxVolume = 5000.0;

  /// 약품군 정의: 대표명 → 키워드 패턴 목록
  /// 각 패턴은 (regex문자열, score) 쌍.
  /// 긴 패턴이 앞에 오도록 정렬하여 더 구체적인 매칭 우선.
  static final _fluidDatabase = <String, List<_FluidPattern>>{
    '생리식염수': [
      _FluidPattern(r'생리식염수', 1.0),
      _FluidPattern(r'식염수', 0.9),
      _FluidPattern(r'sodium\s*chlorid[e]?', 0.95),
      _FluidPattern(r'normal\s*saline', 0.95),
      _FluidPattern(r'0\.9\s*%\s*(?:nacl|sodium|ns)', 0.9),
      _FluidPattern(r'\bnacl\b', 0.7),
      _FluidPattern(r'\bns\b', 0.5), // 짧은 약어는 낮은 점수
    ],
    '포도당': [
      _FluidPattern(r'포도당', 1.0),
      _FluidPattern(r'dextrose', 0.95),
      _FluidPattern(r'glucose', 0.9),
      _FluidPattern(r'\bd5w\b', 0.85),
      _FluidPattern(r'\bd10w\b', 0.85),
      _FluidPattern(r'5\s*%\s*dextrose', 0.95),
      _FluidPattern(r'10\s*%\s*dextrose', 0.95),
      _FluidPattern(r'5\s*%\s*glucose', 0.95),
    ],
    '하트만': [
      _FluidPattern(r'하트만', 1.0),
      _FluidPattern(r"hartmann'?s?\s*solution", 0.95),
      _FluidPattern(r'hartmann', 0.9),
      _FluidPattern(r'hartman(?!n)', 0.85), // 오타 허용
      _FluidPattern(r"lactated\s*ringer'?s?", 0.9),
    ],
    '링거': [
      _FluidPattern(r'링거', 1.0),
      _FluidPattern(r"ringer'?s?\s*(?:solution|lactate)", 0.9),
      _FluidPattern(r"ringer'?s?", 0.7),
      _FluidPattern(r'\blr\b', 0.5),
    ],
    '아미노산': [
      _FluidPattern(r'아미노산', 1.0),
      _FluidPattern(r'amino\s*acids?', 0.95),
    ],
    '알부민': [
      _FluidPattern(r'알부민', 1.0),
      _FluidPattern(r'albumin', 0.95),
    ],
  };

  /// 약품명+농도 유효 조합 (정상적인 약품 구성)
  static const _knownCombinations = <String, List<String>>{
    '생리식염수': ['0.9%', '0.45%', '3%'],
    '포도당': ['5%', '10%', '20%', '50%'],
    '알부민': ['5%', '20%', '25%'],
  };

  // ── 메인 파싱 메서드 ──

  /// OCR 원본 텍스트를 파싱하여 구조화된 결과를 반환한다.
  static IVBagOcrResult parse(String rawText) {
    if (rawText.trim().isEmpty) {
      return IVBagOcrResult.empty(rawText);
    }

    final normalized = _normalizeText(rawText);
    final candidates = <IVBagOcrCandidate>[];
    final matchedKeywords = <String>[];

    // 1. 용량 추출
    final volumeResult = _extractVolume(normalized);
    candidates.addAll(volumeResult.candidates);

    // 2. 약품명 추출
    final fluidResult = _extractFluidName(normalized);
    candidates.addAll(fluidResult.candidates);
    matchedKeywords.addAll(fluidResult.matchedKeywords);

    // 3. 농도 추출
    final concResult = _extractConcentration(normalized);
    candidates.addAll(concResult.candidates);

    // 4. confidence 계산
    final confidence = _calculateConfidence(
      totalMl: volumeResult.bestValue,
      volumeCandidateCount: volumeResult.candidates.length,
      normalizedFluidName: fluidResult.bestNormalizedName,
      fluidCandidateNames:
          fluidResult.candidates.map((c) => c.normalizedValue).toSet(),
      concentration: concResult.bestValue,
      matchedKeywords: matchedKeywords,
      textLength: normalized.length,
    );

    // 5. 경고 생성
    final warnings = _buildWarnings(
      totalMl: volumeResult.bestValue,
      volumeCandidateCount: volumeResult.candidates.length,
      normalizedFluidName: fluidResult.bestNormalizedName,
      confidence: confidence,
    );

    return IVBagOcrResult(
      rawText: rawText,
      normalizedText: normalized,
      totalMl: volumeResult.bestValue,
      fluidName: fluidResult.bestRawName,
      normalizedFluidName: fluidResult.bestNormalizedName,
      concentration: concResult.bestValue,
      confidence: confidence,
      warnings: warnings,
      matchedKeywords: matchedKeywords,
      candidates: candidates,
    );
  }

  // ── 텍스트 정규화 ──

  /// OCR 원본 텍스트를 정규화한다.
  ///
  /// - 소문자화
  /// - 줄바꿈 → 공백
  /// - 유니코드 mL 변환 (㎖, ｍｌ, mℓ 등)
  /// - OCR 오류 보정 (O→0, I→1 숫자 문맥에서)
  /// - 연속 공백 제거
  static String _normalizeText(String text) {
    var t = text.toLowerCase();

    // 줄바꿈 → 공백
    t = t.replaceAll(RegExp(r'[\r\n]+'), ' ');

    // 유니코드 단위 정규화
    t = t.replaceAll('㎖', 'ml');
    t = t.replaceAll('ｍｌ', 'ml');
    t = t.replaceAll('mℓ', 'ml');
    t = t.replaceAll('ℓ', 'l');

    // OCR 오류 보정: 숫자 문맥에서 O/o → 0, I/l → 1
    // "5OO" → "500", "1OOO" → "1000", "1O0" → "100"
    t = t.replaceAllMapped(
      RegExp(r'(\d)[OoОо]([OoОо\d])'),
      (m) => '${m[1]}0${m[2]!.replaceAll(RegExp(r'[OoОо]'), '0')}',
    );
    // 남은 숫자 사이 O 보정
    t = t.replaceAllMapped(
      RegExp(r'(\d)[OoОо](\d)'),
      (m) => '${m[1]}0${m[2]}',
    );
    // 숫자 앞 O 보정 ("O.9%" → "0.9%")
    t = t.replaceAllMapped(
      RegExp(r'\b[Oo](\.\d)'),
      (m) => '0${m[1]}',
    );

    // 연속 공백 제거
    t = t.replaceAll(RegExp(r'\s{2,}'), ' ').trim();

    return t;
  }

  // ── 용량 추출 ──

  static _VolumeExtractionResult _extractVolume(String text) {
    final candidates = <IVBagOcrCandidate>[];

    // 패턴 1: 숫자 + mL (가장 일반적)
    final mlRegex = RegExp(r'(\d{2,5})\s*ml\b');
    for (final m in mlRegex.allMatches(text)) {
      final value = double.tryParse(m.group(1)!);
      if (value != null && value >= _minVolume && value <= _maxVolume) {
        final isStandard = _standardVolumes.contains(value);
        // "내용량", "용량", "total", "volume" 근처인지 확인
        final nearLabel = _isNearVolumeLabel(text, m.start);
        final score = (isStandard ? 0.8 : 0.5) + (nearLabel ? 0.15 : 0.0);
        candidates.add(IVBagOcrCandidate(
          type: OcrCandidateType.volume,
          value: m.group(0)!,
          normalizedValue: '${value.toStringAsFixed(0)}ml',
          score: score,
          source: 'regex_ml${nearLabel ? '_labeled' : ''}',
        ));
      }
    }

    // 패턴 2: 숫자 + L (리터)
    final literRegex = RegExp(r'(\d+(?:\.\d+)?)\s*(?:l\b|리터|liter|litre)');
    for (final m in literRegex.allMatches(text)) {
      final liters = double.tryParse(m.group(1)!);
      if (liters != null) {
        final ml = liters * 1000;
        if (ml >= _minVolume && ml <= _maxVolume) {
          final isStandard = _standardVolumes.contains(ml);
          candidates.add(IVBagOcrCandidate(
            type: OcrCandidateType.volume,
            value: m.group(0)!,
            normalizedValue: '${ml.toStringAsFixed(0)}ml',
            score: isStandard ? 0.75 : 0.5,
            source: 'regex_liter',
          ));
        }
      }
    }

    // 최선 후보 선택: score 기준 내림차순
    candidates.sort((a, b) => b.score.compareTo(a.score));

    double? best;
    if (candidates.isNotEmpty) {
      best = double.tryParse(
        candidates.first.normalizedValue.replaceAll('ml', ''),
      );
    }

    return _VolumeExtractionResult(bestValue: best, candidates: candidates);
  }

  /// 텍스트에서 특정 위치 근처에 용량 관련 라벨이 있는지 확인
  static bool _isNearVolumeLabel(String text, int position) {
    // 매치 위치 앞 40자 범위에서 라벨 검색
    final start = math.max(0, position - 40);
    final context = text.substring(start, position);
    return RegExp(r'내용량|용량|total|volume|content').hasMatch(context);
  }

  // ── 약품명 추출 ──

  static _FluidExtractionResult _extractFluidName(String text) {
    final candidates = <IVBagOcrCandidate>[];
    final matchedKeywords = <String>[];

    // 각 약품군의 패턴을 순회하며 매칭
    for (final entry in _fluidDatabase.entries) {
      final normalizedName = entry.key;
      final patterns = entry.value;

      for (final pattern in patterns) {
        final regex = RegExp(pattern.pattern, caseSensitive: false);
        final match = regex.firstMatch(text);

        if (match != null) {
          final matchedText = match.group(0)!;
          matchedKeywords.add(matchedText);

          candidates.add(IVBagOcrCandidate(
            type: OcrCandidateType.fluidName,
            value: matchedText,
            normalizedValue: normalizedName,
            score: pattern.score,
            source: 'keyword_${normalizedName}',
          ));

          // 같은 약품군에서 가장 높은 점수 패턴만 취함
          break;
        }
      }
    }

    // score 내림차순 정렬
    candidates.sort((a, b) => b.score.compareTo(a.score));

    String? bestRaw;
    String? bestNormalized;
    if (candidates.isNotEmpty) {
      bestRaw = candidates.first.value;
      bestNormalized = candidates.first.normalizedValue;
    }

    return _FluidExtractionResult(
      bestRawName: bestRaw,
      bestNormalizedName: bestNormalized,
      candidates: candidates,
      matchedKeywords: matchedKeywords,
    );
  }

  // ── 농도 추출 ──

  static _ConcentrationExtractionResult _extractConcentration(String text) {
    final candidates = <IVBagOcrCandidate>[];

    // 숫자(정수 또는 소수) + % 패턴
    final regex = RegExp(r'(\d+(?:\.\d+)?)\s*%');
    for (final m in regex.allMatches(text)) {
      final raw = m.group(0)!;
      final number = m.group(1)!;
      // 정규화: 공백 제거
      final normalized = '$number%';

      // 100% 초과는 농도가 아님
      final value = double.tryParse(number);
      if (value == null || value > 100 || value <= 0) continue;

      // 일반적인 수액 농도 범위 (0.45% ~ 50%)
      final isTypical =
          value == 0.45 || value == 0.9 || value == 3 ||
          value == 5 || value == 10 || value == 20 ||
          value == 25 || value == 50;

      candidates.add(IVBagOcrCandidate(
        type: OcrCandidateType.concentration,
        value: raw,
        normalizedValue: normalized,
        score: isTypical ? 0.8 : 0.4,
        source: 'regex_percent',
      ));
    }

    candidates.sort((a, b) => b.score.compareTo(a.score));

    return _ConcentrationExtractionResult(
      bestValue: candidates.isNotEmpty ? candidates.first.normalizedValue : null,
      candidates: candidates,
    );
  }

  // ── Confidence 계산 ──

  static double _calculateConfidence({
    required double? totalMl,
    required int volumeCandidateCount,
    required String? normalizedFluidName,
    required Set<String> fluidCandidateNames,
    required String? concentration,
    required List<String> matchedKeywords,
    required int textLength,
  }) {
    var score = 0.0;

    // 가산 항목
    if (totalMl != null) {
      score += 0.35;
      if (_standardVolumes.contains(totalMl)) {
        score += 0.15;
      }
    }

    if (normalizedFluidName != null) {
      score += 0.20;
    }

    if (concentration != null) {
      score += 0.10;
    }

    // 약품명+농도 조합이 알려진 유효 조합인지
    if (normalizedFluidName != null && concentration != null) {
      final validConcs = _knownCombinations[normalizedFluidName];
      if (validConcs != null && validConcs.contains(concentration)) {
        score += 0.10;
      }
    }

    // 텍스트 품질: 충분히 길고 노이즈가 적은 경우
    if (textLength >= 30) {
      score += 0.05;
    }

    // 다수 키워드가 같은 약품군을 지지
    if (matchedKeywords.length >= 2) {
      score += 0.05;
    }

    // 감점 항목
    if (volumeCandidateCount >= 3) {
      score -= 0.10;
    }

    // 약품명 후보가 서로 다른 약품군을 가리키면 충돌
    if (fluidCandidateNames.length >= 2) {
      score -= 0.15;
    }

    // 텍스트가 너무 짧으면 감점
    if (textLength < 15) {
      score -= 0.10;
    }

    // 상한 제한
    if (totalMl == null && score > 0.60) {
      score = 0.60;
    }
    if (normalizedFluidName == null && score > 0.80) {
      score = 0.80;
    }

    return score.clamp(0.0, 1.0);
  }

  // ── 경고 생성 ──

  static List<String> _buildWarnings({
    required double? totalMl,
    required int volumeCandidateCount,
    required String? normalizedFluidName,
    required double confidence,
  }) {
    final warnings = <String>[];

    if (totalMl == null) {
      warnings.add('수액 용량을 찾지 못했습니다. 직접 입력이 필요합니다.');
    }

    if (normalizedFluidName == null) {
      warnings.add('약품명을 명확히 판독하지 못했습니다.');
    }

    if (confidence < 0.70) {
      warnings.add('자동 감지 신뢰도가 낮습니다. 촬영 상태를 확인하거나 직접 입력해주세요.');
    }

    if (volumeCandidateCount >= 2) {
      warnings.add('여러 용량 후보가 발견되어 대표값을 선택했습니다.');
    }

    if (totalMl != null && !_standardVolumes.contains(totalMl)) {
      warnings.add('일반적인 수액 용량과 다릅니다. 실제 라벨을 확인해주세요.');
    }

    return warnings;
  }
}

// ── 내부 결과 구조체 ──

class _VolumeExtractionResult {
  final double? bestValue;
  final List<IVBagOcrCandidate> candidates;

  const _VolumeExtractionResult({
    required this.bestValue,
    required this.candidates,
  });
}

class _FluidExtractionResult {
  final String? bestRawName;
  final String? bestNormalizedName;
  final List<IVBagOcrCandidate> candidates;
  final List<String> matchedKeywords;

  const _FluidExtractionResult({
    required this.bestRawName,
    required this.bestNormalizedName,
    required this.candidates,
    required this.matchedKeywords,
  });
}

class _ConcentrationExtractionResult {
  final String? bestValue;
  final List<IVBagOcrCandidate> candidates;

  const _ConcentrationExtractionResult({
    required this.bestValue,
    required this.candidates,
  });
}

/// 약품 키워드 패턴 + 점수
class _FluidPattern {
  final String pattern;
  final double score;

  const _FluidPattern(this.pattern, this.score);
}
