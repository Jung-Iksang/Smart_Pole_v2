import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// 앱 입력 필드
/// React의 input field와 동일한 스타일 (에러 상태 포함)
class AppInput extends StatefulWidget {
  const AppInput({
    super.key,
    required this.controller,
    this.label,
    this.placeholder,
    this.errorText,
    this.helperText,
    this.successText,
    this.showSuccess = false,
    this.keyboardType,
    this.inputFormatters,
    this.maxLength,
    this.obscureText = false,
    this.enabled = true,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.textInputAction,
    this.autofocus = false,
    this.prefixIcon,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String? label;
  final String? placeholder;
  final String? errorText;
  final String? helperText;
  final String? successText;
  final bool showSuccess;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final bool obscureText;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final bool autofocus;
  final Widget? prefixIcon;
  final Widget? suffixIcon;

  @override
  State<AppInput> createState() => _AppInputState();
}

class _AppInputState extends State<AppInput> {
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    } else {
      _focusNode.removeListener(_onFocusChange);
    }
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: AppTypography.label,
          ),
          AppSpacing.gapVSm,
        ],

        // Input field
        Container(
          height: AppSpacing.inputHeight,
          padding: EdgeInsets.only(
            left: widget.prefixIcon != null ? 0 : AppSpacing.base,
            right: widget.suffixIcon != null ? 4 : AppSpacing.base,
          ),
          decoration: BoxDecoration(
            color: hasError
                ? AppColors.statusWarning.withValues(alpha: 0.05)
                : AppColors.card,
            borderRadius: AppSpacing.borderRadiusLg,
            border: Border.all(
              color: _getBorderColor(hasError),
              width: 2,
            ),
          ),
          child: Row(
            children: [
              if (widget.prefixIcon != null) widget.prefixIcon!,
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  enabled: widget.enabled,
                  obscureText: widget.obscureText,
                  keyboardType: widget.keyboardType,
                  inputFormatters: widget.inputFormatters,
                  maxLength: widget.maxLength,
                  textInputAction: widget.textInputAction,
                  autofocus: widget.autofocus,
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                  style: AppTypography.input,
                  decoration: InputDecoration(
                    hintText: widget.placeholder,
                    hintStyle: AppTypography.inputPlaceholder,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    counterText: '',
                  ),
                ),
              ),
              if (widget.suffixIcon != null) widget.suffixIcon!,
            ],
          ),
        ),

        // Error, success, or helper text
        if (hasError) ...[
          AppSpacing.gapVSm,
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.statusWarning,
                  shape: BoxShape.circle,
                ),
              ),
              AppSpacing.gapHXs,
              Expanded(
                child: Text(
                  widget.errorText!,
                  style: AppTypography.inputError,
                ),
              ),
            ],
          ),
        ] else if (widget.showSuccess && widget.successText != null) ...[
          AppSpacing.gapVSm,
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.statusNormal,
                  shape: BoxShape.circle,
                ),
              ),
              AppSpacing.gapHXs,
              Expanded(
                child: Text(
                  widget.successText!,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.statusNormal,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ] else if (widget.helperText != null) ...[
          AppSpacing.gapVSm,
          Text(
            widget.helperText!,
            style: AppTypography.caption,
          ),
        ],
      ],
    );
  }

  Color _getBorderColor(bool hasError) {
    if (hasError) {
      return _isFocused
          ? AppColors.statusWarning
          : AppColors.statusWarningLight;
    }
    if (widget.showSuccess) {
      return AppColors.statusNormal;
    }
    return _isFocused ? AppColors.blue400 : AppColors.borderLight;
  }
}

/// 검색 입력 필드
class SearchInput extends StatefulWidget {
  const SearchInput({
    super.key,
    required this.controller,
    this.placeholder = '검색',
    this.onChanged,
    this.onClear,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String placeholder;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final bool autofocus;

  @override
  State<SearchInput> createState() => _SearchInputState();
}

class _SearchInputState extends State<SearchInput> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final hasText = widget.controller.text.isNotEmpty;

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: AppSpacing.borderRadiusBase,
        border: Border.all(color: AppColors.borderBlue, width: 1),
      ),
      child: Row(
        children: [
          Icon(
            Icons.search,
            size: 14,
            color: AppColors.textMuted,
          ),
          AppSpacing.gapHSm,
          Expanded(
            child: TextField(
              controller: widget.controller,
              autofocus: widget.autofocus,
              onChanged: widget.onChanged,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: widget.placeholder,
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
            ),
          ),
          if (hasText)
            GestureDetector(
              onTap: () {
                widget.controller.clear();
                widget.onClear?.call();
              },
              child: Icon(
                Icons.close,
                size: 14,
                color: AppColors.textDisabled,
              ),
            ),
        ],
      ),
    );
  }
}
