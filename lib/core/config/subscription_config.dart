import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../error/exceptions.dart';
import '../network/supabase_client.dart';
import '../utils/app_logger.dart';

/// SaaS pricing (mirrors supabase/migrations/20260812_subscriptions.sql and
/// the subscription-checkout Edge Function).
class SubscriptionConfig {
  SubscriptionConfig._();

  /// Base plan — includes the 1st meter.
  static const int basePricePerMonth = 799;

  /// Every additional meter beyond the 1st.
  static const int meterPricePerMonth = 99;

  /// Free-tier trial length.
  static const int trialDays = 60;

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
  final DateTime? trialEnd;
  final DateTime? creditEnd;
  final DateTime? currentPeriodEnd;
  final String subscriptionStatus;
  final String referralCode;
  final int metersAllowed;
  final int extraMeters;
  final int freeMonthsCredit;

  const Entitlement({
    required this.isDemo,
    required this.trialActive,
    required this.subActive,
    required this.creditActive,
    required this.readOnly,
    this.trialEnd,
    this.creditEnd,
    this.currentPeriodEnd,
    required this.subscriptionStatus,
    required this.referralCode,
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
      trialEnd: parse('trial_end'),
      creditEnd: parse('credit_end'),
      currentPeriodEnd: parse('current_period_end'),
      subscriptionStatus: (json['subscription_status'] ?? 'none') as String,
      referralCode: (json['referral_code'] ?? '') as String,
      metersAllowed: (json['meters_allowed'] as num?)?.toInt() ?? 1,
      extraMeters: (json['extra_meters'] as num?)?.toInt() ?? 0,
      freeMonthsCredit: (json['free_months_credit'] as num?)?.toInt() ?? 0,
    );
  }

  /// Next date access ends (trial, credit, or paid period).
  DateTime? get accessEndsAt {
    final candidates = [trialEnd, creditEnd, currentPeriodEnd]
        .whereType<DateTime>()
        .where((d) => d.isAfter(DateTime.now()))
        .toList();
    if (candidates.isEmpty) return null;
    candidates.sort();
    return candidates.first;
  }
}

/// Result of starting a checkout: either a full Razorpay subscription
/// (₹799 base + ₹99 × meters) or a one-time extra-meter top-up payment link
/// (₹99 × delta) for users with an active base plan.
class CheckoutResult {
  final String mode;

  /// 'full' — new subscription; 'addon' — extra-meter payment link;
  /// 'noop' — no change needed (already at the requested meter count).
  final String subscriptionId;
  final String paymentUrl;
  final int deltaMeters;
  final int amount;

  const CheckoutResult({
    this.mode = 'full',
    this.subscriptionId = '',
    this.paymentUrl = '',
    this.deltaMeters = 0,
    this.amount = 0,
  });

  factory CheckoutResult.fromJson(Map<String, dynamic> json) {
    return CheckoutResult(
      mode: (json['mode'] as String?) ?? 'full',
      subscriptionId: (json['subscription_id'] ?? '') as String,
      paymentUrl: ((json['payment_url'] ?? json['short_url']) as String?) ?? '',
      deltaMeters: (json['delta_meters'] as num?)?.toInt() ?? 0,
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
  /// Returns the hosted payment page URL for the user to pay.
  static Future<CheckoutResult> startCheckout({required int extraMeters}) async {
    try {
      final res = await SupabaseClientManager.client.functions
          .invoke(
            'subscription-checkout',
            body: {'extra_meters': extraMeters},
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
}
