import 'package:flutter/widgets.dart';

export 'hcaptcha_stub.dart'
    if (dart.library.js_interop) 'hcaptcha_web.dart'
    show createHCaptcha;

/// Spam protection for the contact form.
///
/// Web3Forms can require an hCaptcha token per submission. Their
/// zero-config snippet (`<div class="h-captcha">` + `script.js`) only
/// works for real HTML forms — Flutter Web paints to a canvas, so the
/// widget is hosted in the DOM instead via a platform view and the
/// hCaptcha JS API is called directly. Native builds fall back to a
/// no-op because mail is delivered over SMTP there, where Web3Forms
/// (and its captcha) is not involved.
abstract class HCaptcha {
  /// False where the hCaptcha JS API is unavailable (native builds).
  bool get isSupported;

  /// Token from the last solved challenge, or null while pending.
  String? get token;

  /// Renders the challenge. [onToken] fires with a fresh token after
  /// each solve and with null when the challenge expires or resets.
  Widget buildWidget({required ValueChanged<String?> onToken});

  /// Discards the current token so a new challenge is shown.
  void reset();
}
