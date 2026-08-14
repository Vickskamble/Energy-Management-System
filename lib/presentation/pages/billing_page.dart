import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/config/subscription_config.dart';
import '../../core/network/supabase_client.dart';
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
  bool _paymentPending = false;
  int _expectedExtraMeters = 0;
  String? _error;
  Timer? _pollTimer;
  Timer? _paymentPollTimer;
  final _ownerKeyCtrl = TextEditingController();
  bool _ownerBusy = false;
  String? _ownerError;
  DateTime? _ownerUntil;

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
    _paymentPollTimer?.cancel();
    _ownerKeyCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final meterRepo = context.read<MeterRepository>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Re-confirm any add-on payment whose checkout page was closed before
      // confirmation completed — payment-status flips the plan server-side
      // even when the webhook never delivered.
      final pendingLink = await SubscriptionStore.getPendingCheckoutLink();
      if (pendingLink != null && pendingLink.isNotEmpty) {
        final paid = await SubscriptionStore.isPaymentDone(paymentLinkId: pendingLink);
        if (paid) {
          await SubscriptionStore.clearPendingCheckoutLink();
          SubscriptionStore.invalidateCache();
        }
      }
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
      // Remember the add-on link so a closed/refreshed checkout never loses
      // the payment: payment-status re-checks Razorpay directly on next load.
      if (result.isAddon) {
        await SubscriptionStore.setPendingCheckoutLink(result.paymentLinkId);
      }
      if (!mounted) return;
      if (RazorpayCheckoutPage.supported) {
        final attempt = await Navigator.of(context).push<PaymentAttemptResult>(
          MaterialPageRoute(
            builder: (_) => RazorpayCheckoutPage(
              subscriptionId: result.isAddon ? '' : result.subscriptionId,
              initialUrl: result.isAddon ? result.paymentUrl : null,
              successPrefix: result.isAddon
                  ? '${SubscriptionConfig.paymentDoneUrl}?'
                  : null,
              fallbackUrl: result.paymentUrl,
              amountLabel: 'Monthly subscription',
            ),
          ),
        );
        paidInApp = attempt?.status == PaymentAttemptStatus.completed;
        if (paidInApp && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment received — confirming with the bank…'),
              backgroundColor: Colors.green,
            ),
          );
          // Hit payment-status right now so the server flips the DB row
          // immediately — the 3-s poll below is a safety net only.
          final confirmId = result.isAddon
              ? result.paymentLinkId
              : result.subscriptionId;
          if (confirmId.isNotEmpty) {
            final confirmed = await SubscriptionStore.isPaymentDone(
              paymentLinkId: result.isAddon ? confirmId : null,
              subscriptionId: result.isAddon ? null : confirmId,
            );
            if (confirmed) {
              await SubscriptionStore.clearPendingCheckoutLink();
              SubscriptionStore.invalidateCache();
            }
          }
          _load();
        }
        // In-app checkout starts the same instant-confirmation polling as
        // the browser path: the direct Razorpay status check + webhook
        // update flip the plan within seconds — no manual refresh needed.
        _startPaymentPolling(result);
      } else {
        final paymentUri = result.isAddon
            ? Uri.parse(result.paymentUrl)
            : _webCheckoutUri(result);
        final opened = await launchUrl(
          paymentUri,
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
        _startPaymentPolling(result);
      }

      SubscriptionStore.invalidateCache();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              paidInApp
                  ? 'Payment received — your plan updates automatically.'
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

  /// In-app checkout page for web subscriptions: Razorpay Checkout JS hosted
  /// on our domain renders the desktop layout and redirects back to
  /// [SubscriptionConfig.paymentDoneUrl] after payment.
  Uri _webCheckoutUri(CheckoutResult result) {
    final page = Uri.base.resolve('checkout.html');
    return page.replace(
      queryParameters: {
        'key': dotenv.env['RAZORPAY_KEY_ID'] ?? '',
        'subscription_id': result.subscriptionId,
        'description': 'Monthly subscription — ₹${result.amount}/mo',
        'done_url': SubscriptionConfig.paymentDoneUrl,
        'cancel_url': SubscriptionConfig.paymentDoneUrl,
      },
    );
  }

  /// Watch for the payment to complete. Two sources:
  ///  1. Razorpay direct (via the payment-status Edge Function) — confirms
  ///     the payment the moment it happens, no webhook wait.
  ///  2. The entitlement flip — the webhook updates the plan; once
  ///     [SubscriptionStore.getEntitlement] reflects it the UI refreshes.
  /// Runs every 3s for up to 12 minutes; the banner stays visible meanwhile.
  void _startPaymentPolling(CheckoutResult result) {
    _paymentPollTimer?.cancel();
    if (mounted) {
      setState(() {
        _paymentPending = true;
        _expectedExtraMeters = result.extraMeters;
      });
    }
    final subscriptionId = result.subscriptionId;
    final paymentLinkId = result.paymentLinkId;
    var ticks = 0;
    var confirmed = false;
    _paymentPollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      ticks++;
      if (!mounted) return;
      Entitlement? ent;
      try {
        ent = await SubscriptionStore.getEntitlement(force: true);
      } catch (_) {
        ent = null;
      }
      if (!mounted) return;
      final paid = ent != null &&
          (result.isAddon
              ? ent.extraMeters >= _expectedExtraMeters
              : ent.subActive || ent.creditActive);
      if (paid) {
        _paymentPollTimer?.cancel();
        setState(() => _paymentPending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment received — your plan has been updated!'),
            backgroundColor: Colors.green,
          ),
        );
        _load();
        return;
      }
      if (!confirmed) {
        var rzpPaid = false;
        try {
          final res = await SupabaseClientManager.client.functions.invoke(
            'payment-status',
            body: subscriptionId.isNotEmpty
                ? {'subscription_id': subscriptionId}
                : {'payment_link_id': paymentLinkId},
          );
          rzpPaid = (res.data as Map?)?['paid'] == true;
        } catch (_) {
          rzpPaid = false;
        }
        if (rzpPaid) {
          confirmed = true;
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Payment confirmed — plan activate ho raha hai (thoda wait karo)…',
              ),
              backgroundColor: Colors.green,
            ),
          );
          _load();
        }
      } else if (ticks % 6 == 0) {
        // Confirmed already — keep nudging the entitlement until the
        // webhook flips the subscription.
        _load();
      }
      if (ticks >= 240) {
        _paymentPollTimer?.cancel();
        if (!mounted) return;
        setState(() => _paymentPending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Payment confirmation pending — your plan updates automatically '
              'once the payment is received.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    });
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
              : Column(
                  children: [
                    if (_paymentPending) _buildPaymentPendingBanner(),
                    Expanded(child: _buildContent()),
                  ],
                ),
  );
  }

  Widget _buildPaymentPendingBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page, vertical: 10),
      color: AppColors.kpiSavings.withValues(alpha: 0.12),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Payment window me payment complete karo — plan yahan automatically update ho jayega',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
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

  Future<void> _redeemOwnerKey() async {
    final key = _ownerKeyCtrl.text.trim();
    if (key.isEmpty) {
      setState(() => _ownerError = 'Enter the key first.');
      return;
    }
    setState(() {
      _ownerBusy = true;
      _ownerError = null;
      _ownerUntil = null;
    });
    final result = await SubscriptionStore.redeemOwnerKey(key);
    if (!mounted) return;
    setState(() {
      _ownerBusy = false;
      if (result.ok) {
        _ownerUntil = result.until;
        _ownerKeyCtrl.clear();
        _load();
      } else {
        _ownerError = result.message;
      }
    });
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
              _buildOwnerKeyCard(),
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

  Widget _buildOwnerKeyCard() {
    final ent = _entitlement;
    final activeUntil = ent?.ownerAccessUntil;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.admin_panel_settings_rounded, color: AppColors.info),
              SizedBox(width: 10),
              Text(
                'Owner access key',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter the owner key to unlock 6 months of full access — '
            'unlimited meters, no read-only lock.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          if (activeUntil != null && activeUntil.isAfter(DateTime.now())) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_rounded,
                      size: 18, color: AppColors.success),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Full access active until '
                      '${DateFormat('d MMM yyyy').format(activeUntil)}.',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_ownerUntil != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Key accepted — full access granted until '
                '${DateFormat('d MMM yyyy').format(_ownerUntil!)}.',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (_ownerError != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                _ownerError!,
                style: const TextStyle(fontSize: 13, color: AppColors.danger),
              ),
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ownerKeyCtrl,
                  enabled: !_ownerBusy,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'Enter owner key',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onSubmitted: (_) => _redeemOwnerKey(),
                ),
              ),
              const SizedBox(width: 8),
              AppButton(
                label: 'Redeem',
                loading: _ownerBusy,
                onPressed: _ownerBusy ? null : _redeemOwnerKey,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
