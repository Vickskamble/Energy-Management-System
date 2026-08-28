import 'package:web/web.dart' as web;

/// Navigate the current tab to [url]. Used on web to open the Razorpay
/// checkout page without triggering browser popup blockers (an async gap
/// between a user click and `window.open` is treated as a popup).
void navigateToUrl(String url) {
  web.window.location.href = url;
}
