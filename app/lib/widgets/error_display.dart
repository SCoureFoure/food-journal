import 'package:flutter/material.dart';

/// Inline red text for form-level errors.
class ErrorBanner extends StatelessWidget {
  final String message;
  const ErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Text(message, style: const TextStyle(color: Colors.red));
  }
}

/// Full-screen centered error + retry button, for screen load failures.
class ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final String? semanticsId;

  const ErrorRetry({
    super.key,
    required this.message,
    required this.onRetry,
    this.semanticsId,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(message),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
    if (semanticsId != null) {
      return Semantics(identifier: semanticsId!, child: content);
    }
    return content;
  }
}
