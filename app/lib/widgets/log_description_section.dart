import 'package:flutter/material.dart';

class LogDescriptionSection extends StatelessWidget {
  final TextEditingController controller;
  final bool aiEnabled;
  final bool isAutofilling;
  final VoidCallback? onAutofill;
  final String hintText;
  final String autofillSemanticsId;
  /// Optional anchor for the description TextField (explore rig). When null the
  /// field carries no identifier — keeps existing callers unchanged.
  final String? inputSemanticsId;

  const LogDescriptionSection({
    super.key,
    required this.controller,
    required this.aiEnabled,
    required this.isAutofilling,
    this.onAutofill,
    this.hintText = 'Describe…',
    this.autofillSemanticsId = 'btn-autofill',
    this.inputSemanticsId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final field = TextField(
      controller: controller,
      maxLines: 3,
      enabled: !isAutofilling,
      decoration: InputDecoration(
        hintText: hintText,
        border: const OutlineInputBorder(),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        inputSemanticsId != null
            ? Semantics(identifier: inputSemanticsId, child: field)
            : field,
        if (aiEnabled) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Semantics(
              identifier: autofillSemanticsId,
              child: OutlinedButton.icon(
              onPressed: isAutofilling ? null : onAutofill,
              icon: isAutofilling
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.primary,
                      ),
                    )
                  : const Icon(Icons.auto_awesome, size: 16),
              label: Text(isAutofilling ? 'Filling…' : 'Autofill with AI'),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
                side: BorderSide(color: theme.colorScheme.primary.withAlpha(120)),
              ),
            ),
            ),
          ),
        ],
      ],
    );
  }
}
