import 'package:flutter/material.dart';

class LoadingButton extends StatelessWidget {
  final bool isLoading;
  final bool disabled;
  final VoidCallback? onPressed;
  final String label;
  final String? semanticsId;

  const LoadingButton({
    super.key,
    required this.isLoading,
    required this.label,
    required this.onPressed,
    this.disabled = false,
    this.semanticsId,
  });

  @override
  Widget build(BuildContext context) {
    Widget button = ElevatedButton(
      onPressed: isLoading || disabled ? null : onPressed,
      child: isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    );
    if (semanticsId != null) {
      return Semantics(identifier: semanticsId!, child: button);
    }
    return button;
  }
}
