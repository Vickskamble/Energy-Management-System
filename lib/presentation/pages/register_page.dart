import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/config/subscription_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/validation_rules.dart';
import '../../core/widgets/app_button.dart';
import '../auth_bloc/auth_bloc.dart';
import '../widgets/legal_consent_text.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _referralCtrl = TextEditingController();
  final _consentFocusNode = FocusNode();
  bool _obscurePass = true;
  bool _consentAccepted = false;
  bool _consentError = false;
  bool _consentFocused = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _referralCtrl.dispose();
    _consentFocusNode.dispose();
    super.dispose();
  }

  void _toggleConsent() {
    setState(() {
      _consentAccepted = !_consentAccepted;
      _consentError = false;
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (!_consentAccepted) {
      setState(() => _consentError = true);
      return;
    }
    final referral = _referralCtrl.text.trim();
    if (referral.isNotEmpty) {
      // Remember it — claimed once the user signs in (idempotent server-side).
      SubscriptionStore.setPendingReferral(referral);
    }
    context.read<AuthBloc>().add(
      AppAuthRegisterRequested(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Get started',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create your account to start monitoring',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.dim(context),
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [
                      AutofillHints.username,
                      AutofillHints.email,
                    ],
                    validator: ValidationRules.validateEmail,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passCtrl,
                    obscureText: _obscurePass,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Min ${ValidationRules.minPasswordLength} chars, letter + number',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: InkWell(
                        onTap: () =>
                            setState(() => _obscurePass = !_obscurePass),
                        child: Icon(
                          _obscurePass
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 20,
                        ),
                      ),
                    ),
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                    validator: ValidationRules.validatePassword,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm password',
                      prefixIcon: Icon(Icons.lock_outlined),
                    ),
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                    validator: (v) {
                      if (v != _passCtrl.text) return 'Passwords do not match';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _referralCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Referral code (optional)',
                      hintText: 'Got a friend code? You both save.',
                      prefixIcon: Icon(Icons.card_giftcard_outlined),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      if (v.trim().length < 4) {
                        return 'Referral codes are at least 4 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  Focus(
                    focusNode: _consentFocusNode,
                    canRequestFocus: true,
                    onFocusChange: (focused) =>
                        setState(() => _consentFocused = focused),
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent &&
                          (event.logicalKey == LogicalKeyboardKey.enter ||
                              event.logicalKey ==
                                  LogicalKeyboardKey.space)) {
                        _toggleConsent();
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: InkWell(
                      onTap: _toggleConsent,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: _consentFocused
                              ? Border.all(
                                  color: AppColors.primary,
                                  width: 1.5,
                                )
                              : null,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              _consentAccepted
                                  ? Icons.check_box_rounded
                                  : Icons.check_box_outline_blank_rounded,
                              color: _consentError
                                  ? AppColors.danger
                                  : (_consentAccepted
                                        ? AppColors.primary
                                        : AppColors.dim(context)),
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            const Expanded(child: LegalConsentText()),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_consentError)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'Please accept the Terms of Service and Privacy '
                        'Policy to continue.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  BlocConsumer<AuthBloc, AppAuthState>(
                    listener: (context, state) {
                      if (state is AppAuthRegisterSuccess) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Account created! Check your email to verify, '
                              'then sign in to continue.',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                        Navigator.pop(context);
                      } else if (state is AppAuthError) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(state.message),
                            backgroundColor: Colors.red.shade700,
                          ),
                        );
                      }
                    },
                    builder: (context, state) {
                      final loading = state is AppAuthLoading;
                      return AppButton(
                        label: 'Create Account',
                        onPressed: loading ? null : _submit,
                        expanded: true,
                        loading: loading,
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Already have an account? Sign in'),
                  ),
                  const SizedBox(height: 12),
                  const LegalConsentText(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
