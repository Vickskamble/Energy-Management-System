import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/config/subscription_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../data/repositories/meter_repository.dart';
import 'razorpay_checkout_page.dart';

/// Plan & Billing: current entitlement, meter add-ons, Razorpay checkout,
/// and the referral program (referrer gets +1 month per referred client).
class BillingPage extends StatefulWidget {
  const BillingPage({super.key});

  @override
  State<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends State<BillingPage> with WidgetsBindingObserver {
  Entitlement? _entitlement;
  int _meterCount = 0;
  int _extraMeters = 0;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final meterRepo = context.read<MeterRepository>();
      final ent = await SubscriptionStore.getEntitlement(force: true);
      final meters = await meterRepo.getAllMeters();
      if (!mounted) return;
      setState(() {
        _entitlement = ent;
        _meterCount = meters.length;
        _extraMeters = ent.isDemo
            ? 0
            : (meters.length - 1 > ent.extraMeters
                ? meters.length - 1
                : ent.extraMeters);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load your plan. Check your connection and retry.';
      });
    }
  }

  /// Monthly price for the selected extra-meter count.
  int get _totalMonthly =>
      SubscriptionConfig.basePricePerMonth +
      _extraMeters * SubscriptionConfig.meterPricePerMonth;

  /// Extra meters to add for active subscribers (top-up, ₹99 each).
  int get _deltaMeters =>
      _entitlement == null ? 0 : _extraMeters - _entitlement!.extraMeters;

  Future<void> _subscribe() async {
    setState(() => _busy = true);
    try {
      final result = await SubscriptionStore.startCheckout(
        extraMeters: _extraMeters,
      );
      if (!mounted) return;

      if (result.isNoop) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your plan is already up to date.'),
            backgroundColor: Colors.green,
          ),
        );
        return;
      }

      bool paidInApp = false;
      if (RazorpayCheckoutPage.supported) {
        paidInApp = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => RazorpayCheckoutPage(
              subscriptionId: result.isAddon ? '' : result.subscriptionId,
              initialUrl: result.isAddon ? result.paymentUrl : null,
              successPrefix: result.isAddon
                  ? '${SubscriptionConfig.paymentDoneUrl}?'
                  : null,
              amountLabel: 'Monthly subscription',
            ),
          ),
        ) ==
            true;
      } else {
        final opened = await launchUrl(
          Uri.parse(result.paymentUrl),
          mode: LaunchMode.externalApplication,
        );
        if (!opened && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open the payment page. Try again.'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
      }

      SubscriptionStore.invalidateCache();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              paidInApp
                  ? 'Payment successful! Updating your plan…'
                  : result.isAddon
                      ? 'Payment page opened — your plan updates automatically '
                          'after payment.'
                      : 'Payment page opened — your plan updates automatically '
                          'after payment.',
            ),
            backgroundColor: Colors.green,
          ),
        );
        _load();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _copyReferralCode() {
    final code = _entitlement?.referralCode ?? '';
    if (code.isEmpty) return;
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Referral code copied!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _shareReferral() async {
    final code = _entitlement?.referralCode ?? '';
    if (code.isEmpty) return;
    await SharePlus.instance.share(
      ShareParams(
        text:
            'Try PowerEMS — free for 60 days (1 meter). Use my referral code '
            '$code to get us both going. Pay only ₹799/mo after trial!',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Plan & Billing')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            AppButton(label: 'Retry', onPressed: _load),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final ent = _entitlement!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.page),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (ent.readOnly) _buildReadOnlyBanner(),
              if (ent.trialActive && !ent.subActive) _buildTrialCard(ent),
              if (ent.subActive) _buildActiveCard(ent),
              if (!ent.subActive && ent.freeMonthsCredit > 0)
                _buildCreditCard(ent),
              const SizedBox(height: AppSpacing.md),
              _buildPricingCard(ent),
              const SizedBox(height: AppSpacing.md),
              _buildReferralCard(ent),
              const SizedBox(height: AppSpacing.md),
              TextButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Refresh plan status'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReadOnlyBanner() {
    return AppCard(
      color: AppColors.danger.withValues(alpha: 0.08),
      child: Row(
        children: [
          const Icon(Icons.lock_clock_rounded, color: AppColors.danger),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Your free trial has ended. You can still view your data, but '
              'new readings and meters are locked. Subscribe to continue.',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrialCard(Entitlement ent) {
    final end = ent.trialEnd;
    final daysLeft = end != null
        ? end.difference(DateTime.now()).inDays + 1
        : SubscriptionConfig.trialDays;
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.free_cancellation_rounded, color: AppColors.info),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Free trial — $daysLeft day${daysLeft == 1 ? '' : 's'} left',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  end == null
                      ? '1 meter included'
                      : '1 meter included • ends ${DateFormat('d MMM yyyy').format(end)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveCard(Entitlement ent) {
    final end = ent.currentPeriodEnd ?? ent.accessEndsAt;
    return AppCard(
      color: AppColors.success.withValues(alpha: 0.08),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.workspace_premium_rounded, color: AppColors.success),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Active subscription',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '₹799/month • ${ent.extraMeters} extra meter(s) • '
                  '${end == null ? 'next billing unknown' : 'next billing ${DateFormat('d MMM yyyy').format(end)}'}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditCard(Entitlement ent) {
    return AppCard(
      color: AppColors.warning.withValues(alpha: 0.08),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.card_giftcard_rounded, color: AppColors.warning),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${ent.freeMonthsCredit} free month(s) from referrals',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  'Valid until ${DateFormat('d MMM yyyy').format(ent.creditEnd ?? DateTime.now().add(const Duration(days: 30)))}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingCard(Entitlement ent) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Your plan',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _priceRow(
            'Base plan (includes 1 meter)',
            '₹${SubscriptionConfig.basePricePerMonth}/mo',
          ),
          const Divider(height: 24),
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Extra meters',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '₹${SubscriptionConfig.meterPricePerMonth}/mo each',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: ent.isDemo || _extraMeters <= 0 || _busy
                    ? null
                    : () => setState(() => _extraMeters--),
              ),
              Text(
                '$_extraMeters',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: _busy || _extraMeters >= 20
                    ? null
                    : () => setState(() => _extraMeters++),
              ),
            ],
          ),
          const Divider(height: 24),
          _priceRow(
            'Total per month',
            '₹$_totalMonthly',
            emphasized: true,
          ),
          const SizedBox(height: 4),
          Text(
            'You have $_meterCount meter(s) configured. Base plan + '
            '$_extraMeters extra meter(s) = ${_meterCount > 1 ? _meterCount : 1} total.',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          if (ent.subActive && _extraMeters > ent.extraMeters) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'You are subscribed — extra meters cost ₹99/meter as a '
                'one-time top-up. Your ₹799 base plan is NOT charged again.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 12),
          ],
          AppButton(
            label: ent.subActive
                ? _extraMeters == ent.extraMeters
                    ? 'No changes — you already pay for $_extraMeters'
                        ' extra meter(s)'
                    : 'Add $_deltaMeters extra meter'
                        '${_deltaMeters == 1 ? '' : 's'} — '
                        'pay ₹${_deltaMeters * SubscriptionConfig.meterPricePerMonth}'
                        ' one-time'
                : _extraMeters == 0
                    ? 'Subscribe — ₹${SubscriptionConfig.basePricePerMonth}/mo'
                    : 'Subscribe — ₹$_totalMonthly/mo',
            onPressed:
                _busy || (ent.subActive && _extraMeters == ent.extraMeters)
                    ? null
                    : _subscribe,
            loading: _busy,
            expanded: true,
          ),
          const SizedBox(height: 8),
          const Text(
            'Powered by Razorpay — UPI, cards & netbanking. 60-day free trial '
            'on every new account.',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _priceRow(String label, String value, {bool emphasized = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: emphasized ? 14 : 13,
            fontWeight: emphasized ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: emphasized ? 16 : 13,
            fontWeight: FontWeight.w700,
            color: emphasized ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildReferralCard(Entitlement ent) {
    final code = ent.referralCode;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.group_add_rounded, color: AppColors.primary),
              SizedBox(width: 10),
              Text(
                'Refer & earn 1 month free',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Every client who signs up with your code and subscribes gives '
            'you +1 free month. No limit on referrals.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    code.isEmpty ? '—' : code,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                      color: AppColors.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: code.isEmpty ? null : _copyReferralCode,
                icon: const Icon(Icons.copy_rounded, size: 20),
                tooltip: 'Copy code',
              ),
              const SizedBox(width: 4),
              IconButton.filledTonal(
                onPressed: code.isEmpty ? null : _shareReferral,
                icon: const Icon(Icons.share_rounded, size: 20),
                tooltip: 'Share',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
