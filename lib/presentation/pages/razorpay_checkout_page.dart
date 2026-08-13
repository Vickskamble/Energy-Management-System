import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Razorpay checkout rendered inside the app via WebView, so the user lands
/// back in the app automatically after payment.
///
/// Two modes:
///  - subscription checkout: loads an HTML page that boots Razorpay Checkout
///    JS with `redirect: false`; the payment handler fires in-app and pops.
///  - addon (extra meters): loads the Razorpay payment link directly; when the
///    link redirects to [successPrefix] (its callback_url) the page pops.
///
/// IMPORTANT: This widget only reports that the user *attempted/completed*
/// checkout on the client side (Razorpay JS handler or a redirect match).
/// Neither of those is a verified payment — verification happens server-side
/// via Razorpay's webhook (signature-checked). The caller must NOT treat
/// [PaymentAttemptResult.completed] as "paid". Instead, show a "confirming"
/// state and rely on a Supabase Realtime subscription (or a status poll) on
/// the payments/subscriptions row to flip the UI to "active" once the
/// webhook has actually updated the database.
enum PaymentAttemptStatus {
  /// Client-side handler fired / redirect matched — payment *likely* went
  /// through, but this is NOT verified. Wait for backend confirmation.
  completed,

  /// User closed the checkout modal or backed out before finishing.
  cancelled,

  /// The in-app WebView/JS threw an error before payment could complete.
  failed,
}

class PaymentAttemptResult {
  const PaymentAttemptResult(this.status, {this.paymentId});

  final PaymentAttemptStatus status;

  /// Razorpay payment id, when the client-side handler or redirect exposed
  /// one. Pass this to your backend status-check / use it to filter your
  /// Realtime subscription — never trust it as proof of payment by itself.
  final String? paymentId;
}

class RazorpayCheckoutPage extends StatefulWidget {
  const RazorpayCheckoutPage({
    super.key,
    required this.subscriptionId,
    this.amountLabel,
    this.initialUrl,
    this.successPrefix,
    this.fallbackUrl,
  });

  final String subscriptionId;
  final String? amountLabel;

  /// Payment-link mode: load this URL directly instead of Checkout JS.
  final String? initialUrl;

  /// Payment-link mode: URL to treat as "checkout finished" (its callback_url).
  final String? successPrefix;

  /// External payment page URL used if the in-app WebView fails to start.
  final String? fallbackUrl;

  /// Whether this device/OS can render the in-app checkout.
  /// Falls back to the external hosted page otherwise.
  ///
  /// Windows/macOS are EXCLUDED: the WebView2/macOS WKWebView platform view
  /// can throw during build when the runtime is missing, which surfaces as a
  /// full-screen Flutter crash ("Something went wrong"). Desktop uses the
  /// hosted checkout.html in the default browser instead — reliable, and the
  /// caller's flow is unchanged (browser path + payment-status polling).
  static bool get supported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  State<RazorpayCheckoutPage> createState() => _RazorpayCheckoutPageState();
}

class _RazorpayCheckoutPageState extends State<RazorpayCheckoutPage> {
  late final WebViewController _controller;
  bool _completed = false;
  bool _initFailed = false;
  PaymentAttemptStatus? _resultStatus;

  String get _keyId => dotenv.env['RAZORPAY_KEY_ID'] ?? '';

  String _buildHtml() {
    final key = jsonEncode(_keyId);
    final subId = jsonEncode(widget.subscriptionId);
    final desc = jsonEncode(widget.amountLabel ?? 'Monthly subscription');
    return '''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>PowerEMS Payment</title>
<style>
  body { margin:0; background:#0e1420; }
</style>
</head>
<body>
<script src="https://checkout.razorpay.com/v1/checkout.js"></script>
<script>
  window.razorpayError = function(e){ if(window.razorpay_cb) window.razorpay_cb.postMessage(JSON.stringify({ok:false, error:String(e)})); };
  try {
    var options = {
      "key": $key,
      "subscription_id": $subId,
      "name": "PowerEMS",
      "description": $desc,
      "currency": "INR",
      "redirect": false,
      "theme": {"color": "#16a34a"},
      "handler": function(r){ window.razorpay_cb.postMessage(JSON.stringify({ok:true, payment_id:r.razorpay_payment_id})) },
      "modal": { "ondismiss": function(){ window.razorpay_cb.postMessage(JSON.stringify({ok:false})) } }
    };
    var rzp = new Razorpay(options);
    rzp.open();
  } catch(e) { window.razorpayError(e); }
</script>
</body>
</html>''';
  }

  /// Pops the page with a [PaymentAttemptResult]. This is deliberately NOT
  /// called "success" — see the class doc comment. The caller is responsible
  /// for verifying the payment server-side before updating any UI/state.
  void _finish(PaymentAttemptStatus status, {String? paymentId}) {
    if (!mounted || _completed) return;
    _completed = true;
    setState(() => _resultStatus = status);
    Navigator.of(context).pop(
      PaymentAttemptResult(status, paymentId: paymentId),
    );
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final prefix = widget.successPrefix;
            if (prefix != null &&
                request.url.startsWith(prefix) &&
                !_completed) {
              // Extract payment id from the redirect query params if present
              // (e.g. razorpay_payment_id=pay_xxx) so the caller can key its
              // status check / Realtime filter off it. This is still just a
              // client-side signal, not verification.
              final uri = Uri.tryParse(request.url);
              final paymentId = uri?.queryParameters['razorpay_payment_id'];
              _finish(PaymentAttemptStatus.completed, paymentId: paymentId);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onWebResourceError: (_) => _markInitFailed(),
        ),
      )
      ..addJavaScriptChannel(
        'razorpay_cb',
        onMessageReceived: (JavaScriptMessage message) {
          try {
            final data =
                jsonDecode(message.message) as Map<String, dynamic>;
            final ok = data['ok'] == true;
            final paymentId = data['payment_id'] as String?;
            _finish(
              ok ? PaymentAttemptStatus.completed
                 : PaymentAttemptStatus.cancelled,
              paymentId: paymentId,
            );
          } catch (_) {
            _finish(PaymentAttemptStatus.failed);
          }
        },
      )
      ..setBackgroundColor(const Color(0xFF0e1420));
    final initialUrl = widget.initialUrl;
    if (initialUrl != null && initialUrl.isNotEmpty) {
      _controller
          .loadRequest(Uri.parse(initialUrl))
          .catchError((Object _) => _markInitFailed());
    } else {
      _controller
          .loadHtmlString(_buildHtml())
          .catchError((Object _) => _markInitFailed());
    }
  }

  void _markInitFailed() {
    if (mounted) setState(() => _initFailed = true);
  }

  Future<void> _openExternally() async {
    final url =
        widget.fallbackUrl ??
        widget.initialUrl ??
        '';
    if (url.isEmpty) {
      _finish(PaymentAttemptStatus.failed);
      return;
    }
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open the payment page. Try again.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
    // Note: if the user pays in the external browser, this widget never
    // gets a client-side signal at all. The calling screen must rely
    // entirely on the Realtime/webhook confirmation in that path — don't
    // gate anything on this widget's return value when the fallback is used.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0e1420),
      appBar: AppBar(
        title: const Text('Pay securely'),
        backgroundColor: const Color(0xFF0e1420),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _finish(PaymentAttemptStatus.cancelled),
        ),
      ),
      body: _completed
          ? _buildCompletedState()
          : _initFailed
              ? _buildFallback()
              : WebViewWidget(controller: _controller),
    );
  }

  Widget _buildCompletedState() {
    // Deliberately does NOT say "Payment successful" — the payment is not
    // verified yet. The caller shows its own confirming/active UI once the
    // backend webhook has updated the database.
    final isOk = _resultStatus == PaymentAttemptStatus.completed;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 32),
          Icon(
            isOk ? Icons.hourglass_top_rounded : Icons.info_outline_rounded,
            color: isOk ? const Color(0xFF4ade80) : const Color(0xFF94a3b8),
            size: 56,
          ),
          const SizedBox(height: 12),
          Text(
            isOk
                ? 'Payment received — confirming with the bank…'
                : 'Checkout closed.',
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildFallback() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.public_rounded,
                color: Color(0xFF94a3b8), size: 56),
            const SizedBox(height: 12),
            const Text(
              'In-app payment page could not open.',
              style: TextStyle(color: Colors.white, fontSize: 15),
            ),
            const SizedBox(height: 4),
            const Text(
              'Continue in your browser instead — your plan updates '
              'automatically after payment.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF94a3b8), fontSize: 13),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _openExternally,
              icon: const Icon(Icons.open_in_browser),
              label: const Text('Open payment in browser'),
            ),
          ],
        ),
      ),
    );
  }
}