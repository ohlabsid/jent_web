import 'package:flutter/widgets.dart';
import 'package:jent_web/features/mail/captcha/hcaptcha.dart';

/// Native / test fallback: SMTP delivery has no captcha, so the widget
/// renders nothing and every send is allowed through.
class HCaptchaStub implements HCaptcha {
  @override
  bool get isSupported => false;

  @override
  String? get token => null;

  @override
  Widget buildWidget({required ValueChanged<String?> onToken}) =>
      const SizedBox.shrink();

  @override
  void reset() {}
}

HCaptcha createHCaptcha() => HCaptchaStub();
