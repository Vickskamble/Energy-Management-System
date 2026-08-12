import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Razorpay checkout rendered inside the app via WebView, so the user lands
/// back in the app automatically after payment.
///
/// Two modes:
///  - subscription checkout: loads an HTML page that boots Razorpay Checkout
///    JS with `redirect: false`; the payment handler fires in-app and pops.
///  - addon (extra meters): loads the Razorpay payment link directly; when the
///    link redirects to [successPrefix] (its callback_url) the page pops.
class RazorpayCheckoutPage extends StatefulWidget {
  const RazorpayCheckoutPage({
    super.key,
    required this.subscriptionId,
    this.amountLabel,
    this.initialUrl,
    this.successPrefix,
  });

  final String subscriptionId;
  final String? amountLabel;

  /// Payment-link mode: load this URL directly instead of Checkout JS.
  final String? initialUrl;

  /// Payment-link mode: URL to treat as "payment done" (its callback_url).
  final String? successPrefix;

  /// Whether this device/OS can render the in-app checkout.
  /// Falls back to the external hosted page otherwise.
  static bool get supported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  @override
  State<RazorpayCheckoutPage> createState() => _RazorpayCheckoutPageState();
}

class _RazorpayCheckoutPageState extends State<RazorpayCheckoutPage> {
  late final WebViewController _controller;
  bool _completed = false;

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

  void _finish(bool ok) {
    if (!mounted || _completed) return;
    _completed = true;
    Navigator.of(context).pop(ok);
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
              _finish(true);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..addJavaScriptChannel(
        'razorpay_cb',
        onMessageReceived: (JavaScriptMessage message) {
          var ok = false;
          try {
            final data =
                jsonDecode(message.message) as Map<String, dynamic>;
            ok = data['ok'] == true;
          } catch (_) {
            ok = false;
          }
          _finish(ok);
        },
      )
      ..setBackgroundColor(const Color(0xFF0e1420));
    final initialUrl = widget.initialUrl;
    if (initialUrl != null && initialUrl.isNotEmpty) {
      _controller.loadRequest(Uri.parse(initialUrl));
    } else {
      _controller.loadHtmlString(_buildHtml());
    }
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
          onPressed: () => _finish(false),
        ),
      ),
      body: _completed
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 32),
                  Icon(Icons.check_circle_rounded,
                      color: Color(0xFF4ade80), size: 56),
                  SizedBox(height: 12),
                  Text(
                    'Payment successful — updating your plan…',
                    style: TextStyle(color: Colors.white, fontSize: 15),
                  ),
                ],
              ),
            )
          : WebViewWidget(controller: _controller),
    );
  }
}
