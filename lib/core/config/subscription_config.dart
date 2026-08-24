import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../error/exceptions.dart';
import '../network/supabase_client.dart';
import '../utils/app_logger.dart';

/// Billing cadence for a subscription.
enum PlanTerm { monthly, yearly }

/// SaaS pricing (mirrors supabase/migrations/20260812_subscriptions.sql and
/// the subscription-checkout Edge Function).
class SubscriptionConfig {
  SubscriptionConfig._();

  /// Meters included in both the monthly and yearly base plans.
  static const int includedMeters = 5;

  // ---- Monthly plan ----
  /// Monthly base price (covers 5 meters).
  static const int monthlyBasePrice = 2500;

  /// Extra meter on the monthly plan, per month.
  static const int monthlyMeterPrice = 499;

  // ---- Yearly plan ----
  /// Yearly base price (covers 5 meters).
  static const int yearlyBasePrice = 25500;

  /// Extra meter on the yearly plan, per month (billed across the year).
  static const int yearlyMeterPrice = 499;

  /// Free-tier trial length.
  static const int trialDays = 60;

  /// Grace window after a paid plan expires before the account is fully
  /// locked to read-only. Data stays intact and renewal remains possible.
  static const int graceDays = 7;

  /// Annualised cost of the monthly plan for [extraMeters] beyond the base.
  static int monthlyAnnualised(int extraMeters) =>
      (monthlyBasePrice + extraMeters * monthlyMeterPrice) * 12;

  /// Total yearly-plan cost for [extraMeters] beyond the base.
  static int yearlyTotal(int extraMeters) =>
      yearlyBasePrice + extraMeters * yearlyMeterPrice * 12;

  /// Savings of the yearly plan vs 12× the monthly plan (base-focused).
  static int yearlySavings(int extraMeters) =>
      monthlyAnnualised(extraMeters) - yearlyTotal(extraMeters);

  /// Savings percentage of the yearly plan vs 12× the monthly plan.
  static double yearlySavingsPct(int extraMeters) {
    final annual = monthlyAnnualised(extraMeters);
    if (annual == 0) return 0;
    return (yearlySavings(extraMeters) / annual) * 100;
  }

  /// Callback landing after addon (extra-meter) payment — the Razorpay
  /// payment-link redirects here, and the in-app WebView treats it as done.
  static const String paymentDoneUrl =
      'https://Vickskamble.github.io/Energy-Management-System/payment-done.html';
}

/// Server-computed entitlement for the signed-in user
/// (from the `get_entitlement` RPC — single source of truth).
class Entitlement {
  final bool isDemo;
  final bool trialActive;
  final bool subActive;
  final bool creditActive;
  final bool readOnly;
  final bool inGrace;
  final DateTime? trialEnd;
  final DateTime? creditEnd;
  final DateTime? currentPeriodEnd;
  final DateTime? graceEnd;
  final DateTime? ownerAccessUntil;
  final String subscriptionStatus;
  final String referralCode;
  final String planTerm;
  final int metersAllowed;
  final int extraMeters;
  final int freeMonthsCredit;

  const Entitlement({
    required this.isDemo,
    required this.trialActive,
    required this.subActive,
    required this.creditActive,
    required this.readOnly,
    required this.inGrace,
    this.trialEnd,
    this.creditEnd,
    this.currentPeriodEnd,
    this.graceEnd,
    this.ownerAccessUntil,
    required this.subscriptionStatus,
    required this.referralCode,
    this.planTerm = 'monthly',
    required this.metersAllowed,
    required this.extraMeters,
    required this.freeMonthsCredit,
  });

  factory Entitlement.fromJson(Map<String, dynamic> json) {
    DateTime? parse(String? key) {
      final v = json[key];
      if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
      return null;
    }

    return Entitlement(
      isDemo: json['is_demo'] == true,
      trialActive: json['trial_active'] == true,
      subActive: json['sub_active'] == true,
      creditActive: json['credit_active'] == true,
      readOnly: json['read_only'] == true,
      inGrace: json['in_grace'] == true,
       trialEnd: parse('trial_end'),
       creditEnd: parse('credit_end'),
       currentPeriodEnd: parse('current_period_end'),
       graceEnd: parse('grace_end'),
       ownerAccessUntil: parse('owner_access_until'),
       subscriptionStatus: (json['subscription_status'] ?? 'none') as String,
       referralCode: (json['referral_code'] ?? '') as String,
       planTerm: (json['plan_term'] ?? 'monthly') as String,
      metersAllowed: (json['meters_allowed'] as num?)?.toInt() ?? 1,
      extraMeters: (json['extra_meters'] as num?)?.toInt() ?? 0,
      freeMonthsCredit: (json['free_months_credit'] as num?)?.toInt() ?? 0,
    );
  }

  /// Next date access ends (trial, credit, or paid period).
  DateTime? get accessEndsAt {
    final candidates = [trialEnd, creditEnd, currentPeriodEnd, ownerAccessUntil]
        .whereType<DateTime>()
        .where((d) => d.isAfter(DateTime.now()))
        .toList();
    if (candidates.isEmpty) return null;
    candidates.sort();
    return candidates.first;
  }
}

/// Outcome of redeeming the owner (manager) access key (`NEW20`).
class RedeemResult {
  final bool ok;
  final String error;

  /// When full access expires (6 months from redemption).
  final DateTime? until;

  const RedeemResult({required this.ok, this.error = '', this.until});

  String get message => error;
}

/// Result of starting a checkout: either a full Razorpay subscription
/// (₹2,500 base incl. 5 meters + ₹149 × extra meters) or a one-time
/// extra-meter top-up payment link (₹149 × delta) for active subscribers.
class CheckoutResult {
  final String mode;

  /// 'full' — new subscription; 'addon' — extra-meter payment link;
  /// 'noop' — no change needed (already at the requested meter count).
  final String subscriptionId;
  final String paymentUrl;
  final String paymentLinkId;
  final int deltaMeters;
  final int extraMeters;
  final int amount;

  const CheckoutResult({
    this.mode = 'full',
    this.subscriptionId = '',
    this.paymentUrl = '',
    this.paymentLinkId = '',
    this.deltaMeters = 0,
    this.extraMeters = 0,
    this.amount = 0,
  });

  factory CheckoutResult.fromJson(Map<String, dynamic> json) {
    return CheckoutResult(
      mode: (json['mode'] as String?) ?? 'full',
      subscriptionId: (json['subscription_id'] ?? '') as String,
      paymentUrl: ((json['payment_url'] ?? json['short_url']) as String?) ?? '',
      paymentLinkId: (json['payment_link_id'] ?? '') as String,
      deltaMeters: (json['delta_meters'] as num?)?.toInt() ?? 0,
      extraMeters: (json['extra_meters'] as num?)?.toInt() ?? 0,
      amount: (json['amount'] as num?)?.toInt() ?? 0,
    );
  }

  bool get isAddon => mode == 'addon';
  bool get isNoop => mode == 'noop';
}

/// Per-user subscription + referral store. Client reads entitlement from the
/// server (RLS + Edge Function); server triggers enforce the limits.
class SubscriptionStore {
  SubscriptionStore._();

  static const _secureStorage = FlutterSecureStorage();
  static const _pendingReferralKey = 'ems_pending_referral_code';
  static const _pendingLinkKey = 'ems_pending_payment_link_id';

  static Entitlement? _cached;
  static DateTime? _cachedAt;

  static Entitlement? get cached => _cached;

  /// Entitlement for the signed-in user, cached for 60s.
  static Future<Entitlement> getEntitlement({bool force = false}) async {
    if (!force &&
        _cached != null &&
        _cachedAt != null &&
        DateTime.now().difference(_cachedAt!).inSeconds < 60) {
      return _cached!;
    }
    final data = await SupabaseClientManager.client
        .rpc('get_entitlement')
        .timeout(const Duration(seconds: 15));
    final entitlement = Entitlement.fromJson(
      (data as Map).cast<String, dynamic>(),
    );
    _cached = entitlement;
    _cachedAt = DateTime.now();
    return entitlement;
  }

  static void invalidateCache() {
    _cached = null;
  }

  /// Start (or re-create, on extra-meter change) a Razorpay subscription.
  /// [planTerm] selects the monthly or yearly Razorpay plan.
  /// Returns the hosted payment page URL for the user to pay.
  static Future<CheckoutResult> startCheckout({
    required int extraMeters,
    required PlanTerm planTerm,
  }) async {
    try {
      final res = await SupabaseClientManager.client.functions
          .invoke(
            'subscription-checkout',
            body: {
              'extra_meters': extraMeters,
              'plan_term': planTerm == PlanTerm.yearly ? 'yearly' : 'monthly',
            },
          )
          .timeout(const Duration(seconds: 30));
      final data = (res.data as Map?)?.cast<String, dynamic>() ?? {};
      final result = CheckoutResult.fromJson(data);
      if (result.isNoop) return result;
      if (result.paymentUrl.isEmpty) {
        final detail = data['error'] ?? 'no payment URL returned';
        throw SubscriptionException(
          'Could not start payment — $detail.',
        );
      }
      return result;
    } on SubscriptionException {
      rethrow;
    } on TimeoutException {
      throw const SubscriptionException(
        'Payment setup timed out. Check your connection and try again.',
      );
    } catch (e) {
      AppLogger.e('Checkout failed', e);
      throw const SubscriptionException(
        'Could not start payment. Try again in a moment.',
      );
    }
  }

  /// Link the signed-in account to a referrer's code (once, server-validated).
  static Future<bool> claimReferral(String code) async {
    final ok = await SupabaseClientManager.client
        .rpc('claim_referral', params: {'p_code': code.trim()});
    if (ok == true) invalidateCache();
    return ok == true;
  }

  /// Result of redeeming the owner (manager) access key.
  static Future<RedeemResult> redeemOwnerKey(String key) async {
    try {
      final data = await SupabaseClientManager.client
          .rpc('redeem_owner_key', params: {'p_code': key.trim()});
      final map = (data as Map?)?.cast<String, dynamic>() ?? {};
      if (map['ok'] == true) invalidateCache();
      return RedeemResult(
        ok: map['ok'] == true,
        error: (map['error'] as String?) ?? '',
        until: (map['until'] as String?) == null
            ? null
            : DateTime.tryParse(map['until'] as String),
      );
    } catch (e) {
      AppLogger.e('redeem_owner_key failed', e);
      return const RedeemResult(ok: false, error: 'Could not redeem the key.');
    }
  }

  /// Remember a referral code entered at signup so it can be claimed after
  /// the user signs in (survives app restarts via secure storage).
  static Future<void> setPendingReferral(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return;
    await _secureStorage.write(key: _pendingReferralKey, value: trimmed);
  }

  static Future<String?> getPendingReferral() async {
    try {
      return await _secureStorage.read(key: _pendingReferralKey);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearPendingReferral() async {
    try {
      await _secureStorage.delete(key: _pendingReferralKey);
    } catch (_) {
      // best-effort
    }
  }

  /// Claim the pending referral code (called after login). Idempotent —
  /// safe to call repeatedly; the server ignores invalid/duplicate claims.
  static Future<void> claimPendingReferral() async {
    try {
      final code = await getPendingReferral();
      if (code == null || code.isEmpty) return;
      final ok = await claimReferral(code);
      if (ok) await clearPendingReferral();
    } catch (e) {
      AppLogger.e('Pending referral claim failed', e);
    }
  }

  /// True when the signed-in user is allowed to create another meter.
  static Future<bool> canAddMeter({required int currentMeterCount}) async {
    try {
      final ent = await getEntitlement();
      return currentMeterCount < ent.metersAllowed;
    } catch (_) {
      // Unknown → allow; the server trigger is the hard gate.
      return true;
    }
  }

  /// Persist the add-on payment link id so the app can re-confirm the payment
  /// after the checkout page closes/refreshes (webhook delivery is unreliable,
  /// payment-status is the source of truth).
  static Future<void> setPendingCheckoutLink(String paymentLinkId) async {
    if (paymentLinkId.isEmpty) return;
    try {
      await _secureStorage.write(key: _pendingLinkKey, value: paymentLinkId);
    } catch (_) {
      // best-effort
    }
  }

  static Future<String?> getPendingCheckoutLink() async {
    try {
      return await _secureStorage.read(key: _pendingLinkKey);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearPendingCheckoutLink() async {
    try {
      await _secureStorage.delete(key: _pendingLinkKey);
    } catch (_) {
      // best-effort
    }
  }

  /// Ask the payment-status Edge Function whether the payment went through.
  /// Returns true only when Razorpay confirms it; not a local optimization.
  /// Pass [paymentLinkId] for add-on links or [subscriptionId] for base plans.
  static Future<bool> isPaymentDone({
    String? paymentLinkId,
    String? subscriptionId,
  }) async {
    try {
      final body = (subscriptionId != null && subscriptionId.isNotEmpty)
          ? {'subscription_id': subscriptionId}
          : {'payment_link_id': paymentLinkId ?? ''};
      final res = await SupabaseClientManager.client.functions
          .invoke('payment-status', body: body)
          .timeout(const Duration(seconds: 20));
      final data = (res.data as Map?)?.cast<String, dynamic>() ?? {};
      return data['paid'] == true;
    } catch (e) {
      AppLogger.e('payment-status check failed', e);
      return false;
    }
  }
}
