import 'package:flutter/material.dart';
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
  bool _obscurePass = true;
  bool _consentAccepted = false;
  bool _consentError = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _referralCtrl.dispose();
    super.dispose();
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
                  const Text(
                    'Create your account to start monitoring',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
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
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      if (v.trim().length < 4) {
                        return 'Referral codes are at least 4 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  InkWell(
                    onTap: () => setState(() {
                      _consentAccepted = !_consentAccepted;
                      _consentError = false;
                    }),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
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
                                      : AppColors.textSecondary),
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          const Expanded(child: LegalConsentText()),
                        ],
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
