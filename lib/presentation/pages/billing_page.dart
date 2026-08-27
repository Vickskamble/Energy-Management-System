import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/config/subscription_config.dart';
import '../../core/services/quotation_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import 'razorpay_checkout_page.dart';

/// Plan & Billing: 3-tier plan cards, hybrid payment (Razorpay + UTR),
/// quotation PDF, referral program, and owner key.
class BillingPage extends StatefulWidget {
  const BillingPage({super.key});

  @override
  State<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends State<BillingPage> with WidgetsBindingObserver {
  Entitlement? _entitlement;
  PlanTier _selectedTier = PlanTier.growth;
  PlanTerm _selectedTerm = PlanTerm.monthly;
  int _extraDataPoints = 0;
  bool _loading = true;
  bool _busy = false;
  bool _paymentPending = false;
  String? _error;
  Timer? _pollTimer;
  Timer? _paymentPollTimer;
  final _ownerKeyCtrl = TextEditingController();
  bool _ownerBusy = false;
  String? _ownerError;
  DateTime? _ownerUntil;

  // UTR state
  bool _showUtrEntry = false;
  final _utrCtrl = TextEditingController();
  final _utrAmountCtrl = TextEditingController();
  bool _utrBusy = false;
  String? _utrResult;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _paymentPollTimer?.cancel();
    _ownerKeyCtrl.dispose();
    _utrCtrl.dispose();
    _utrAmountCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load(silent: true);
  }

  Future<void> _load({bool silent = false}) async {
    setState(() {
      if (!silent) {
        _loading = true;
        _error = null;
      }
    });
    try {
      final pendingLink = await SubscriptionStore.getPendingCheckoutLink();
      if (pendingLink != null && pendingLink.isNotEmpty) {
        final paid = await SubscriptionStore.isPaymentDone(paymentLinkId: pendingLink);
        if (paid) {
          await SubscriptionStore.clearPendingCheckoutLink();
          SubscriptionStore.invalidateCache();
        }
      }
      final ent = await SubscriptionStore.getEntitlement(force: true);
      if (!mounted) return;
      setState(() {
        _entitlement = ent;
        _loading = false;
        if (!silent) {
          // Restore current plan selection from entitlement (initial load only,
          // so the 30s poll never overrides a plan the user picked).
          final tier = SubscriptionConfig.tierFromString(ent.planName);
          if (tier != null) _selectedTier = tier;
          final term = SubscriptionConfig.termFromString(ent.planTerm);
          if (term != null) _selectedTerm = term;
          _extraDataPoints = ent.extraDataPoints;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (!silent) _error = 'Could not load your plan. Check your connection and retry.';
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Pricing helpers
  // ---------------------------------------------------------------------------

  int get _totalPrice =>
      SubscriptionConfig.totalAmount(_selectedTier, _selectedTerm, _extraDataPoints);

  String get _termLabel => SubscriptionConfig.termLabel(_selectedTerm);
  String get _periodLabel => _selectedTerm == PlanTerm.yearly
      ? 'year'
      : _selectedTerm == PlanTerm.quarterly
          ? 'quarter'
          : 'month';
  int get _dpTotal =>
      SubscriptionConfig.includedDataPoints(_selectedTier) + _extraDataPoints;

  // ---------------------------------------------------------------------------
  // Razorpay checkout
  // ---------------------------------------------------------------------------

  Future<void> _subscribeRazorpay() async {
    setState(() => _busy = true);
    try {
      final result = await SubscriptionStore.startCheckout(
        planTier: _selectedTier,
        extraDataPoints: _extraDataPoints,
        planTerm: _selectedTerm,
      );
      if (!mounted) return;

      if (result.isNoop) {
        _showStatus('Your plan is already up to date.', Colors.green);
        return;
      }

      bool paidInApp = false;
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
              amountLabel: '$planNameLabel subscription',
            ),
          ),
        );
        paidInApp = attempt?.status == PaymentAttemptStatus.completed;
        if (paidInApp && mounted) {
          _showStatus('Payment received — confirming with the bank…', Colors.green);
          final confirmId = result.isAddon ? result.paymentLinkId : result.subscriptionId;
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
          _showStatus('Could not open the payment page. Try again.', Colors.orange);
          return;
        }
        _startPaymentPolling(result);
      }

      SubscriptionStore.invalidateCache();
      if (mounted && !paidInApp) {
        _showStatus(
          'Payment page opened — your plan updates automatically after payment.',
          Colors.green,
        );
        _load();
      }
    } catch (e) {
      if (!mounted) return;
      _showStatus(e.toString(), Colors.red.shade700);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get planNameLabel => SubscriptionConfig.planName(_selectedTier);

  Uri _webCheckoutUri(CheckoutResult result) {
    final page = Uri.base.resolve('checkout.html');
    return page.replace(
      queryParameters: {
        'key': dotenv.env['RAZORPAY_KEY_ID'] ?? '',
        'subscription_id': result.subscriptionId,
        'description': '$planNameLabel subscription — ₹${result.amount}/$_periodLabel',
        'done_url': SubscriptionConfig.paymentDoneUrl,
        'cancel_url': SubscriptionConfig.paymentDoneUrl,
      },
    );
  }

  void _startPaymentPolling(CheckoutResult result) {
    _paymentPollTimer?.cancel();
    if (mounted) setState(() => _paymentPending = true);
    var ticks = 0;
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
      final paid = ent != null && ent.subActive;
      if (paid) {
        _paymentPollTimer?.cancel();
        setState(() => _paymentPending = false);
        _showStatus('Payment received — your plan has been updated!', Colors.green);
        _load();
        return;
      }
      if (ticks >= 240) {
        _paymentPollTimer?.cancel();
        if (!mounted) return;
        setState(() => _paymentPending = false);
        _showStatus(
          'Payment pending — your plan updates automatically once received.',
          Colors.orange,
        );
      }
    });
  }

  // ---------------------------------------------------------------------------
  // UTR (Bank Transfer) flow
  // ---------------------------------------------------------------------------

  Future<void> _submitUTR() async {
    final utr = _utrCtrl.text.trim();
    final amountText = _utrAmountCtrl.text.trim();
    if (utr.isEmpty) {
      setState(() => _utrResult = 'Enter the UTR number from your bank.');
      return;
    }
    if (amountText.isEmpty) {
      setState(() => _utrResult = 'Enter the amount you paid.');
      return;
    }
    final amountPaid = int.tryParse(amountText);
    if (amountPaid == null || amountPaid <= 0) {
      setState(() => _utrResult = 'Enter a valid amount (e.g. 2500).');
      return;
    }
    setState(() {
      _utrBusy = true;
      _utrResult = null;
    });
    try {
      final res = await SubscriptionStore.submitUTR(
        utrNumber: utr,
        amountPaid: amountPaid,
        planTier: _selectedTier,
        planTerm: _selectedTerm,
        extraDataPoints: _extraDataPoints,
        bankName: BankDetails.bankName,
      );
      if (!mounted) return;
      if (res['verified'] == true) {
        setState(() => _utrResult = '✅ Payment verified! Your plan is now active.');
        _load();
      } else if (res['error'] == 'DUPLICATE_UTR') {
        setState(() => _utrResult = '⚠ This UTR has already been used.');
      } else if (res['error'] == 'AMOUNT_MISMATCH') {
        setState(
          () => _utrResult = '⚠ Amount mismatch — expected ₹${res['expected']}, '
              'got ₹${res['received']}. Please check and re-enter.',
        );
      } else {
        setState(() => _utrResult = 'UTR submitted — pending verification.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _utrResult = 'Error: $e');
    } finally {
      if (mounted) setState(() => _utrBusy = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Quotation PDF
  // ---------------------------------------------------------------------------

  Future<void> _shareQuotation() async {
    final number = QuotationService.generateQuotationNumber();
    await QuotationService.share(
      quotationNumber: number,
      planTier: _selectedTier,
      planTerm: _selectedTerm,
      extraDataPoints: _extraDataPoints,
    );
  }

  Future<void> _openBankPaymentPage() async {
    final url = SubscriptionConfig.bankPaymentUrl;
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      _showStatus('Could not open bank payment page.', Colors.orange);
    }
  }

  // ---------------------------------------------------------------------------
  // Misc
  // ---------------------------------------------------------------------------

  void _showStatus(String text, Color background) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(text), backgroundColor: background),
    );
  }

  void _copyReferralCode() {
    final code = _entitlement?.referralCode ?? '';
    if (code.isEmpty) return;
    Clipboard.setData(ClipboardData(text: code));
    _showStatus('Referral code copied!', Colors.green);
  }

  Future<void> _shareReferral() async {
    final code = _entitlement?.referralCode ?? '';
    if (code.isEmpty) return;
    await SharePlus.instance.share(
      ShareParams(
        text:
            'Try PowerEMS — free for 30 days! Use my referral code '
            '$code to get us both +1 free month.',
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

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

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
      child: const Row(
        children: [
          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Payment in progress — your plan updates automatically',
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
            Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.dim(context)),
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
              if (!ent.subActive && ent.freeMonthsCredit > 0) _buildCreditCard(ent),
              const SizedBox(height: AppSpacing.md),
              _buildTermToggle(),
              const SizedBox(height: AppSpacing.sm),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 640;
                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final tier in PlanTier.values) ...[
                          Expanded(child: _buildPlanCard(tier, ent)),
                          if (tier != PlanTier.values.last)
                            const SizedBox(width: 12),
                        ],
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SegmentedButton<PlanTier>(
                        segments: const [
                          ButtonSegment(
                            value: PlanTier.starter,
                            label: Text('Starter'),
                          ),
                          ButtonSegment(
                            value: PlanTier.growth,
                            label: Text('Growth'),
                          ),
                          ButtonSegment(
                            value: PlanTier.pro,
                            label: Text('Pro'),
                          ),
                        ],
                        selected: {_selectedTier},
                        showSelectedIcon: false,
                        onSelectionChanged: (set) => setState(() {
                          _selectedTier = set.first;
                          if (!ent.subActive) _extraDataPoints = 0;
                        }),
                      ),
                      const SizedBox(height: 12),
                      _buildPlanCard(_selectedTier, ent),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),
              _buildPaymentSection(ent),
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

  // ---------------------------------------------------------------------------
  // Status cards
  // ---------------------------------------------------------------------------

  Widget _buildReadOnlyBanner() {
    return AppCard(
      color: AppColors.danger.withValues(alpha: 0.08),
      child: Row(
        children: [
          const Icon(Icons.lock_clock_rounded, color: AppColors.danger),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Your free trial has ended. New readings and meters are locked. '
              'Subscribe to continue.',
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
            width: 44, height: 44,
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
                  '1 data point included • ends ${end == null ? '—' : DateFormat('d MMM yyyy').format(end)}',
                  style: TextStyle(fontSize: 12, color: AppColors.dim(context)),
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
    final tier = SubscriptionConfig.tierFromString(ent.planName);
    final tierName = tier != null ? SubscriptionConfig.planName(tier) : ent.planName;
    return AppCard(
      color: AppColors.success.withValues(alpha: 0.08),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
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
                Text(
                  'Active — $tierName plan',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '${ent.dataPointsAllowed} data point(s) • ${ent.extraDataPoints > 0 ? '${ent.extraDataPoints} extra • ' : ''}'
                  '${end == null ? 'next billing unknown' : 'next billing ${DateFormat('d MMM yyyy').format(end)}'}',
                  style: TextStyle(fontSize: 12, color: AppColors.dim(context)),
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
            width: 44, height: 44,
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
                  ent.creditEnd == null
                      ? 'Active on your account — no expiry set'
                      : 'Valid until ${DateFormat('d MMM yyyy').format(ent.creditEnd!)}',
                  style: TextStyle(fontSize: 12, color: AppColors.dim(context)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Term toggle
  // ---------------------------------------------------------------------------

  Widget _buildTermToggle() {
    return SegmentedButton<PlanTerm>(
      segments: const [
        ButtonSegment(value: PlanTerm.monthly, label: Text('Monthly')),
        ButtonSegment(value: PlanTerm.quarterly, label: Text('Quarterly')),
        ButtonSegment(value: PlanTerm.yearly, label: Text('Yearly')),
      ],
      selected: {_selectedTerm},
      showSelectedIcon: false,
      onSelectionChanged: (set) => setState(() => _selectedTerm = set.first),
    );
  }

  // ---------------------------------------------------------------------------
  // Plan cards (Starter / Growth / Pro)
  // ---------------------------------------------------------------------------

  Widget _buildPlanCard(PlanTier tier, Entitlement ent) {
    final plan = SubscriptionConfig.plans[tier]!;
    final isSelected = _selectedTier == tier;
    final isActivePlan = ent.subActive &&
        SubscriptionConfig.tierFromString(ent.planName) == tier;
    final basePrice = SubscriptionConfig.baseAmount(tier, _selectedTerm);
    final dpRate = SubscriptionConfig.extraDPRate(tier, _selectedTerm);
    final total = isSelected
        ? SubscriptionConfig.totalAmount(tier, _selectedTerm, _extraDataPoints)
        : basePrice;

    return GestureDetector(
      onTap: () => setState(() {
        _selectedTier = tier;
        if (!ent.subActive) _extraDataPoints = 0;
      }),
      child: AppCard(
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.06)
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Plan name + radio + ACTIVE badge
            Row(
              children: [
                Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: isSelected ? AppColors.primary : AppColors.dim(context),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    plan.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? AppColors.primary : null,
                    ),
                  ),
                ),
                if (isActivePlan) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'ACTIVE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            // Base price
            Text(
              '₹$basePrice$_termLabel',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isSelected ? AppColors.primary : null,
              ),
            ),
            const SizedBox(height: 8),
            // Data points + extra rate
            _planRow(Icons.hub_outlined, '${plan.includedDataPoints} data points included'),
            const SizedBox(height: 4),
            _planRow(Icons.add_circle_outline, 'Extra data point: ₹$dpRate$_termLabel'),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            // Complete plan details
            ..._planFeatures(tier).map(
              (feature) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _planRow(Icons.check_rounded, feature),
              ),
            ),
            // Extra DP counter (only on selected plan for non-active users)
            if (isSelected && !ent.subActive) ...[
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('Extra data points', style: TextStyle(fontSize: 13, color: AppColors.dim(context))),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: _extraDataPoints <= 0 || _busy
                        ? null
                        : () => setState(() => _extraDataPoints--),
                  ),
                  Text(
                    '$_extraDataPoints',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: _extraDataPoints >= SubscriptionConfig.maxExtraDataPoints || _busy
                        ? null
                        : () => setState(() => _extraDataPoints++),
                  ),
                ],
              ),
              if (_extraDataPoints > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '+ ₹${_extraDataPoints * dpRate} extra = ₹$total total',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.dim(context),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _planRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.dim(context)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12.5, color: AppColors.dim(context)),
          ),
        ),
      ],
    );
  }

  /// Complete "what's included" list for a plan tier (all billing terms).
  List<String> _planFeatures(PlanTier tier) {
    final plan = SubscriptionConfig.plans[tier]!;
    return [
      '30-day free trial',
      'MSEDCL-accurate ToD billing',
      'Solar export tracking',
      'Reports & PDF quotation',
      'Extra: ₹${plan.extraMonthlyRate}/mo, ₹${plan.extraQuarterlyRate}/qtr, ₹${plan.extraYearlyRate}/yr',
      'Up to ${SubscriptionConfig.maxExtraDataPoints} extra data points',
      'Referral → +1 free month',
    ];
  }

  // ---------------------------------------------------------------------------
  // Payment section (Razorpay + Bank Transfer)
  // ---------------------------------------------------------------------------

  Widget _buildPaymentSection(Entitlement ent) {
    final isActive = ent.subActive;
    final currentTier = SubscriptionConfig.tierFromString(ent.planName);
    final currentTerm = SubscriptionConfig.termFromString(ent.planTerm);
    final upToDate = isActive &&
        currentTier == _selectedTier &&
        currentTerm == _selectedTerm &&
        _extraDataPoints <= ent.extraDataPoints;
    final hasExtra = isActive &&
        currentTier == _selectedTier &&
        currentTerm == _selectedTerm &&
        _extraDataPoints > ent.extraDataPoints;
    final currentPlanName = currentTier != null
        ? SubscriptionConfig.planName(currentTier)
        : (ent.planName.isEmpty ? 'Growth' : ent.planName);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Payment',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Total: ₹$_totalPrice $_periodLabel for $_dpTotal data point(s)',
            style: TextStyle(fontSize: 13, color: AppColors.dim(context)),
          ),
          const SizedBox(height: 16),

          // Razorpay button (UPI / cards) — always available, enabled whenever
          // the selection differs from the current plan.
          AppButton(
            label: !isActive
                ? 'Pay ₹$_totalPrice via Razorpay'
                : upToDate
                    ? 'No payment needed — you are on $currentPlanName'
                    : hasExtra
                        ? 'Pay ₹${_totalPrice - SubscriptionConfig.baseAmount(_selectedTier, _selectedTerm)} for $_extraDataPoints extra'
                        : 'Pay ₹$_totalPrice via Razorpay — switch to $planNameLabel',
            onPressed: _busy || upToDate ? null : _subscribeRazorpay,
            loading: _busy,
            expanded: true,
            icon: Icons.payment_rounded,
          ),
          const SizedBox(height: 12),

          // Divider
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'OR',
                  style: TextStyle(fontSize: 12, color: AppColors.dim(context)),
                ),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 12),

          // Bank Transfer button
          AppButton(
            label: 'Bank Transfer (NEFT / RTGS)',
            onPressed: _busy ? null : _openBankPaymentPage,
            expanded: true,
            color: AppColors.info,
            icon: Icons.account_balance_rounded,
          ),
          const SizedBox(height: 8),
          Text(
            'Pay via bank transfer, then enter your UTR below.',
            style: TextStyle(fontSize: 11, color: AppColors.dim(context)),
          ),
          const SizedBox(height: 12),

          // UTR entry
          if (_showUtrEntry) ...[
            const Divider(height: 24),
            const Text(
              'UTR Payment Entry',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            // Bank details display
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bankRow('Account Name', BankDetails.accountName),
                  _bankRow('Account No.', BankDetails.accountNumber),
                  _bankRow('IFSC', BankDetails.ifsc),
                  _bankRow('Bank', BankDetails.bankName),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _utrCtrl,
              decoration: InputDecoration(
                labelText: 'UTR Number',
                hintText: 'e.g. 298765432101',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _utrAmountCtrl,
              decoration: InputDecoration(
                labelText: 'Amount Paid (₹)',
                hintText: 'e.g. 2500',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            AppButton(
              label: _utrBusy ? 'Verifying…' : 'Submit UTR',
              onPressed: _utrBusy ? null : _submitUTR,
              loading: _utrBusy,
              expanded: true,
            ),
            if (_utrResult != null) ...[
              const SizedBox(height: 8),
              Text(
                _utrResult!,
                style: TextStyle(
                  fontSize: 13,
                  color: _utrResult!.startsWith('✅')
                      ? AppColors.success
                      : _utrResult!.startsWith('⚠')
                          ? AppColors.warning
                          : AppColors.dim(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 12),
          ],

          // Show/hide UTR entry
          TextButton.icon(
            onPressed: () => setState(() => _showUtrEntry = !_showUtrEntry),
            icon: Icon(
              _showUtrEntry ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: 18,
            ),
            label: Text(_showUtrEntry ? 'Hide UTR entry' : 'Paid via bank transfer? Enter UTR'),
          ),

          // Quotation
          if (!isActive) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _shareQuotation,
              icon: const Icon(Icons.description_outlined, size: 18),
              label: const Text('Download / share quotation PDF'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _bankRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: AppColors.dim(context))),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Referral card
  // ---------------------------------------------------------------------------

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
          Text(
            'Every client who signs up with your code and subscribes gives '
            'you +1 free month. No limit.',
            style: TextStyle(fontSize: 13, color: AppColors.dim(context)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
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

  // ---------------------------------------------------------------------------
  // Owner key card
  // ---------------------------------------------------------------------------

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
          Text(
            'Enter the owner key to unlock 6 months of full access — '
            'unlimited data points, no read-only lock.',
            style: TextStyle(fontSize: 13, color: AppColors.dim(context)),
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
                  const Icon(Icons.verified_rounded, size: 18, color: AppColors.success),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Full access active until ${DateFormat('d MMM yyyy').format(activeUntil)}.',
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
                  fontSize: 13, color: AppColors.success, fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (_ownerError != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_ownerError!, style: const TextStyle(fontSize: 13, color: AppColors.danger)),
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
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
