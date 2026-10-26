import 'package:flutter/material.dart';
import 'auth_scaffold.dart';

class AuthPasswordField extends StatefulWidget {
  const AuthPasswordField({
    super.key,
    required this.controller,
    required this.label,
    required this.validator,
    this.enabled = true,
    this.newPassword = false,
    this.textInputAction = TextInputAction.done,
    this.onSubmitted,
    this.onChanged,
    this.fieldKey,
  });

  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String> validator;
  final bool enabled;
  final bool newPassword;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final GlobalKey<FormFieldState<String>>? fieldKey;

  @override
  State<AuthPasswordField> createState() => _AuthPasswordFieldState();
}

class _AuthPasswordFieldState extends State<AuthPasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: widget.fieldKey,
      controller: widget.controller,
      enabled: widget.enabled,
      obscureText: _obscured,
      autocorrect: false,
      enableSuggestions: false,
      keyboardType: TextInputType.visiblePassword,
      autofillHints: [
        widget.newPassword ? AutofillHints.newPassword : AutofillHints.password
      ],
      textInputAction: widget.textInputAction,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          tooltip: _obscured
              ? 'Afficher le mot de passe'
              : 'Masquer le mot de passe',
          onPressed: widget.enabled
              ? () => setState(() => _obscured = !_obscured)
              : null,
          icon: Icon(_obscured
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined),
        ),
      ),
      validator: widget.validator,
      onFieldSubmitted: widget.onSubmitted,
      onChanged: widget.onChanged,
    );
  }
}

class AuthFeedback extends StatefulWidget {
  const AuthFeedback({super.key, required this.message, this.success = false});

  final String message;
  final bool success;

  @override
  State<AuthFeedback> createState() => _AuthFeedbackState();
}

class _AuthFeedbackState extends State<AuthFeedback> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Scrollable.ensureVisible(context,
            alignment: 0.1, duration: const Duration(milliseconds: 250));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final color =
        widget.success ? authPrimary : Theme.of(context).colorScheme.error;
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: widget.success
              ? const Color(0xFFE8F5F4)
              : Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
                widget.success
                    ? Icons.check_circle_outline
                    : Icons.info_outline,
                color: color,
                size: 21),
            const SizedBox(width: 10),
            Expanded(
                child: Text(widget.message,
                    style: TextStyle(color: color, height: 1.4))),
          ],
        ),
      ),
    );
  }
}

class AuthSubmitButton extends StatelessWidget {
  const AuthSubmitButton(
      {super.key,
      required this.label,
      required this.loadingLabel,
      required this.loading,
      required this.onPressed});

  final String label;
  final String loadingLabel;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: loading ? null : onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading) ...[
              const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 12),
            ],
            Flexible(
                child: Text(loading ? loadingLabel : label,
                    textAlign: TextAlign.center)),
            if (!loading) ...[
              const SizedBox(width: 10),
              const Icon(Icons.arrow_forward_rounded, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}

class PasswordStrengthIndicator extends StatelessWidget {
  const PasswordStrengthIndicator({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final password = value.text;
        final variety = [
          RegExp('[a-z]'),
          RegExp('[A-Z]'),
          RegExp('[0-9]'),
          RegExp(r'[^a-zA-Z0-9]')
        ].where((pattern) => pattern.hasMatch(password)).length;
        final score = password.isEmpty
            ? 0
            : password.length < 12
                ? 1
                : password.length >= 12 && variety >= 3
                    ? 4
                    : password.length >= 10 && variety >= 2
                        ? 3
                        : 2;
        final labels = [
          '12 caractères minimum · privilégiez une phrase',
          'Très court',
          'Peu robuste',
          'Correct',
          'Robuste'
        ];
        final color = score < 3 ? const Color(0xFFB16B22) : authPrimary;
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: List.generate(
                    4,
                    (index) => Expanded(
                          child: Container(
                            height: 4,
                            margin: EdgeInsets.only(right: index == 3 ? 0 : 5),
                            decoration: BoxDecoration(
                              color: index < score
                                  ? color
                                  : const Color(0xFFE6EDF0),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        )),
              ),
              const SizedBox(height: 7),
              Text(labels[score],
                  style: TextStyle(
                      fontSize: 12,
                      color: score == 0 ? const Color(0xFF637D88) : color)),
            ],
          ),
        );
      },
    );
  }
}
