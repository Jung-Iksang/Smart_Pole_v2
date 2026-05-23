import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/services/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/providers/iv_status_provider.dart';
import '../../shared/widgets/widgets.dart';
import '../iv_scan/models/iv_bag_ocr_result.dart';
import '../iv_scan/services/iv_bag_ocr_parser.dart';
import '../iv_scan/widgets/ocr_confidence_banner.dart';

/// 수액팩 촬영 & 정보 입력 스크린
class IVBagScanScreen extends ConsumerStatefulWidget {
  final int deviceId;

  const IVBagScanScreen({super.key, required this.deviceId});

  @override
  ConsumerState<IVBagScanScreen> createState() => _IVBagScanScreenState();
}

class _IVBagScanScreenState extends ConsumerState<IVBagScanScreen> {
  final _volumeController = TextEditingController();
  final _nameController = TextEditingController();
  final _imagePicker = ImagePicker();
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.korean);

  bool _isProcessing = false;
  bool _isSubmitting = false;
  IVBagOcrResult? _ocrResult;

  @override
  void dispose() {
    _volumeController.dispose();
    _nameController.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _captureAndRecognize() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
    );
    if (image == null) return;

    setState(() => _isProcessing = true);

    try {
      final inputImage = InputImage.fromFile(File(image.path));
      final result = await _textRecognizer.processImage(inputImage);
      final parsed = IVBagOcrParser.parse(result.text);

      if (parsed.totalMl != null) {
        _volumeController.text = parsed.totalMl!.toStringAsFixed(0);
      }
      if (parsed.normalizedFluidName != null) {
        _nameController.text = parsed.normalizedFluidName!;
      }

      setState(() => _ocrResult = parsed);

      debugPrint('[OCR] $parsed');
    } catch (e) {
      debugPrint('[OCR] 인식 실패: $e');
      setState(() => _ocrResult = IVBagOcrResult.empty(''));
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _submit() async {
    final volumeText = _volumeController.text.trim();
    if (volumeText.isEmpty) {
      _showSnackBar('수액 용량을 입력해주세요');
      return;
    }

    final totalMl = double.tryParse(volumeText);
    if (totalMl == null || totalMl <= 0) {
      _showSnackBar('올바른 숫자를 입력해주세요');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final fluidName = _nameController.text.trim();
      await ApiClient.instance.dio.post(
        '/devices/${widget.deviceId}/infusion/setup',
        queryParameters: {'device_id': widget.deviceId},
        data: {
          'total_ml': totalMl,
          if (fluidName.isNotEmpty) 'fluid_name': fluidName,
          // 백엔드 스키마가 준비된 경우에만 활성화
          // if (_ocrResult != null) 'ocr_confidence': _ocrResult!.confidence,
          // if (_ocrResult != null) 'ocr_raw_text': _ocrResult!.rawText,
        },
      );

      ref.read(dashboardProvider.notifier).refresh();

      if (mounted) {
        _showSnackBar('수액 정보가 저장되었어요');
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/iv-status');
        }
      }
    } catch (e) {
      if (mounted) _showSnackBar('저장 실패: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: AppColors.background,
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      _buildGuideCard(),
                      const SizedBox(height: 20),
                      _buildCaptureButton(),
                      const SizedBox(height: 24),

                      // OCR 결과 배너
                      if (_ocrResult != null)
                        OcrConfidenceBanner(result: _ocrResult!),
                      if (_ocrResult != null) const SizedBox(height: 16),

                      _buildVolumeInput(),
                      const SizedBox(height: 16),
                      _buildFluidNameInput(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: PrimaryButton(
                  text: _isSubmitting ? '저장 중...' : '저장하기',
                  onPressed: _isSubmitting ? null : _submit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Row(
        children: [
          AnimatedIconButton(
            icon: LucideIcons.arrowLeft,
            onTap: () => context.pop(),
            backgroundColor: AppColors.blue50,
            activeBackgroundColor: AppColors.blue100,
            iconColor: AppColors.blue500,
            activeIconColor: AppColors.blue600,
          ),
          const SizedBox(width: 12),
          Text('수액 정보 입력', style: AppTypography.heading4),
        ],
      ),
    );
  }

  Widget _buildGuideCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: AppSpacing.borderRadiusLg,
        border: Border.all(color: AppColors.blue200),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.blue50,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(LucideIcons.info, size: 20, color: AppColors.blue400),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '수액팩 용량이 필요해요',
                  style: AppTypography.small.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.blue800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '정확한 잔량 측정을 위해 수액 용량을 알아야 해요.\n수액팩을 촬영하거나 직접 입력해주세요.',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.blue600,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaptureButton() {
    return GestureDetector(
      onTap: _isProcessing ? null : _captureAndRecognize,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: AppSpacing.borderRadiusLg,
          border: Border.all(
            color: AppColors.blue200,
            width: 1.5,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.blue500.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF60A5FA), Color(0xFF3B82F6)],
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: _isProcessing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Icon(
                        _ocrResult != null
                            ? LucideIcons.refreshCw
                            : LucideIcons.camera,
                        size: 24,
                        color: Colors.white,
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _isProcessing
                  ? '텍스트 인식 중...'
                  : _ocrResult != null
                      ? '다시 촬영하기'
                      : '수액팩 촬영하기',
              style: AppTypography.small.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.blue700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '촬영하면 용량과 약품명을 자동으로 읽어와요',
              style: AppTypography.caption.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVolumeInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '수액 용량',
              style: AppTypography.small.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.blue100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '필수',
                style: AppTypography.micro.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.blue700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: AppSpacing.borderRadiusMd,
            border: Border.all(color: const Color(0xFFE8F0FE)),
          ),
          child: TextField(
            controller: _volumeController,
            keyboardType: TextInputType.number,
            style: AppTypography.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: '예: 500',
              hintStyle: AppTypography.bodyLarge.copyWith(
                color: AppColors.textDisabled,
              ),
              suffixText: 'mL',
              suffixStyle: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w500,
                color: AppColors.textMuted,
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              border: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '수액팩에 적힌 용량을 입력해주세요 (예: 500, 1000)',
          style: AppTypography.caption.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }

  Widget _buildFluidNameInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '약품명',
              style: AppTypography.small.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '선택',
              style: AppTypography.micro.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: AppSpacing.borderRadiusMd,
            border: Border.all(color: const Color(0xFFE8F0FE)),
          ),
          child: TextField(
            controller: _nameController,
            style: AppTypography.bodyLarge,
            decoration: InputDecoration(
              hintText: '모르면 건너뛰어도 돼요',
              hintStyle: AppTypography.bodyLarge.copyWith(
                color: AppColors.textDisabled,
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }
}
