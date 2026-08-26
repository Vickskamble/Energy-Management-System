import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../error/exceptions.dart';
import '../network/supabase_client.dart';
import '../utils/app_logger.dart';

/// Plan tier — controls included data points, features, and pricing.
enum PlanTier { starter, growth, pro }

/// Billing cadence for a subscription.
enum PlanTerm { monthly, quarterly, yearly }

/// Bank details for NEFT/RTGS payment.
class BankDetails {
  BankDetails._();

  static const String accountName = 'Brilliants';
  static const String accountNumber = '09288100004458';
  static const String ifsc = 'BARB0HINGAN';
  static const String bankName = 'Bank of Baroda';
}

/// 3-tier SaaS pricing — mirrors supabase migrations and Edge Functions.
class SubscriptionConfig {
  SubscriptionConfig._();

  // ---- Trial ----
  /// Free-tier trial length (30 days for all plans).
  static const int trialDays = 30;

  /// Grace window after a paid plan expires before full read-only lock.
  static const int graceDays = 7;

  /// Maximum extra data points a user can add beyond their plan.
  static const int maxExtraDataPoints = 20;

  // ---- Plan definitions ----
  static const Map<PlanTier, _PlanPricing> plans = {
    PlanTier.starter: _PlanPricing(
      name: 'Starter',
      includedDataPoints: 2,
      monthlyPrice: 999,
      quarterlyPrice: 2697,
      yearlyPrice: 9990,
      extraMonthlyRate: 299,
      extraQuarterlyRate: 249,
      extraYearlyRate: 199,
    ),
    PlanTier.growth: _PlanPricing(
      name: 'Growth',
      includedDataPoints: 5,
      monthlyPrice: 2500,
      quarterlyPrice: 6750,
      yearlyPrice: 25500,
      extraMonthlyRate: 499,
      extraQuarterlyRate: 399,
      extraYearlyRate: 299,
    ),
    PlanTier.pro: _PlanPricing(
      name: 'Pro',
      includedDataPoints: 10,
      monthlyPrice: 5000,
      quarterlyPrice: 13500,
      yearlyPrice: 50000,
      extraMonthlyRate: 799,
      extraQuarterlyRate: 649,
      extraYearlyRate: 499,
    ),
  };

  /// Total price for [tier] + [term] + [extraDataPoints] additional data points.
  static int totalAmount(PlanTier tier, PlanTerm term, int extraDataPoints) {
    final p = plans[tier]!;
    final base = switch (term) {
      PlanTerm.monthly => p.monthlyPrice,
      PlanTerm.quarterly => p.quarterlyPrice,
      PlanTerm.yearly => p.yearlyPrice,
    };
    final extraRate = switch (term) {
      PlanTerm.monthly => p.extraMonthlyRate,
      PlanTerm.quarterly => p.extraQuarterlyRate,
      PlanTerm.yearly => p.extraYearlyRate,
    };
    return base + extraDataPoints * extraRate;
  }

  /// Base price for a given term (no extra data points).
  static int baseAmount(PlanTier tier, PlanTerm term) {
    final p = plans[tier]!;
    return switch (term) {
      PlanTerm.monthly => p.monthlyPrice,
      PlanTerm.quarterly => p.quarterlyPrice,
      PlanTerm.yearly => p.yearlyPrice,
    };
  }

  /// Per-extra-data-point rate for a given term.
  static int extraDPRate(PlanTier tier, PlanTerm term) {
    final p = plans[tier]!;
    return switch (term) {
      PlanTerm.monthly => p.extraMonthlyRate,
      PlanTerm.quarterly => p.extraQuarterlyRate,
      PlanTerm.yearly => p.extraYearlyRate,
    };
  }

  /// Total included data points for a tier.
  static int includedDataPoints(PlanTier tier) =>
      plans[tier]!.includedDataPoints;

  /// Label for a plan tier.
  static String planName(PlanTier tier) => plans[tier]!.name;

  /// Term label for display.
  static String termLabel(PlanTerm term) => switch (term) {
        PlanTerm.monthly => '/mo',
        PlanTerm.quarterly => '/qtr',
        PlanTerm.yearly => '/yr',
      };

  /// Convert a string plan name to PlanTier.
  static PlanTier? tierFromString(String? name) {
    if (name == null) return null;
    for (final t in PlanTier.values) {
      if (t.name == name) return t;
    }
    return null;
  }

  /// Convert a string term to PlanTerm.
  static PlanTerm? termFromString(String? term) {
    if (term == null) return null;
    for (final t in PlanTerm.values) {
      if (t.name == term) return t;
    }
    return null;
  }

  /// Razorpay callback landing page — the payment-link redirects here.
  static const String paymentDoneUrl =
      'https://app.brilliants.in/payment-done.html';

  /// Bank transfer payment page — opens in new browser tab on web.
  static const String bankPaymentUrl =
      'https://app.brilliants.in/bank-payment.html';
}

/// Internal pricing data for a single plan tier.
class _PlanPricing {
  final String name;
  final int includedDataPoints;
  final int monthlyPrice;
  final int quarterlyPrice;
  final int yearlyPrice;
  final int extraMonthlyRate;
  final int extraQuarterlyRate;
  final int extraYearlyRate;

  const _PlanPricing({
    required this.name,
    required this.includedDataPoints,
    required this.monthlyPrice,
    required this.quarterlyPrice,
    required this.yearlyPrice,
    required this.extraMonthlyRate,
    required this.extraQuarterlyRate,
    required this.extraYearlyRate,
  });
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
  final String planName;
  final String planTerm;
  final int dataPointsAllowed;
  final int extraDataPoints;
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
    this.planName = 'growth',
    this.planTerm = 'monthly',
    required this.dataPointsAllowed,
    required this.extraDataPoints,
    required this.freeMonthsCredit,
  });

  /// Backward-compatible alias — data points allowed = meters allowed.
  int get metersAllowed => dataPointsAllowed;

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
      planName: (json['plan_name'] ?? json['meters_allowed'] != null
          ? 'growth'
          : 'growth') as String,
      planTerm: (json['plan_term'] ?? 'monthly') as String,
      dataPointsAllowed: (json['data_points_allowed'] ??
              json['meters_allowed'] as num?)
          ?.toInt() ?? 1,
      extraDataPoints: (json['extra_data_points'] ??
              json['extra_meters'] as num?)
          ?.toInt() ?? 0,
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
  final DateTime? until;

  const RedeemResult({required this.ok, this.error = '', this.until});

  String get message => error;
}

/// Result of starting a Razorpay checkout.
class CheckoutResult {
  final String mode;
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

  /// Start (or re-create, on extra-data-point change) a Razorpay subscription.
  /// [planTerm] selects the billing cadence; [planName] selects the tier.
  static Future<CheckoutResult> startCheckout({
    required PlanTier planTier,
    required int extraDataPoints,
    required PlanTerm planTerm,
  }) async {
    try {
      final res = await SupabaseClientManager.client.functions
          .invoke(
            'subscription-checkout',
            body: {
              'plan_name': planTier.name,
              'extra_data_points': extraDataPoints,
              'plan_term': planTerm.name,
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

  /// Submit a UTR payment for auto-verification.
  static Future<Map<String, dynamic>> submitUTR({
    required String utrNumber,
    required int amountPaid,
    required PlanTier planTier,
    required PlanTerm planTerm,
    required int extraDataPoints,
    required String bankName,
  }) async {
    try {
      final res = await SupabaseClientManager.client.functions
          .invoke(
            'verify-utr',
            body: {
              'utr_number': utrNumber.trim(),
              'amount_paid': amountPaid,
              'plan_name': planTier.name,
              'plan_term': planTerm.name,
              'extra_data_points': extraDataPoints,
              'bank_name': bankName,
            },
          )
          .timeout(const Duration(seconds: 30));
      final data = (res.data as Map?)?.cast<String, dynamic>() ?? {};
      if (data['verified'] == true) invalidateCache();
      return data;
    } on TimeoutException {
      throw const SubscriptionException(
        'Verification timed out. Check your connection and try again.',
      );
    } catch (e) {
      AppLogger.e('UTR verification failed', e);
      throw const SubscriptionException(
        'Could not verify payment. Try again in a moment.',
      );
    }
  }

  /// Link the signed-in account to a referrer's code.
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

  /// True when the signed-in user is allowed to create another data point.
  static Future<bool> canAddDataPoint({
    required int currentDataPointCount,
  }) async {
    try {
      final ent = await getEntitlement();
      return currentDataPointCount < ent.dataPointsAllowed;
    } catch (_) {
      return true;
    }
  }

  /// Backward-compatible alias.
  static Future<bool> canAddMeter({required int currentMeterCount}) =>
      canAddDataPoint(currentDataPointCount: currentMeterCount);

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
