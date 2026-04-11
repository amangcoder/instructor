/// OTP input field widget — 6 individual digit boxes.
library otp_input_field;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A 6-digit OTP input composed of individual character boxes.
///
/// Each box accepts a single digit. Focus advances automatically as the user
/// types. The [onCompleted] callback fires when all 6 digits are entered.
class OtpInputField extends StatefulWidget {
  const OtpInputField({
    super.key,
    required this.onCompleted,
    this.onChanged,
    this.enabled = true,
  });

  /// Called with the complete 6-digit OTP string when all fields are filled.
  final void Function(String otp) onCompleted;

  /// Called after every keystroke with the current (potentially incomplete) value.
  final void Function(String value)? onChanged;

  final bool enabled;

  @override
  State<OtpInputField> createState() => OtpInputFieldState();
}

/// Public state class so parent widgets can call [clear] via a [GlobalKey].
class OtpInputFieldState extends State<OtpInputField> {
  static const int _length = 6;

  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(_length, (_) => TextEditingController());
    _focusNodes = List.generate(_length, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _currentValue =>
      _controllers.map((c) => c.text).join();

  void _onChanged(int index, String value) {
    if (value.length > 1) {
      // User pasted a full OTP — distribute across all boxes.
      _distributePaste(value);
      return;
    }

    if (value.isNotEmpty && index < _length - 1) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      // Backspace deleted the digit — move focus back.
      _focusNodes[index - 1].requestFocus();
    }

    widget.onChanged?.call(_currentValue);

    if (_currentValue.length == _length) {
      widget.onCompleted(_currentValue);
    }
  }

  void _distributePaste(String text) {
    final digits = text.replaceAll(RegExp(r'\D'), '');
    for (var i = 0; i < _length && i < digits.length; i++) {
      _controllers[i].text = digits[i];
    }
    // Move focus to end.
    final lastFilled = digits.length < _length ? digits.length : _length - 1;
    _focusNodes[lastFilled].requestFocus();

    widget.onChanged?.call(_currentValue);
    if (_currentValue.length == _length) {
      widget.onCompleted(_currentValue);
    }
  }

  /// Clears all boxes and returns focus to the first field.
  void clear() {
    for (final c in _controllers) {
      c.clear();
    }
    _focusNodes[0].requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      label: 'Enter 6-digit OTP',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_length, (index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: SizedBox(
              width: 48,
              height: 56,
              child: TextField(
                controller: _controllers[index],
                focusNode: _focusNodes[index],
                enabled: widget.enabled,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 1,
                autofocus: index == 0,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  counterText: '',
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: colorScheme.outline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: colorScheme.outline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest,
                ),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
                onChanged: (v) => _onChanged(index, v),
              ),
            ),
          );
        }),
      ),
    );
  }
}
